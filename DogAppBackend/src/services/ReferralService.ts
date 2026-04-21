import { PrismaClient } from '@prisma/client'
import crypto from 'crypto'
import { Errors } from '../lib/errors'

export class ReferralService {
  constructor(private db: PrismaClient) {}

  async getMyCode(userId: string) {
    let referral = await this.db.referral.findFirst({ where: { referrerId: userId } })
    if (!referral) {
      referral = await this.db.referral.create({
        data: { referrerId: userId, referralCode: this.generateCode() },
      })
    }

    const rewards = await this.db.referralReward.count({ where: { referral: { referrerId: userId } } })
    const invited = await this.db.referral.count({ where: { referrerId: userId, status: { not: 'pending' } } })

    return {
      referralCode:  referral.referralCode,
      invitedCount:  invited,
      rewardedCount: rewards,
    }
  }

  async applyCode(userId: string, referralCode: string, ipAddress?: string) {
    // Prevent self-referral
    const referral = await this.db.referral.findFirst({ where: { referralCode } })
    if (!referral) throw Errors.notFound('Referral code')
    if (referral.referrerId === userId) throw Errors.validation('Cannot use your own referral code')

    // Check if user already used a code
    const alreadyUsed = await this.db.referral.findFirst({ where: { referredId: userId } })
    if (alreadyUsed) throw Errors.conflict('You have already used a referral code')

    // Anti-abuse: check IP hash
    const ipHash = ipAddress ? crypto.createHash('sha256').update(ipAddress).digest('hex') : undefined

    await this.db.referral.update({
      where: { id: referral.id },
      data:  { referredId: userId, status: 'signed_up', ipAddressHash: ipHash },
    })

    // Grant reward to referrer (7 days premium)
    const sub = await this.db.subscription.findUnique({ where: { userId: referral.referrerId } })
    if (sub) {
      const newExpiry = new Date(Math.max(
        (sub.expiresAt ?? new Date()).getTime(),
        Date.now()
      ))
      newExpiry.setDate(newExpiry.getDate() + 7)

      await this.db.$transaction([
        this.db.subscription.update({
          where: { userId: referral.referrerId },
          data:  { tier: 'premium', expiresAt: newExpiry },
        }),
        this.db.referralReward.create({
          data: { referralId: referral.id, userId: referral.referrerId, rewardType: 'premium_days', rewardValue: 7 },
        }),
        this.db.referral.update({ where: { id: referral.id }, data: { status: 'rewarded', convertedAt: new Date() } }),
      ])
    }

    return { applied: true }
  }

  private generateCode(): string {
    return crypto.randomBytes(4).toString('hex').toUpperCase()
  }
}
