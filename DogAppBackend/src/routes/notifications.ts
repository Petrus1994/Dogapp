import { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { requireAuth } from '../middleware/auth'
import { NotificationService } from '../services/NotificationService'
import { prisma } from '../lib/prisma'

const RegisterBody = z.object({
  token:      z.string().min(10),
  platform:   z.enum(['ios', 'android']).default('ios'),
  deviceName: z.string().optional(),
})

export async function notificationRoutes(app: FastifyInstance) {
  const svc = new NotificationService(prisma)

  app.post('/notifications/token', { preHandler: requireAuth }, async (req, reply) => {
    const body = RegisterBody.parse(req.body)
    await svc.registerToken(req.user.userId, body.token, body.platform, body.deviceName)
    return reply.code(201).send({ registered: true })
  })

  app.delete('/notifications/token/:token', { preHandler: requireAuth }, async (req, reply) => {
    const { token } = req.params as { token: string }
    await svc.removeToken(token)
    return reply.code(204).send()
  })
}
