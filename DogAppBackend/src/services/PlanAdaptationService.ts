import { PrismaClient } from '@prisma/client'
import { logger } from '../lib/logger'

// ─── Types ────────────────────────────────────────────────────────────────────

type AdaptationSignal = 'reduce' | 'maintain' | 'increase'

// ─── Service ──────────────────────────────────────────────────────────────────

export class PlanAdaptationService {
  constructor(private db: PrismaClient) {}

  // ── Called after every task feedback submission ───────────────────────────

  async adaptAfterFeedback(planId: string, taskId: string, result: string) {
    const plan = await this.db.trainingPlan.findUnique({
      where:   { id: planId },
      include: { tasks: { include: { feedback: { orderBy: { createdAt: 'desc' }, take: 5 } } } },
    })
    if (!plan) return

    const task = plan.tasks.find(t => t.id === taskId)
    if (!task) return

    // Gather recent results for this task's category
    const categoryTasks = plan.tasks.filter(t => t.category === task.category)
    const recentResults: string[] = []
    for (const t of categoryTasks) {
      recentResults.push(...t.feedback.map(f => f.result))
    }

    const signal = this.computeSignal(recentResults)
    if (signal === 'maintain') return

    // Apply adaptation
    await this.applyAdaptation(task.id, task.difficulty, signal)

    // Update plan metadata
    await this.db.trainingPlan.update({
      where: { id: planId },
      data:  { lastAdaptedAt: new Date() },
    })

    logger.info({ action: 'plan_adapted', planId, taskId, signal, category: task.category })
  }

  // ── Inactivity check — called by daily pg-boss job ────────────────────────

  async checkAndFlagInactivity(userId: string, dogId: string): Promise<boolean> {
    const plan = await this.db.trainingPlan.findFirst({
      where:   { userId, dogId, isActive: true },
      include: { tasks: { orderBy: { scheduledDay: 'asc' } } },
    })
    if (!plan) return false

    // Count tasks that should have been attempted but have no feedback and are still pending
    const daysSinceStart = Math.floor((Date.now() - plan.startDate.getTime()) / 86_400_000)
    const dueTasks = plan.tasks.filter(t => t.scheduledDay <= daysSinceStart && t.status === 'pending')

    const newSkippedCount = Math.min(dueTasks.length, 20)
    if (newSkippedCount === plan.skippedTaskCount) return false

    await this.db.trainingPlan.update({
      where: { id: plan.id },
      data:  { skippedTaskCount: newSkippedCount },
    })

    // Trigger "simpler plan?" if threshold crossed
    const triggered = newSkippedCount >= 5 && plan.skippedTaskCount < 5
    if (triggered) {
      logger.info({ action: 'inactivity_threshold_crossed', userId, dogId, skippedCount: newSkippedCount })
    }
    return triggered
  }

  // ── User accepts "simpler plan" offer ────────────────────────────────────

  async simplifyPlan(userId: string, planId: string) {
    const plan = await this.db.trainingPlan.findFirst({
      where:   { id: planId, userId },
      include: { tasks: true },
    })
    if (!plan) throw new Error('Plan not found')

    // Reduce all pending task difficulties by 1 (floor 1), clear pending status
    for (const task of plan.tasks.filter(t => t.status === 'pending')) {
      const newDifficulty = Math.max(1, task.difficulty - 1)
      await this.db.trainingTask.update({
        where: { id: task.id },
        data: {
          difficulty:   newDifficulty,
          guidanceNote: 'Plan simplified — shorter sessions, less pressure. Build confidence first.',
        },
      })
    }

    await this.db.trainingPlan.update({
      where: { id: planId },
      data: {
        simplifiedAt:    new Date(),
        lastAdaptedAt:   new Date(),
        skippedTaskCount: 0,
        weeklyFocus:     `Rebuilding consistency — ${plan.weeklyFocus}`,
      },
    })

    logger.info({ action: 'plan_simplified', userId, planId })
    return this.db.trainingPlan.findUnique({ where: { id: planId }, include: { tasks: true } })
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  private computeSignal(results: string[]): AdaptationSignal {
    if (results.length < 2) return 'maintain'

    const recent = results.slice(0, 4)  // most recent first
    const failedOrPartial = recent.filter(r => r === 'failed' || r === 'partial').length
    const successes       = recent.filter(r => r === 'success').length

    // 3+ failures in last 4 attempts → reduce
    if (failedOrPartial >= 3) return 'reduce'
    // 4/4 successes → increase
    if (successes === 4)       return 'increase'
    // 3 successes and task is progressing → increase
    if (successes >= 3 && recent[0] === 'success') return 'increase'

    return 'maintain'
  }

  private async applyAdaptation(taskId: string, currentDifficulty: number, signal: AdaptationSignal) {
    if (signal === 'reduce') {
      const newDiff = Math.max(1, currentDifficulty - 1)
      await this.db.trainingTask.update({
        where: { id: taskId },
        data: {
          difficulty:   newDiff,
          guidanceNote: newDiff < currentDifficulty
            ? 'Difficulty reduced based on recent sessions — focus on consistency before increasing challenge.'
            : null,
        },
      })
    } else if (signal === 'increase') {
      const newDiff = Math.min(5, currentDifficulty + 1)
      await this.db.trainingTask.update({
        where: { id: taskId },
        data: {
          difficulty:   newDiff,
          guidanceNote: newDiff > currentDifficulty
            ? 'Great progress! Difficulty increased — try adding distance, duration, or distractions.'
            : null,
        },
      })
    }
  }
}
