import { PrismaClient } from '@prisma/client'
import crypto from 'crypto'
import { Errors } from '../lib/errors'
import { config } from '../config'

// Days granted INCREMENTALLY when the successful-referral count hits each key.
// Non-milestone counts (4, 5, 7–11, 13+) earn nothing extra.
//   1 → total  7 days
//   2 → total 14 days (+7)
//   3 → total 30 days (+16)
//   6 → total 90 days (+60)
//  12 → total 180 days (+90)
const REWARD_MILESTONES: Record<number, number> = {
  1:  7,
  2:  7,
  3:  16,
  6:  60,
  12: 90,
}

export class ReferralService {
  constructor(private db: PrismaClient) {}

  // ─── Public API ──────────────────────────────────────────────────────────────

  async getMyInfo(userId: string) {
    const user = await this.db.user.findUniqueOrThrow({ where: { id: userId } })
    const code = user.referralCode ?? (await this.ensureCode(userId))

    const referrals = await this.db.referral.findMany({
      where:   { referrerId: userId },
      orderBy: { createdAt: 'desc' },
    })

    const successfulCount = referrals.filter(r =>
      r.status === 'subscribed' || r.status === 'rewarded'
    ).length
    const pendingCount = referrals.filter(r => r.status === 'registered').length

    const totalRewardAgg = await this.db.referralReward.aggregate({
      where: { userId },
      _sum:  { rewardValue: true },
    })

    // TODO: referralLink is null until REFERRAL_APP_LINK_BASE is set in env.
    //       Configure it once the App Store listing and landing page (pawcoach.app/invite) are live.
    //       iOS clients must treat null as "show code only, no share link".
    const referralLink = config.referral.appLinkBase
      ? `${config.referral.appLinkBase}?code=${code}`
      : null

    return {
      referralCode:          code,
      referralLink,
      totalReferrals:        referrals.length,
      successfulReferrals:   successfulCount,
      pendingReferrals:      pendingCount,
      totalRewardDaysEarned: totalRewardAgg._sum.rewardValue ?? 0,
      nextMilestone:         this.nextMilestone(successfulCount),
      milestones:            this.allMilestonesWithStatus(successfulCount),
      recentActivity:        referrals.slice(0, 10).map(r => ({
        id:          r.id,
        status:      r.status,
        createdAt:   r.createdAt,
        subscribedAt: r.subscribedAt,
      })),
    }
  }

  // Called at registration or post-registration. Just links the accounts;
  // NO reward is granted here — reward only comes after first payment.
  async applyCode(userId: string, code: string, ipAddress?: string) {
    const inviter = await this.db.user.findFirst({
      where: { referralCode: code },
    })
    if (!inviter) throw Errors.notFound('Referral code')
    if (inviter.id === userId) throw Errors.validation('You cannot use your own referral code')

    const alreadyReferred = await this.db.referral.findFirst({
      where: { referredId: userId },
    })
    if (alreadyReferred) throw Errors.conflict('You have already used a referral code')

    const ipHash = ipAddress
      ? crypto.createHash('sha256').update(ipAddress).digest('hex')
      : undefined

    // Anti-abuse: block if this IP already referred someone for this inviter
    if (ipHash) {
      const ipConflict = await this.db.referral.findFirst({
        where: { referrerId: inviter.id, ipAddressHash: ipHash },
      })
      if (ipConflict) {
        throw Errors.validation('This invite cannot be applied from this network')
      }
    }

    await this.db.referral.create({
      data: {
        referrerId:    inviter.id,
        referredId:    userId,
        status:        'registered',
        ipAddressHash: ipHash,
      },
    })

    return { applied: true }
  }

  // Called by SubscriptionService immediately after a successful payment is confirmed.
  async onPaymentCompleted(userId: string): Promise<void> {
    const referral = await this.db.referral.findFirst({
      where: { referredId: userId, status: 'registered' },
    })
    if (!referral) return

    await this.db.referral.update({
      where: { id: referral.id },
      data:  { status: 'subscribed', subscribedAt: new Date() },
    })

    // Count total successful referrals for this inviter (including the one just subscribed)
    const successCount = await this.db.referral.count({
      where: {
        referrerId: referral.referrerId,
        status:     { in: ['subscribed', 'rewarded'] },
      },
    })

    const rewardDays = REWARD_MILESTONES[successCount]
    if (rewardDays) {
      await this.grantReward(referral.referrerId, referral.id, rewardDays, successCount)
    }
  }

  // ─── Internal helpers ─────────────────────────────────────────────────────

  private async grantReward(
    referrerId: string,
    referralId: string,
    days: number,
    milestone: number,
  ): Promise<void> {
    const sub = await this.db.subscription.findUnique({ where: { userId: referrerId } })
    if (!sub) return

    const base     = sub.expiresAt && sub.expiresAt > new Date() ? sub.expiresAt : new Date()
    const newExpiry = new Date(base.getTime() + days * 24 * 60 * 60 * 1000)

    await this.db.$transaction([
      this.db.subscription.update({
        where: { userId: referrerId },
        data:  { tier: 'premium', expiresAt: newExpiry },
      }),
      this.db.referralReward.create({
        data: {
          referralId,
          userId:      referrerId,
          rewardType:  `milestone_${milestone}`,
          rewardValue: days,
        },
      }),
      this.db.referral.update({
        where: { id: referralId },
        data:  { rewardGranted: true, status: 'rewarded' },
      }),
    ])
  }

  async ensureCode(userId: string): Promise<string> {
    // Try up to 5 times in case of collision (SHA256-derived 8-char codes = ~4B combos)
    for (let i = 0; i < 5; i++) {
      const code = this.generateCode()
      const existing = await this.db.user.findUnique({ where: { referralCode: code } })
      if (!existing) {
        await this.db.user.update({ where: { id: userId }, data: { referralCode: code } })
        return code
      }
    }
    throw Errors.internal('Could not generate unique referral code')
  }

  private generateCode(): string {
    // 8 uppercase hex chars — human-readable, shareable
    return crypto.randomBytes(4).toString('hex').toUpperCase()
  }

  private nextMilestone(successCount: number) {
    const keys = Object.keys(REWARD_MILESTONES).map(Number).sort((a, b) => a - b)
    const next = keys.find(k => k > successCount)
    if (!next) return null
    return {
      targetCount:   next,
      rewardDays:    REWARD_MILESTONES[next],
      progressCount: successCount,
      remaining:     next - successCount,
    }
  }

  private allMilestonesWithStatus(successCount: number) {
    return Object.entries(REWARD_MILESTONES)
      .map(([count, days]) => ({
        targetCount: Number(count),
        rewardDays:  days,
        achieved:    successCount >= Number(count),
      }))
      .sort((a, b) => a.targetCount - b.targetCount)
  }
}
