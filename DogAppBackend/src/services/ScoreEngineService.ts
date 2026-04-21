import { PrismaClient } from '@prisma/client'
import PgBoss from 'pg-boss'
import { Jobs } from '../lib/jobs'
import { subDays, todayDate } from '../utils/dates'

type Dimension = 'foodBehavior' | 'activityExcitement' | 'ownerContact' | 'socialization'

const DIMENSION_ISSUES: Record<Dimension, string[]> = {
  foodBehavior:        ['beggingForFood', 'pickingFoodFromGround'],
  activityExcitement:  ['overexcitement', 'leashPulling', 'jumpingOnPeople'],
  ownerContact:        ['notResponding', 'ignoringOwner'],
  socialization:       ['reactingToDogs', 'reactingToPeople', 'fearReactions', 'barking'],
}

const DIMENSIONS: Dimension[] = ['foodBehavior', 'activityExcitement', 'ownerContact', 'socialization']

export class ScoreEngineService {
  constructor(private db: PrismaClient, private boss: PgBoss) {}

  async recalculate(dogId: string): Promise<void> {
    const today    = todayDate()
    const window   = subDays(today, 30)
    const priorRef = subDays(today, 7)

    const [signals, events] = await Promise.all([
      this.db.extractedNoteSignal.findMany({
        where: { dogId, createdAt: { gte: window } },
      }),
      this.db.behaviorEvent.findMany({
        where:   { dogId, occurredAt: { gte: window } },
        include: { issues: true },
      }),
    ])

    for (const dimension of DIMENSIONS) {
      const relevantIssues = DIMENSION_ISSUES[dimension]

      // Signal component: average sentiment for this dimension
      const dimSignals = signals.filter((s) => s.dimension === dimension)
      const signalAvg = dimSignals.length > 0
        ? dimSignals.reduce((sum, s) => sum + Number(s.sentimentScore ?? 0), 0) / dimSignals.length
        : 0

      // Event issue penalty
      const issueCount = events.filter((e) =>
        e.issues.some((i) => relevantIssues.includes(i.issue))
      ).length
      const penalty = Math.min(issueCount * 3, 30)

      const rawScore = 50 + signalAvg * 30 - penalty
      const score    = Math.max(0, Math.min(100, rawScore))
      const confidence = Math.min((dimSignals.length + events.length) * 5, 100)

      // Trend vs 7 days ago
      const prior = await this.db.behaviorScoreHistory.findFirst({
        where:   { dogId, dimension, snapshotDate: { lte: priorRef } },
        orderBy: { snapshotDate: 'desc' },
      })

      const diff  = prior ? score - Number(prior.score) : 0
      const trend = diff > 5 ? 'improving' : diff < -5 ? 'needsAttention' : 'stable'

      const snapshotDate = today

      await this.db.$transaction([
        this.db.behaviorDimension.upsert({
          where:  { dogId_dimension: { dogId, dimension } },
          create: { dogId, dimension, score, trend, confidence, lastUpdated: new Date() },
          update: { score, trend, confidence, lastUpdated: new Date() },
        }),
        this.db.behaviorScoreHistory.upsert({
          where:  { dogId_dimension_snapshotDate: { dogId, dimension, snapshotDate } },
          create: { dogId, dimension, snapshotDate, score, confidence, activityCount: dimSignals.length + events.length },
          update: { score, confidence, activityCount: dimSignals.length + events.length },
        }),
      ])
    }

    // After scores update, refresh memory snapshot
    await this.boss.send(Jobs.MEMORY_REFRESH, { dogId }, { singletonKey: `memory:${dogId}` })
  }
}
