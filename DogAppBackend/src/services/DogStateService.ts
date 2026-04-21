import { PrismaClient } from '@prisma/client'

export interface DogStateSnapshot {
  // Core Tamagotchi parameters (0–100)
  energy:        number
  hunger:        number
  happiness:     number
  trainingLevel: number
  // Extended parameters
  engagement:    number  // bond with owner
  calmness:      number  // overstimulation level (high = calm, low = overstimulated)
  confidence:    number  // fear/stability (high = confident)
  // Meta
  currentAction: string  // highest-priority action right now
  isResting:     boolean
  minutesUntilNextAction: number | null
  alerts: string[]
}

interface TodayTotals {
  walkMinutes:     number
  playMinutes:     number
  trainingMinutes: number
  feedingCount:    number
  lastFeedingAt:   Date | null
  lastWalkAt:      Date | null
  lastPlayAt:      Date | null
  behaviorIssues:  number
}

export class DogStateService {
  constructor(private db: PrismaClient) {}

  async getState(dogId: string): Promise<DogStateSnapshot> {
    const now      = new Date()
    const todayStart = new Date(now)
    todayStart.setHours(0, 0, 0, 0)

    const [walks, plays, trainings, feedings, behaviors, toilets, dimensions] = await Promise.all([
      this.db.walkLog.findMany({ where: { dogId, loggedAt: { gte: todayStart } }, orderBy: { loggedAt: 'desc' } }),
      this.db.playLog.findMany({ where: { dogId, loggedAt: { gte: todayStart } }, orderBy: { loggedAt: 'desc' } }),
      this.db.trainingSessionLog.findMany({ where: { dogId, loggedAt: { gte: todayStart } }, orderBy: { loggedAt: 'desc' } }),
      this.db.feedingLog.findMany({ where: { dogId, loggedAt: { gte: todayStart } }, orderBy: { loggedAt: 'desc' } }),
      this.db.behaviorEvent.findMany({
        where: { dogId, occurredAt: { gte: todayStart } },
        include: { issues: true },
      }),
      this.db.toiletEvent.findMany({ where: { dogId, occurredAt: { gte: new Date(now.getTime() - 8 * 3600_000) } }, orderBy: { occurredAt: 'desc' } }),
      this.db.behaviorDimension.findMany({ where: { dogId } }),
    ])

    const totals: TodayTotals = {
      walkMinutes:     walks.reduce((s, w) => s + w.durationMin, 0),
      playMinutes:     plays.reduce((s, p) => s + p.durationMin, 0),
      trainingMinutes: trainings.reduce((s, t) => s + t.durationMin, 0),
      feedingCount:    feedings.length,
      lastFeedingAt:   feedings[0]?.loggedAt ?? null,
      lastWalkAt:      walks[0]?.loggedAt ?? null,
      lastPlayAt:      plays[0]?.loggedAt ?? null,
      behaviorIssues:  behaviors.reduce((s, b) => s + b.issues.filter(i => i.issue !== 'none').length, 0),
    }

    const totalActivityMin = totals.walkMinutes + totals.playMinutes

    // --- Energy (inverse of activity: resting dog has high energy) ---
    const minutesSinceLastActivity = this.minutesSince(
      totals.lastWalkAt && totals.lastPlayAt
        ? new Date(Math.max(totals.lastWalkAt.getTime(), totals.lastPlayAt.getTime()))
        : totals.lastWalkAt ?? totals.lastPlayAt
    )
    const activityFatigue = Math.min(totalActivityMin / 120, 1) * 50
    const recoveryBoost   = Math.min((minutesSinceLastActivity ?? 60) / 120, 1) * 30
    const energy          = Math.round(Math.max(20, 100 - activityFatigue + recoveryBoost))

    // --- Hunger (time since last feeding) ---
    const hoursSinceFeeding = (this.minutesSince(totals.lastFeedingAt) ?? 240) / 60
    const hunger = Math.round(Math.min(100, (hoursSinceFeeding / 8) * 100))

    // --- Happiness (play + training drive it) ---
    const playScore     = Math.min(totals.playMinutes / 30, 1) * 50
    const trainingScore = Math.min(totals.trainingMinutes / 20, 1) * 20
    const issuesPenalty = Math.min(totals.behaviorIssues * 10, 30)
    const happiness     = Math.round(Math.max(0, 30 + playScore + trainingScore - issuesPenalty))

    // --- Training level (from behavior dimensions) ---
    const avgDimScore = dimensions.length > 0
      ? dimensions.reduce((s, d) => s + (d.currentScore ?? 50), 0) / dimensions.length
      : 50
    const trainingLevel = Math.round(avgDimScore)

    // --- Engagement (bond) ---
    const interactionMinutes = totals.walkMinutes * 0.5 + totals.playMinutes + totals.trainingMinutes * 2
    const engagement = Math.round(Math.min(100, 20 + Math.min(interactionMinutes / 60, 1) * 80))

    // --- Calmness (overstimulation) ---
    const recentIntenseActivity = totals.playMinutes + totals.trainingMinutes
    const calmness = Math.round(Math.max(10, 100 - Math.min(recentIntenseActivity / 60, 1) * 60))

    // --- Confidence ---
    const behaviorPenalty = Math.min(totals.behaviorIssues * 8, 40)
    const confidence = Math.round(Math.max(20, 70 - behaviorPenalty + Math.min(totals.trainingMinutes / 30, 1) * 20))

    // --- Resting? ---
    const lastActivityAt = totals.lastWalkAt ?? totals.lastPlayAt ?? totals.lastFeedingAt
    const minSinceActivity = this.minutesSince(lastActivityAt) ?? 999
    const isResting = minSinceActivity < 30 && totalActivityMin > 20

    // --- Current action (highest priority) ---
    const { currentAction, minutesUntilNextAction } = this.computeCurrentAction(totals, hunger, energy, isResting, now)

    // --- Alerts ---
    const alerts: string[] = []
    if (hunger > 75) alerts.push('Dog is very hungry — time to feed')
    if (totals.walkMinutes === 0 && new Date().getHours() >= 10) alerts.push('No walk yet today')
    if (calmness < 30) alerts.push('Dog may be overstimulated — give rest time')
    if (toilets.length === 0 && new Date().getHours() >= 8) alerts.push('No toilet event logged today')

    return {
      energy, hunger, happiness, trainingLevel,
      engagement, calmness, confidence,
      currentAction, isResting, minutesUntilNextAction,
      alerts,
    }
  }

