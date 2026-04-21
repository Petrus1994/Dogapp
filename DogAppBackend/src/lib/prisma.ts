import { PrismaClient } from '@prisma/client'
import { logger } from './logger'

export const prisma = new PrismaClient({
  log: [
    { level: 'error', emit: 'event' },
    { level: 'warn',  emit: 'event' },
  ],
})

prisma.$on('error', (e) => {
  logger.error({ source: 'prisma', msg: e.message, target: e.target })
})

prisma.$on('warn', (e) => {
  logger.warn({ source: 'prisma', msg: e.message, target: e.target })
})
