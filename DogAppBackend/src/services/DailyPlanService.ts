import { PrismaClient } from '@prisma/client'
import { ActivityNormService, ActivityLevel, ActivityNorm } from './ActivityNormService'
import { todayDate } from '../utils/dates'

export interface PlannedSession {
  index:        number        // 1-based session number
  type:         'walk' | 'play' | 'training' | 'feeding' | 'rest'
  suggestedTime: string       // e.g. "08:00"
  minMinutes:   number
  maxMinutes:   number
  minKm?:       number
  maxKm?:       number
  completed:    boolean
  loggedMinutes?: number
}

export interface DailyPlan {
  dogId:           string
  date:            string
  norm:            ActivityNorm
  effectiveLevel:  ActivityLevel
  sessions:        PlannedSession[]
  summary: {
    totalWalkMin:    { min: number; max: number }
    totalPlayMin:    { min: number; max: number }
    totalActivityMin:{ min: number; max: number }
    walkKm:          { min: number; max: number }
    completionPct:   number    // 0–100 based on logged vs target
    underActivity:   boolean
    overActivity:    boolean
    playDeficit:     boolean
  }
  aiHints: string[]
}

// Fixed feeding times by age group
const FEEDING_SCHEDULE: Record<string, string[]> = {
  '2-3m': ['07:00', '10:00', '13:00', '16:00', '19:00', '22:00'],
  '4-6m': ['07:00', '12:00', '17:00', '21:00'],
  '6-9m': ['07:00', '13:00', '19:00'],
  '9-12m':['07:00', '13:00', '19:00'],
  default:['07:30', '19:00'],
}

export class DailyPlanService {
  constructor(private db: PrismaClient) {}