  private computeCurrentAction(
    totals: TodayTotals,
    hunger: number,
    energy: number,
    isResting: boolean,
    now: Date
  ): { currentAction: string; minutesUntilNextAction: number | null } {
    if (isResting) {
      return { currentAction: 'rest', minutesUntilNextAction: 30 - (this.minutesSince(totals.lastWalkAt ?? totals.lastPlayAt) ?? 0) }
    }
    if (hunger > 70) return { currentAction: 'feeding', minutesUntilNextAction: null }
    if (totals.walkMinutes === 0 && now.getHours() >= 7) return { currentAction: 'walk', minutesUntilNextAction: null }
    if (totals.feedingCount < 2 && now.getHours() >= 12) return { currentAction: 'feeding', minutesUntilNextAction: null }
    if (totals.playMinutes < 15) return { currentAction: 'play', minutesUntilNextAction: null }
    if (totals.trainingMinutes < 10) return { currentAction: 'training', minutesUntilNextAction: null }
    if (totals.walkMinutes < 30) return { currentAction: 'walk', minutesUntilNextAction: null }
    return { currentAction: 'free', minutesUntilNextAction: null }
  }

  private minutesSince(date: Date | null | undefined): number | null {
    if (!date) return null
    return Math.round((Date.now() - date.getTime()) / 60_000)
  }
}
