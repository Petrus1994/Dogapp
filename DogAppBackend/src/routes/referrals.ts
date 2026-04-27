import { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { requireAuth } from '../middleware/auth'
import { ReferralService } from '../services/ReferralService'
import { prisma } from '../lib/prisma'

const ApplyBody = z.object({ referralCode: z.string().min(1) })

export async function referralRoutes(app: FastifyInstance) {
  const svc = new ReferralService(prisma)

  // Full referral dashboard: code, link, progress, milestones, recent activity
  app.get('/referrals/my-info', { preHandler: requireAuth }, async (req) => {
    return svc.getMyInfo(req.user.userId)
  })

  // Legacy alias
  app.get('/referrals/my-code', { preHandler: requireAuth }, async (req) => {
    return svc.getMyInfo(req.user.userId)
  })

  // Apply a referral code post-registration (reward fires later on payment)
  app.post('/referrals/apply', { preHandler: requireAuth }, async (req) => {
    const { referralCode } = ApplyBody.parse(req.body)
    return svc.applyCode(req.user.userId, referralCode, req.ip)
  })
}
