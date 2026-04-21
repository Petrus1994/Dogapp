import { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { requireAuth } from '../middleware/auth'
import { SubscriptionService } from '../services/SubscriptionService'
import { prisma } from '../lib/prisma'

const ReceiptBody = z.object({
  receiptData: z.string(),
  platform:    z.enum(['ios', 'android']),
  productId:   z.string(),
})

export async function subscriptionRoutes(app: FastifyInstance) {
  const svc = new SubscriptionService(prisma)

  app.get('/subscription', { preHandler: requireAuth }, async (req) => {
    return svc.getStatus(req.user.userId)
  })

  app.post('/subscription/verify-receipt', { preHandler: requireAuth }, async (req) => {
    const body = ReceiptBody.parse(req.body)
    return svc.applyAppleReceipt(req.user.userId, body.receiptData, body.productId)
  })
}
