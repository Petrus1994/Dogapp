import { FastifyInstance } from 'fastify'
import { requireAuth } from '../middleware/auth'
import { DogService } from '../services/DogService'
import { prisma } from '../lib/prisma'
import { todayDate } from '../utils/dates'

export async function progressRoutes(app: FastifyInstance) {
  const dogSvc = new DogService(prisma)

  app.get('/dogs/:dogId/progress/summary', { preHandler: requireAuth }, async (req) => {
    const { dogId } = req.params as { dogId: string }
    await dogSvc.assertOwnership(req.user.userId, dogId)

    const [scores, memory, plan] = await Promise.all([
      prisma.behaviorDimension.findMany({ where: { dogId } }),
      prisma.dogMemory.findUnique({ where: { dogId } }),
      prisma.trainingPlan.findFirst({ where: { dogId, isActive: true }, orderBy: { createdAt: 'desc' } }),
    ])

    return {
      scores:       scores.map((s) => ({ dimension: s.dimension, score: Number(s.score), trend: s.trend, confidence: Number(s.confidence) })),
      recentWins:   memory?.whatWorked ?? [],
      currentFocus: memory?.currentFocusArea,
      planTitle:    plan?.title,
    }
  })

  app.get('/dogs/:dogId/insights/today', { preHandler: requireAuth }, async (req) => {
    const { dogId } = req.params as { dogId: string }
    await dogSvc.assertOwnership(req.user.userId, dogId)

    const insight = await prisma.dailyInsight.findFirst({
      where:   { dogId, insightDate: todayDate() },
      orderBy: { createdAt: 'desc' },
    })

    return insight ?? { insightText: 'Keep logging activities — your daily insight will appear here.', dimensionFocus: null }
  })

  app.post('/dogs/:dogId/progress/shareable', { preHandler: requireAuth }, async (req, reply) => {
    const { dogId } = req.params as { dogId: string }
    const dog       = await dogSvc.assertOwnership(req.user.userId, dogId)
    const scores    = await prisma.behaviorDimension.findMany({ where: { dogId } })
    const memory    = await prisma.dogMemory.findUnique({ where: { dogId } })

    const summaryLines = [
      `${dog.name}'s Training Progress Report`,
      '',
      ...scores.map((s) => `${s.dimension}: ${Number(s.score).toFixed(0)}/100 (${s.trend})`),
      '',
      memory?.currentFocusArea ? `Current focus: ${memory.currentFocusArea}` : '',
    ]

    const summary = await prisma.shareSummary.create({
      data: {
        dogId,
        summaryText: summaryLines.filter(Boolean).join('\n'),
        expiresAt:   new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
      },
    })

    return reply.code(201).send({
      summaryText: summary.summaryText,
      shareUrl:    `https://pawcoach.app/share/${summary.shareUrlToken}`,
    })
  })
}
