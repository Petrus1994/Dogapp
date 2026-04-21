import { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { requireAuth } from '../middleware/auth'
import { DogService } from '../services/DogService'
import { DogStateService } from '../services/DogStateService'
import { DailyPlanService } from '../services/DailyPlanService'
import { ActivityNormService } from '../services/ActivityNormService'
import { prisma } from '../lib/prisma'

const OverrideBody = z.object({
  activityLevelOverride: z.enum(['low', 'medium', 'high']).nullable(),
})

export async function activityRoutes(app: FastifyInstance) {
  const dogSvc   = new DogService(prisma)
  const stateSvc = new DogStateService(prisma)
  const planSvc  = new DailyPlanService(prisma)

  /** GET /dogs/:dogId/state — real-time Tamagotchi state */
  app.get('/dogs/:dogId/state', { preHandler: requireAuth }, async (req) => {
    const { dogId } = req.params as { dogId: string }
    await dogSvc.assertOwnership(req.user.userId, dogId)
    return stateSvc.getState(dogId)
  })

  /** GET /dogs/:dogId/daily-plan — today's structured plan */
  app.get('/dogs/:dogId/daily-plan', { preHandler: requireAuth }, async (req) => {
    const { dogId } = req.params as { dogId: string }
    await dogSvc.assertOwnership(req.user.userId, dogId)
    return planSvc.getDailyPlan(dogId)
  })

  /** GET /dogs/:dogId/activity-norm — raw norm for this dog */
  app.get('/dogs/:dogId/activity-norm', { preHandler: requireAuth }, async (req) => {
    const { dogId } = req.params as { dogId: string }
    const dog = await dogSvc.assertOwnership(req.user.userId, dogId)
    const level = ActivityNormService.resolveLevel(
      dog.activityLevel,
      (dog as any).activityLevelOverride
    )
    return ActivityNormService.getNorm(dog.ageGroup, level)
  })

  /** PATCH /dogs/:dogId/activity-override — set per-dog personality modifier */
  app.patch('/dogs/:dogId/activity-override', { preHandler: requireAuth }, async (req) => {
    const { dogId } = req.params as { dogId: string }
    await dogSvc.assertOwnership(req.user.userId, dogId)
    const { activityLevelOverride } = OverrideBody.parse(req.body)
    return prisma.dog.update({
      where: { id: dogId },
      data:  { activityLevelOverride } as any,
    })
  })
}
