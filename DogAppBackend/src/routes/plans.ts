import { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { requireAuth } from '../middleware/auth'
import { PlanService } from '../services/PlanService'
import { PlanAdaptationService } from '../services/PlanAdaptationService'
import { prisma } from '../lib/prisma'
import { openai } from '../lib/openai'

const FeedbackBody = z.object({
  result:           z.enum(['success', 'partial', 'failed']),
  timingNote:       z.string().optional(),
  situationNote:    z.string().optional(),
  dogBehaviorNote:  z.string().optional(),
  freeText:         z.string().optional(),
  dogId:            z.string().optional(),
})

const TaskUpdateBody = z.object({
  status: z.enum(['pending', 'completed', 'partial', 'failed']),
  notes:  z.string().optional(),
})

const SimplifyBody = z.object({ planId: z.string() })

export async function planRoutes(app: FastifyInstance) {
  const svc        = new PlanService(prisma, openai)
  const adaptation = new PlanAdaptationService(prisma)

  app.post('/dogs/:dogId/plans/generate', { preHandler: requireAuth }, async (req, reply) => {
    const { dogId } = req.params as { dogId: string }
    const plan = await svc.generatePlan(req.user.userId, dogId)
    return reply.code(201).send(plan)
  })

  app.post('/plans/generate', { preHandler: requireAuth }, async (req, reply) => {
    const plan = await svc.generatePlan(req.user.userId, null)
    return reply.code(201).send(plan)
  })

  app.get('/dogs/:dogId/plans/active', { preHandler: requireAuth }, async (req) => {
    const { dogId } = req.params as { dogId: string }
    return svc.getActivePlan(req.user.userId, dogId)
  })

  app.patch('/tasks/:taskId', { preHandler: requireAuth }, async (req) => {
    const { taskId } = req.params as { taskId: string }
    const body = TaskUpdateBody.parse(req.body)
    return svc.updateTaskStatus(req.user.userId, taskId, body.status, body.notes)
  })

  app.post('/tasks/:taskId/feedback', { preHandler: requireAuth }, async (req, reply) => {
    const { taskId } = req.params as { taskId: string }
    const body       = FeedbackBody.parse(req.body)
    const feedback   = await svc.submitFeedback(req.user.userId, body.dogId ?? null, taskId, body)

    // Trigger plan adaptation asynchronously — does not block response
    const task = await prisma.trainingTask.findUnique({ where: { id: taskId } })
    if (task) {
      adaptation.adaptAfterFeedback(task.planId, taskId, body.result).catch(() => {})
    }

    return reply.code(201).send(feedback)
  })

  // POST /v1/plans/simplify — user accepts "life's been busy" offer
  app.post('/plans/simplify', { preHandler: requireAuth }, async (req, reply) => {
    const { planId } = SimplifyBody.parse(req.body)
    const updated    = await adaptation.simplifyPlan(req.user.userId, planId)
    return reply.code(200).send(updated)
  })

  // GET /v1/plans/:planId/adaptation-status — iOS polls to show/hide simplify banner
  app.get('/plans/:planId/adaptation-status', { preHandler: requireAuth }, async (req) => {
    const { planId } = req.params as { planId: string }
    const plan = await prisma.trainingPlan.findFirst({
      where: { id: planId, userId: req.user.userId },
      select: { skippedTaskCount: true, simplifiedAt: true, lastAdaptedAt: true },
    })
    return {
      skippedTaskCount:    plan?.skippedTaskCount ?? 0,
      offerSimplification: (plan?.skippedTaskCount ?? 0) >= 5 && !plan?.simplifiedAt,
      simplifiedAt:        plan?.simplifiedAt ?? null,
      lastAdaptedAt:       plan?.lastAdaptedAt ?? null,
    }
  })
}
