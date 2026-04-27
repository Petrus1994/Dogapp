import { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { requireAuth } from '../middleware/auth'
import { SimulationEngine } from '../services/SimulationEngine'
import { LearningProfileService } from '../services/LearningProfileService'
import { prisma } from '../lib/prisma'
import { openai } from '../lib/openai'
import { Errors } from '../lib/errors'

const ProfileBody = z.object({
  dogName:          z.string().optional(),
  preferredBreed:   z.string().optional(),
  lifestyle:        z.enum(['active', 'moderate', 'calm']),
  homeType:         z.enum(['apartment', 'house_small', 'house_large', 'rural']),
  timeAvailability: z.enum(['low', 'moderate', 'high']),
  expectedSize:     z.enum(['small', 'medium', 'large']).optional(),
  preparationStage: z.enum(['exploring', 'committed', 'ready']).optional(),
})

const RespondBody = z.object({
  userResponse: z.string().min(1).max(3000),
})

const GenerateBody = z.object({
  category: z.enum(['first_walk', 'home_arrival', 'feeding', 'socialization', 'evening_calm']).optional(),
})

export async function futureDogRoutes(app: FastifyInstance) {
  const simulation = new SimulationEngine(prisma, openai)
  const learning   = new LearningProfileService(prisma)

  // ─── Profile ──────────────────────────────────────────────────────────────

  app.get('/future-dog/profile', { preHandler: requireAuth }, async (req) => {
    const profile = await prisma.futureDogProfile.findUnique({
      where:   { userId: req.user.userId },
      include: { learningProfile: true },
    })
    return profile ?? { exists: false }
  })

  app.put('/future-dog/profile', { preHandler: requireAuth }, async (req) => {
    const body = ProfileBody.parse(req.body)
    const profile = await prisma.futureDogProfile.upsert({
      where:  { userId: req.user.userId },
      create: { userId: req.user.userId, ...body },
      update: body,
    })

    // Ensure a learning profile row exists
    await prisma.userLearningProfile.upsert({
      where:  { futureDogProfileId: profile.id },
      create: { userId: req.user.userId, futureDogProfileId: profile.id },
      update: {},
    })

    return profile
  })

  // ─── Learning profile ─────────────────────────────────────────────────────

  app.get('/future-dog/learning', { preHandler: requireAuth }, async (req) => {
    const fdProfile = await prisma.futureDogProfile.findUnique({
      where: { userId: req.user.userId },
    })
    if (!fdProfile) throw Errors.notFound('Future dog profile')

    const learningProfile = await learning.getProfile(fdProfile.id)

    const recentSessions = await prisma.simulationSession.findMany({
      where:   { futureDogProfileId: fdProfile.id, completed: true },
      orderBy: { completedAt: 'desc' },
      take:    5,
      select:  { id: true, category: true, title: true, score: true, completedAt: true },
    })

    return { learningProfile, recentSessions }
  })

  // ─── Simulation ───────────────────────────────────────────────────────────

  app.post('/future-dog/simulations/generate', { preHandler: requireAuth }, async (req) => {
    const body = GenerateBody.parse(req.body)

    const fdProfile = await prisma.futureDogProfile.findUnique({
      where: { userId: req.user.userId },
    })
    if (!fdProfile) throw Errors.notFound('Future dog profile')

    return simulation.generateScenario(req.user.userId, fdProfile.id, body.category)
  })

  app.post('/future-dog/simulations/:sessionId/respond', { preHandler: requireAuth }, async (req) => {
    const { sessionId } = req.params as { sessionId: string }
    const body = RespondBody.parse(req.body)

    const fdProfile = await prisma.futureDogProfile.findUnique({
      where: { userId: req.user.userId },
    })
    if (!fdProfile) throw Errors.notFound('Future dog profile')

    const result = await simulation.evaluateResponse(sessionId, req.user.userId, body.userResponse)

    // Update learning profile in background
    learning.updateAfterSimulation(
      req.user.userId,
      fdProfile.id,
      result.score,
      result.learningTags,
      result.whatToImprove,
    ).catch(() => {})

    return result
  })

  app.get('/future-dog/simulations/history', { preHandler: requireAuth }, async (req) => {
    const fdProfile = await prisma.futureDogProfile.findUnique({
      where: { userId: req.user.userId },
    })
    if (!fdProfile) return { sessions: [] }

    const sessions = await prisma.simulationSession.findMany({
      where:   { futureDogProfileId: fdProfile.id },
      orderBy: { createdAt: 'desc' },
      take:    20,
      select:  {
        id: true, category: true, title: true, score: true,
        completed: true, createdAt: true, completedAt: true,
      },
    })
    return { sessions }
  })

  // ─── Transformation ───────────────────────────────────────────────────────

  app.post('/future-dog/transform', { preHandler: requireAuth }, async (req) => {
    const fdProfile = await prisma.futureDogProfile.findUnique({
      where: { userId: req.user.userId },
    })
    if (!fdProfile) throw Errors.notFound('Future dog profile')
    if (fdProfile.transformedAt) return { alreadyTransformed: true }

    // Mark the transformation timestamp (profile is KEPT for AI context)
    await prisma.futureDogProfile.update({
      where: { id: fdProfile.id },
      data:  { transformedAt: new Date() },
    })

    // Build the transition context block for the AI
    const transitionContext = await learning.buildTransitionContext(fdProfile.id)

    return { transformed: true, transitionContext }
  })

  // ─── Avatar ───────────────────────────────────────────────────────────────

  app.patch('/future-dog/profile/avatar', { preHandler: requireAuth }, async (req) => {
    const { avatarUrl } = z.object({ avatarUrl: z.string().url() }).parse(req.body)
    const profile = await prisma.futureDogProfile.update({
      where: { userId: req.user.userId },
      data:  { avatarUrl },
    })
    return profile
  })
}
