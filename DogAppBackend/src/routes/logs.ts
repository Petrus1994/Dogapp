import { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { requireAuth } from '../middleware/auth'
import { DailyLogService } from '../services/DailyLogService'
import { DogService } from '../services/DogService'
import { prisma } from '../lib/prisma'
import { boss } from '../lib/jobs'

const WalkBody = z.object({
  loggedAt:        z.string().datetime().optional(),
  durationMinutes: z.number().int().min(1).max(600),
  distanceKm:      z.number().optional(),
  walkQuality:     z.enum(['calm', 'pulling', 'distracted']).optional(),
  stepCount:       z.number().int().optional(),
  notes:           z.string().max(2000).optional(),
})

const FeedingBody = z.object({
  loggedAt:      z.string().datetime().optional(),
  foodType:      z.enum(['dry', 'wet', 'natural', 'mixed']).optional(),
  feedingNumber: z.number().int().min(1).max(6).optional(),
  durationMin:   z.number().int().optional(),
  notes:         z.string().max(2000).optional(),
})

const PlayBody = z.object({
  loggedAt:        z.string().datetime().optional(),
  durationMinutes: z.number().int().min(1).max(240),
  playActivity:    z.string().optional(),
  notes:           z.string().max(2000).optional(),
})

const TrainingBody = z.object({
  loggedAt:        z.string().datetime().optional(),
  durationMinutes: z.number().int().min(1).max(120),
  notes:           z.string().max(2000).optional(),
})

const ToiletBody = z.object({
  occurredAt:               z.string().datetime(),
  outcome:                  z.enum(['success', 'accident', 'prompted']),
  minutesAfterLastFeeding:  z.number().int().optional(),
  minutesAfterLastSleep:    z.number().int().optional(),
  notes:                    z.string().max(1000).optional(),
})

const BehaviorBody = z.object({
  occurredAt:   z.string().datetime(),
  activityType: z.enum(['feeding', 'walking', 'playing', 'training']).optional(),
  issues:       z.array(z.string()),
  notes:        z.string().max(2000).optional(),
})

export async function logRoutes(app: FastifyInstance) {
  const dogSvc = new DogService(prisma)
  const logSvc = new DailyLogService(prisma, boss)

  async function resolvedog(userId: string, dogId: string) {
    return dogSvc.assertOwnership(userId, dogId)
  }

  app.post('/dogs/:dogId/logs/walk', { preHandler: requireAuth }, async (req, reply) => {
    const { dogId } = req.params as { dogId: string }
    await resolvedog(req.user.userId, dogId)
    const body = WalkBody.parse(req.body)
    const log  = await logSvc.logWalk(dogId, {
      ...body,
      loggedAt: body.loggedAt ? new Date(body.loggedAt) : undefined,
    })
    return reply.code(201).send(log)
  })

  app.post('/dogs/:dogId/logs/feeding', { preHandler: requireAuth }, async (req, reply) => {
    const { dogId } = req.params as { dogId: string }
    await resolvedog(req.user.userId, dogId)
    const body = FeedingBody.parse(req.body)
    const log  = await logSvc.logFeeding(dogId, {
      ...body,
      loggedAt: body.loggedAt ? new Date(body.loggedAt) : undefined,
    })
    return reply.code(201).send(log)
  })

  app.post('/dogs/:dogId/logs/play', { preHandler: requireAuth }, async (req, reply) => {
    const { dogId } = req.params as { dogId: string }
    await resolvedog(req.user.userId, dogId)
    const body = PlayBody.parse(req.body)
    const log  = await logSvc.logPlay(dogId, {
      ...body,
      loggedAt: body.loggedAt ? new Date(body.loggedAt) : undefined,
    })
    return reply.code(201).send(log)
  })

  app.post('/dogs/:dogId/logs/training', { preHandler: requireAuth }, async (req, reply) => {
    const { dogId } = req.params as { dogId: string }
    await resolvedog(req.user.userId, dogId)
    const body = TrainingBody.parse(req.body)
    const log  = await logSvc.logTraining(dogId, {
      ...body,
      loggedAt: body.loggedAt ? new Date(body.loggedAt) : undefined,
    })
    return reply.code(201).send(log)
  })

  app.post('/dogs/:dogId/logs/toilet', { preHandler: requireAuth }, async (req, reply) => {
    const { dogId } = req.params as { dogId: string }
    await resolvedog(req.user.userId, dogId)
    const body = ToiletBody.parse(req.body)
    const log  = await logSvc.logToilet(dogId, { ...body, occurredAt: new Date(body.occurredAt) })
    return reply.code(201).send(log)
  })

  app.post('/dogs/:dogId/logs/behavior', { preHandler: requireAuth }, async (req, reply) => {
    const { dogId } = req.params as { dogId: string }
    await resolvedog(req.user.userId, dogId)
    const body = BehaviorBody.parse(req.body)
    const log  = await logSvc.logBehavior(dogId, { ...body, occurredAt: new Date(body.occurredAt) })
    return reply.code(201).send(log)
  })

  app.get('/dogs/:dogId/logs/today', { preHandler: requireAuth }, async (req) => {
    const { dogId } = req.params as { dogId: string }
    await resolvedog(req.user.userId, dogId)
    return logSvc.getTodayLogs(dogId)
  })

  app.get('/dogs/:dogId/logs/range', { preHandler: requireAuth }, async (req, reply) => {
    const { dogId } = req.params as { dogId: string }
    await resolvedog(req.user.userId, dogId)
    const { from, to } = req.query as { from?: string; to?: string }
    if (!from || !to) {
      return reply.code(400).send({ error: 'from and to query params are required (ISO 8601)' })
    }
    const fromDate = new Date(from)
    const toDate   = new Date(to)
    if (isNaN(fromDate.getTime()) || isNaN(toDate.getTime())) {
      return reply.code(400).send({ error: 'Invalid date format. Use ISO 8601.' })
    }
    return logSvc.getLogsForRange(dogId, fromDate, toDate)
  })
}
