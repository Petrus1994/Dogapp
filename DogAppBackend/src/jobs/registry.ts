import PgBoss from 'pg-boss'
import { PrismaClient } from '@prisma/client'
import OpenAI from 'openai'
import { Jobs } from '../lib/jobs'
import { logger } from '../lib/logger'
import { NoteExtractionService } from '../services/NoteExtractionService'
import { ScoreEngineService }    from '../services/ScoreEngineService'
import { MemoryPreparationService } from '../services/MemoryPreparationService'
import { PlanAdaptationService }    from '../services/PlanAdaptationService'

export async function registerJobs(boss: PgBoss, db: PrismaClient, openai: OpenAI) {
  const noteExtractor = new NoteExtractionService(db, openai)
  const scoreEngine   = new ScoreEngineService(db, boss)
  const memoryService = new MemoryPreparationService(db)
  const planAdaptation = new PlanAdaptationService(db)

  // Note extraction
  await boss.work<{ noteId: string }>(Jobs.NOTE_EXTRACT, async (jobs) => {
    const job = Array.isArray(jobs) ? jobs[0] : jobs
    const { noteId } = job.data
    logger.info({ job: Jobs.NOTE_EXTRACT, noteId })
    await noteExtractor.extract(noteId)
  })

  // Score recalculation
  await boss.work<{ dogId: string }>(Jobs.SCORES_RECALCULATE, async (jobs) => {
    const job = Array.isArray(jobs) ? jobs[0] : jobs
    const { dogId } = job.data
    logger.info({ job: Jobs.SCORES_RECALCULATE, dogId })
    await scoreEngine.recalculate(dogId)
  })

  // Memory refresh
  await boss.work<{ dogId: string }>(Jobs.MEMORY_REFRESH, async (jobs) => {
    const job = Array.isArray(jobs) ? jobs[0] : jobs
    const { dogId } = job.data
    logger.info({ job: Jobs.MEMORY_REFRESH, dogId })
    await memoryService.buildAndStore(dogId)
  })

  // Daily insight generation — scheduled via cron
  // work() must run first: pg-boss creates the queue row internally when a worker is registered.
  // schedule() has a FK constraint on pgboss.schedule.name → pgboss.queue.name, so the queue
  // row must exist before schedule() fires. createQueue() is kept as an additional idempotent
  // safety net but work() is what reliably commits the row.
  await boss.work(Jobs.DAILY_INSIGHT, async () => {
    logger.info({ job: Jobs.DAILY_INSIGHT })
    const dogs = await db.dog.findMany({ where: { isActive: true, deletedAt: null } })
    for (const dog of dogs) {
      await boss.send(Jobs.MEMORY_REFRESH, { dogId: dog.id })

      // Check plan inactivity for each active dog's owner
      const triggered = await planAdaptation.checkAndFlagInactivity(dog.userId, dog.id)
      if (triggered) {
        logger.info({ action: 'inactivity_flagged', userId: dog.userId, dogId: dog.id })
        // The iOS app polls /plans/:planId/adaptation-status on launch and after each log
        // No push needed here — the next app open will surface the banner
      }
    }
  })

  try {
    await boss.createQueue(Jobs.DAILY_INSIGHT)
    logger.info('[JOBS] Queue daily.insight ensured')

    await boss.schedule(Jobs.DAILY_INSIGHT, '0 8 * * *', {}) // 08:00 UTC daily
    logger.info('[JOBS] Schedule daily.insight ensured')
  } catch (err: any) {
    logger.error({ err: err?.message ?? err }, '[JOBS] Failed to ensure daily.insight queue/schedule (non-fatal)')
  }

  logger.info('All background jobs registered')
}
