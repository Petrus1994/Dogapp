import { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { requireAuth } from '../middleware/auth'
import { ReferralService } from '../services/ReferralService'
import { prisma } from '../lib/prisma'

const ApplyBody = z.object({ referralCode: z.string().min(1) })

export async function referralRoutes(app: FastifyInstance) {
  const svc = new ReferralService(prisma)

  app.get('/referrals/my-code', { preHandler: requireAuth }, async (req) => {
    return svc.getMyCode(req.user.userId)
  })

  app.post('/referrals/apply', { preHandler: requireAuth }, async (req) => {
    const { referralCode } = ApplyBody.parse(req.body)
    return svc.applyCode(req.user.userId, referralCode, req.ip)
  })
}