  async getDailyPlan(dogId: string): Promise<DailyPlan> {
    const dog = await this.db.dog.findUniqueOrThrow({ where: { id: dogId } })
    const today = todayDate()

    const effectiveLevel = ActivityNormService.resolveLevel(
      dog.activityLevel,
      (dog as any).activityLevelOverride
    )
    const norm = ActivityNormService.getNorm(dog.ageGroup, effectiveLevel)

    // Today's logged activities
    const [walks, plays, trainings] = await Promise.all([
      this.db.walkLog.findMany({ where: { dogId, loggedAt: { gte: today } } }),
      this.db.playLog.findMany({ where: { dogId, loggedAt: { gte: today } } }),
      this.db.trainingSessionLog.findMany({ where: { dogId, loggedAt: { gte: today } } }),
    ])

    const loggedWalkMin  = walks.reduce((s, w) => s + w.durationMin, 0)
    const loggedPlayMin  = plays.reduce((s, p) => s + p.durationMin, 0)
    const loggedTrainMin = trainings.reduce((s, t) => s + t.durationMin, 0)
    const loggedTotalMin = loggedWalkMin + loggedPlayMin

    // Build sessions
    const sessions: PlannedSession[] = []
    const sessionCount = norm.minSessions
    const walkPerSession  = Math.round(norm.minMinutes * (1 - norm.minPlayRatio) / sessionCount)
    const playPerSession  = Math.round(norm.minMinutes * norm.minPlayRatio / sessionCount)
    const kmPerSession    = +(norm.minKm / sessionCount).toFixed(2)

    // Generate walk + play sessions with suggested times
    const sessionStartHours = this.distributeSessionTimes(sessionCount)

    for (let i = 0; i < sessionCount; i++) {
      const hour = sessionStartHours[i]
      const loggedForSession = i === 0 ? loggedWalkMin : 0  // attribute first session to first log

      sessions.push({
        index: i + 1,
        type: 'walk',
        suggestedTime: `${String(hour).padStart(2, '0')}:00`,
        minMinutes: walkPerSession,
        maxMinutes: Math.round(norm.maxMinutes * (1 - norm.maxPlayRatio) / sessionCount),
        minKm: kmPerSession,
        maxKm: +(norm.maxKm / sessionCount).toFixed(2),
        completed: i === 0 ? loggedWalkMin >= walkPerSession : false,
        loggedMinutes: i === 0 ? loggedWalkMin : undefined,
      })

      sessions.push({
        index: i + 1,
        type: 'play',
        suggestedTime: `${String(hour + 1).padStart(2, '0')}:00`,
        minMinutes: playPerSession,
        maxMinutes: Math.round(norm.maxMinutes * norm.maxPlayRatio / sessionCount),
        completed: i === 0 ? loggedPlayMin >= playPerSession : false,
        loggedMinutes: i === 0 ? loggedPlayMin : undefined,
      })
    }

    // Add training (once per day, after first walk)
    sessions.push({
      index: 1,
      type: 'training',
      suggestedTime: `${String(sessionStartHours[0] + 2).padStart(2, '0')}:00`,
      minMinutes: 10,
      maxMinutes: 20,
      completed: loggedTrainMin >= 10,
      loggedMinutes: loggedTrainMin,
    })

    // Add feeding slots
    const feedingTimes = FEEDING_SCHEDULE[norm.ageGroup] ?? FEEDING_SCHEDULE.default
    feedingTimes.forEach((time, idx) => {
      sessions.push({ index: idx + 1, type: 'feeding', suggestedTime: time, minMinutes: 10, maxMinutes: 20, completed: false })
    })

    // Sort by suggested time
    sessions.sort((a, b) => a.suggestedTime.localeCompare(b.suggestedTime))

    // Summary
    const minWalk = Math.round(norm.minMinutes * (1 - norm.maxPlayRatio))
    const maxWalk = Math.round(norm.maxMinutes * (1 - norm.minPlayRatio))
    const minPlay = Math.round(norm.minMinutes * norm.minPlayRatio)
    const maxPlay = Math.round(norm.maxMinutes * norm.maxPlayRatio)
    const completionPct = Math.round(Math.min((loggedTotalMin / norm.minMinutes) * 100, 100))

    const aiHints = this.buildAiHints(norm, loggedWalkMin, loggedPlayMin, loggedTotalMin, dog.ageGroup)

    return {
      dogId,
      date: today.toISOString().split('T')[0],
      norm,
      effectiveLevel,
      sessions,
      summary: {
        totalWalkMin:     { min: minWalk, max: maxWalk },
        totalPlayMin:     { min: minPlay, max: maxPlay },
        totalActivityMin: { min: norm.minMinutes, max: norm.maxMinutes },
        walkKm:           { min: norm.minKm, max: norm.maxKm },
        completionPct,
        underActivity: loggedTotalMin < norm.minMinutes * 0.5,
        overActivity:  loggedTotalMin > norm.maxMinutes * 1.2,
        playDeficit:   loggedPlayMin < norm.minMinutes * norm.minPlayRatio * 0.5,
      },
      aiHints,
    }
  }

  private distributeSessionTimes(count: number): number[] {
    if (count === 1) return [8]
    if (count === 2) return [8, 18]
    if (count === 3) return [7, 13, 18]
    if (count === 4) return [7, 11, 15, 19]
    if (count === 5) return [7, 10, 13, 16, 19]
    if (count === 6) return [7, 9, 12, 14, 17, 20]
    return [7, 9, 11, 13, 15, 17, 19, 21].slice(0, count)
  }

  private buildAiHints(
    norm: ActivityNorm,
    walkMin: number,
    playMin: number,
    totalMin: number,
    ageGroup: string
  ): string[] {
    const hints: string[] = []
    const targetPlay = norm.minMinutes * norm.minPlayRatio

    if (totalMin < norm.minMinutes * 0.3) {
      hints.push(`Start with a short ${norm.minSessions > 3 ? 'puppy walk' : 'walk'} — even ${Math.round(norm.minMinutes / norm.minSessions)} min counts.`)
    }
    if (playMin < targetPlay * 0.5 && totalMin > 0) {
      hints.push(`Play is below target. Add ${Math.round(targetPlay - playMin)} more minutes of active play.`)
    }
    if (walkMin > norm.maxMinutes * (1 - norm.minPlayRatio) * 1.1) {
      hints.push('Walk duration is high today. Ensure rest time before the next session.')
    }
    if (['2-3m', '4-6m'].includes(norm.ageGroup)) {
      hints.push('Puppy rule: short sessions, frequent breaks. Never exceed 5 min per month of age per walk.')
    }
    return hints
  }
}
