import { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { requireAuth } from '../middleware/auth'
import { AIChatService } from '../services/AIChatService'
import { MemoryPreparationService } from '../services/MemoryPreparationService'
import { prisma } from '../lib/prisma'
import { openai } from '../lib/openai'

const ChatBody = z.object({
  message:        z.string().min(1).max(4000),
  conversationId: z.string().optional(),
  dogId:          z.string().optional(),
})

export async function chatRoutes(app: FastifyInstance) {
  const memory = new MemoryPreparationService(prisma)
  const svc    = new AIChatService(prisma, openai, memory)

  app.post('/dogs/:dogId/chat', { preHandler: requireAuth }, async (req) => {
    const { dogId } = req.params as { dogId: string }
    const body      = ChatBody.parse(req.body)
    return svc.chat(req.user.userId, dogId, body.conversationId ?? null, body.message)
  })

  app.post('/chat', { preHandler: requireAuth }, async (req) => {
    const body = ChatBody.parse(req.body)
    return svc.chat(req.user.userId, body.dogId ?? null, body.conversationId ?? null, body.message)
  })

  app.get('/dogs/:dogId/chat/:conversationId/history', { preHandler: requireAuth }, async (req) => {
    const { dogId, conversationId } = req.params as { dogId: string; conversationId: string }
    return svc.getHistory(req.user.userId, conversationId)
  })
}
