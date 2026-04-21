import PgBoss from 'pg-boss'
import { PrismaClient } from '@prisma/client'
import OpenAI from 'openai'
import { Jobs } from '../lib/jobs'
import { logger } from '../lib/logger'
import { NoteExtractionService } from '../services/NoteExtractionService'
import { ScoreEngineService }    from '../services/ScoreEngineService'
import { MemoryPreparationService } from '../services/MemoryPreparationService'

export async function registerJobs(boss: PgBoss, db: PrismaClient, openai: OpenAI) {
  const noteExtractor = new NoteExtractionService(db, openai)
  const scoreEngine   = new ScoreEngineService(db, boss)
  const memoryService = new MemoryPreparationService(db)

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
  await boss.schedule(Jobs.DAILY_INSIGHT, '0 8 * * *', {}) // 08:00 UTC daily
  await boss.work(Jobs.DAILY_INSIGHT, async () => {
    logger.info({ job: Jobs.DAILY_INSIGHT })
    // Get all active dogs and generate insights
    const dogs = await db.dog.findMany({ where: { isActive: true, deletedAt: null } })
    for (const dog of dogs) {
      await boss.send(Jobs.MEMORY_REFRESH, { dogId: dog.id })
    }
  })

  logger.info('All background jobs registered')
}
