import { PrismaClient } from '@prisma/client'

export class LearningProfileService {
  constructor(private db: PrismaClient) {}

  // Called after each simulation is evaluated. Updates strengths, gaps, scores.
  async updateAfterSimulation(
    userId:            string,
    futureDogProfileId: string,
    score:             number,
    learningTags:      string[],
    whatToImprove:     string,
  ): Promise<void> {

    let profile = await this.db.userLearningProfile.findUnique({
      where: { futureDogProfileId },
    })

    if (!profile) {
      profile = await this.db.userLearningProfile.create({
        data: { userId, futureDogProfileId },
      })
    }

    const completedCount = await this.db.simulationSession.count({
      where: { futureDogProfileId, completed: true },
    })

    // Rolling consistency score: weighted average of all scenario scores
    const allScores = await this.db.simulationSession.findMany({
      where:  { futureDogProfileId, completed: true },
      select: { score: true },
    })
    const avg = allScores.reduce((sum, s) => sum + (s.score ?? 0), 0) / (allScores.length || 1)
    const consistencyScore = avg / 100

    // Extract strengths (tags from high-scoring sessions ≥75)
    const highScoreSessions = await this.db.simulationSession.findMany({
      where:  { futureDogProfileId, completed: true, score: { gte: 75 } },
      select: { score: true },
      take:   20,
    })

    // Derive readable strength labels from tag frequency
    const allTagSessions = await this.db.simulationSession.findMany({
      where:  { futureDogProfileId, completed: true },
      select: { score: true, category: true },
    })

    const strongCategories = allTagSessions
      .filter(s => (s.score ?? 0) >= 75)
      .map(s => categoryLabel(s.category))

    const weakCategories = allTagSessions
      .filter(s => (s.score ?? 0) < 55)
      .map(s => categoryLabel(s.category))

    const knownStrengths = [...new Set(strongCategories)].slice(0, 5)
    const knownGaps = [...new Set(weakCategories)].slice(0, 5)

    // Readiness: scaled by count and quality
    const countFactor  = Math.min(completedCount / 15, 1)  // max at 15 scenarios
    const qualityFactor = consistencyScore
    const readiness     = (countFactor * 0.4 + qualityFactor * 0.6)

    await this.db.userLearningProfile.update({
      where: { futureDogProfileId },
      data:  {
        decisionsAnalyzed:    { increment: 1 },
        scenariosCompleted:   completedCount,
        consistencyScore:     consistencyScore,
        knownStrengths,
        knownGaps,
        overallReadinessScore: readiness,
        lastUpdatedAt:         new Date(),
      },
    })
  }

  async getProfile(futureDogProfileId: string) {
    return this.db.userLearningProfile.findUnique({ where: { futureDogProfileId } })
  }

  // Builds an AI context block for injection when user transitions to real dog mode
  async buildTransitionContext(futureDogProfileId: string): Promise<string> {
    const [fdProfile, learningProfile, sessions] = await Promise.all([
      this.db.futureDogProfile.findUnique({ where: { id: futureDogProfileId } }),
      this.db.userLearningProfile.findUnique({ where: { futureDogProfileId } }),
      this.db.simulationSession.findMany({
        where:   { futureDogProfileId, completed: true },
        orderBy: { completedAt: 'desc' },
        take:    5,
        select:  { category: true, score: true, whatToImprove: true },
      }),
    ])

    if (!fdProfile || !learningProfile) return ''

    const weeks = Math.floor(
      (Date.now() - fdProfile.createdAt.getTime()) / (7 * 24 * 60 * 60 * 1000)
    )

    let block = `\nFUTURE DOG PREPARATION HISTORY\n`
    block += `This user spent ${weeks > 0 ? `${weeks} week${weeks > 1 ? 's' : ''}` : 'time'} preparing in Future Dog Mode before getting their dog.\n`
    block += `Scenarios completed: ${learningProfile.scenariosCompleted}\n`
    block += `Consistency score: ${Math.round(Number(learningProfile.consistencyScore) * 100)}%\n`
    block += `Readiness at time of transition: ${Math.round(Number(learningProfile.overallReadinessScore) * 100)}%\n`

    if (learningProfile.knownStrengths.length > 0) {
      block += `Areas of strength: ${learningProfile.knownStrengths.join(', ')}\n`
    }
    if (learningProfile.knownGaps.length > 0) {
      block += `Known gaps to address: ${learningProfile.knownGaps.join(', ')}\n`
    }
    if (fdProfile.preferredBreed) {
      block += `Prepared for breed: ${fdProfile.preferredBreed}\n`
    }

    block += `\nIMPORTANT: Reference this preparation history when coaching. Acknowledge what they already understand. Build on their foundation rather than starting from zero. When a known gap is relevant, address it directly.\n`

    return block
  }
}

function categoryLabel(category: string): string {
  const labels: Record<string, string> = {
    first_walk:    'leash & walk handling',
    home_arrival:  'settling & routine',
    feeding:       'resource management',
    socialization: 'socialization & meeting others',
    evening_calm:  'calm & wind-down routines',
  }
  return labels[category] ?? category.replace('_', ' ')
}
