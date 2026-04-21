import { PrismaClient } from '@prisma/client'
import { Errors } from '../lib/errors'
import { logger } from '../lib/logger'
import { todayDate } from '../utils/dates'

export class SubscriptionService {
  constructor(private db: PrismaClient) {}

  async getStatus(userId: string) {
    let sub = await this.db.subscription.findUnique({ where: { userId } })
    if (!sub) {
      sub = await this.db.subscription.create({ data: { userId } })
    }

    // Check expiry
    if (sub.tier === 'premium' && sub.expiresAt && sub.expiresAt < new Date()) {
      sub = await this.db.subscription.update({
        where: { id: sub.id },
        data:  { tier: 'free' },
      })
    }

    const today = todayDate()
    const usage = await this.db.aiUsage.findUnique({
      where: { userId_usageDate: { userId, usageDate: today } },
    })

    return {
      tier:              sub.tier,
      expiresAt:         sub.expiresAt,
      aiRequestsToday:   usage?.requestCount ?? 0,
      aiDailyLimit:      sub.tier === 'premium' ? null : 10, // null = unlimited
    }
  }

  async applyAppleReceipt(userId: string, receiptData: string, productId: string) {
    // In production: validate receipt with Apple's /verifyReceipt endpoint
    // For MVP: trust the client but log for audit
    logger.info({ action: 'receipt_verify', userId, productId })

    const expiresAt = new Date()
    expiresAt.setMonth(expiresAt.getMonth() + 1) // assume monthly

    const [sub] = await this.db.$transaction([
      this.db.subscription.upsert({
        where:  { userId },
        create: { userId, tier: 'premium', platform: 'ios', storeProductId: productId, expiresAt },
        update: { tier: 'premium', storeProductId: productId, expiresAt },
      }),
      this.db.subscriptionEvent.create({
        data: { userId, eventType: 'purchased', tierBefore: 'free', tierAfter: 'premium' },
      }),
    ])

    return sub
  }

  async handleExpiry(userId: string) {
    await this.db.subscription.update({
      where: { userId },
      data:  { tier: 'free', cancelledAt: new Date() },
    })
    await this.db.subscriptionEvent.create({
      data: { userId, eventType: 'expired', tierBefore: 'premium', tierAfter: 'free' },
    })
  }
}
