import { PrismaClient } from '@prisma/client'
import { subDays, todayDate } from '../utils/dates'

export class MemoryPreparationService {
  constructor(private db: PrismaClient) {}

  async getSnapshot(dogId: string): Promise<string> {
    const memory = await this.db.dogMemory.findUnique({ where: { dogId } })
    // Return cached snapshot if fresh (< 2 hours old)
    if (memory?.aiContextSnapshot && memory.snapshotGeneratedAt) {
      const ageMs = Date.now() - memory.snapshotGeneratedAt.getTime()
      if (ageMs < 2 * 60 * 60 * 1000) return memory.aiContextSnapshot
    }
    return this.buildAndStore(dogId)
  }

  async buildAndStore(dogId: string): Promise<string> {
    const snapshot = await this.build(dogId)
    await this.db.dogMemory.update({
      where: { dogId },
      data:  { aiContextSnapshot: snapshot, snapshotGeneratedAt: new Date() },
    })
    return snapshot
  }

  private async build(dogId: string): Promise<string> {
    const today = todayDate()
    const window14 = subDays(today, 14)
    const window7  = subDays(today, 7)

    const [dog, scores, triggers, signals, todayWalks, todayFeedings, todayPlays, recentFeedback, plan] =
      await Promise.all([
        this.db.dog.findUniqueOrThrow({ where: { id: dogId }, include: { issues: true, memory: true } }),
        this.db.behaviorDimension.findMany({ where: { dogId } }),
        this.db.recurringTrigger.findMany({
          where:   { dogId, isResolved: false },
          orderBy: { occurrenceCount: 'desc' },
          take:    5,
        }),
        this.db.extractedNoteSignal.findMany({
          where:   { dogId, createdAt: { gte: window14 } },
          orderBy: { createdAt: 'desc' },
          take:    20,
        }),
        this.db.walkLog.findMany({
          where:   { dogId, loggedAt: { gte: today } },
        }),
        this.db.feedingLog.findMany({
          where:   { dogId, loggedAt: { gte: today } },
        }),
        this.db.playLog.findMany({
          where:   { dogId, loggedAt: { gte: today } },
        }),
        this.db.taskFeedback.findMany({
          where:   { dogId, createdAt: { gte: window7 } },
          include: { task: true },
          take:    10,
        }),
        this.db.trainingPlan.findFirst({
          where:   { dogId, isActive: true },
          orderBy: { createdAt: 'desc' },
        }),
      ])

    const sortedScores = [...scores].sort((a, b) => Number(a.score) - Number(b.score))
    const weakest = sortedScores[0]

    const issuesList = dog.issues.map((i) => i.issue).join(', ') || 'None reported'

    const scoresBlock = scores.length > 0
      ? scores.map((s) =>
          `  ${s.dimension}: ${Number(s.score).toFixed(0)}/100  trend=${s.trend}  confidence=${Number(s.confidence).toFixed(0)}%`
        ).join('\n')
      : '  No scores yet — keep logging activities'

    const triggersBlock = triggers.length > 0
      ? triggers.map((t) => `  - ${t.triggerPattern} [seen ${t.occurrenceCount}×]`).join('\n')
      : '  None identified yet'

    const recentSignals = signals.slice(0, 8)
      .map((s) => `  [${s.signalType}] ${s.content}`)
      .join('\n') || '  No recent signals'

    const todayWalkMin = todayWalks.reduce((s, w) => s + w.durationMin, 0)
    const todayFeedCount = todayFeedings.length
    const todayPlayMin  = todayPlays.reduce((s, p) => s + p.durationMin, 0)

    const feedbackSummary = recentFeedback.length > 0
      ? recentFeedback.map((f) => `  ${f.task.title}: ${f.result}`).join('\n')
      : '  No recent task feedback'

    return `=== DOG MEMORY CONTEXT ===

DOG PROFILE
Name: ${dog.name}
Age group: ${dog.ageGroup}
Breed: ${dog.breed ?? 'Unknown / Mixed'}
Sex: ${dog.gender}
Activity level: ${dog.activityLevel}
Known issues: ${issuesList}

BEHAVIOR SCORES (0–100, higher = better)
${scoresBlock}
Priority focus: ${weakest ? `${weakest.dimension} (score ${Number(weakest.score).toFixed(0)})` : 'none yet'}

RECURRING TRIGGERS (unresolved)
${triggersBlock}

WHAT WORKED PREVIOUSLY
${dog.memory?.whatWorked?.length ? dog.memory.whatWorked.map((w) => `  - ${w}`).join('\n') : '  No confirmed techniques yet'}

WHAT FAILED PREVIOUSLY
${dog.memory?.whatFailed?.length ? dog.memory.whatFailed.map((w) => `  - ${w}`).join('\n') : '  No failures recorded yet'}

TODAY'S ACTIVITY LOG
  Walks: ${todayWalks.length} session(s), ${todayWalkMin} min total
  Feedings: ${todayFeedCount} feeding(s)
  Play: ${todayPlays.length} session(s), ${todayPlayMin} min total

RECENT SIGNALS (last 14 days)
${recentSignals}

RECENT TASK PERFORMANCE
${feedbackSummary}

TRAINING PLAN
${plan ? `${plan.title} — focus: ${plan.weeklyFocus}` : 'No active training plan'}

=== END MEMORY ===`.trim()
  }
}
