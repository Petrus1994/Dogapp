import PgBoss from 'pg-boss'
import { config } from '../config'
import { logger } from './logger'

export const boss = new PgBoss({
  connectionString: config.db.url,
  retryLimit:       3,
  retryDelay:       60,       // seconds between retries
  retryBackoff:     true,
  deleteAfterDays:  7,
  monitorStateIntervalSeconds: 60,
})

boss.on('error', (err) => {
  logger.error({ source: 'pg-boss', err }, 'Job queue error')
})

// Job name constants — single source of truth
export const Jobs = {
  NOTE_EXTRACT:       'note.extract',
  MEMORY_REFRESH:     'memory.refresh',
  SCORES_RECALCULATE: 'scores.recalculate',
  DAILY_INSIGHT:      'daily.insight',
  PUSH_SEND:          'push.send',
  PUSH_SCHEDULE:      'push.schedule',
  SUBSCRIPTION_SYNC:  'subscription.sync',
} as const
