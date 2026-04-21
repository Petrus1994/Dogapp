import { PrismaClient } from '@prisma/client'
import { logger } from '../lib/logger'

export class NotificationService {
  constructor(private db: PrismaClient) {}

  async registerToken(userId: string, token: string, platform: string, deviceName?: string) {
    await this.db.notificationToken.upsert({
      where:  { token },
      create: { userId, token, platform, deviceName, isActive: true },
      update: { userId, isActive: true, lastSeen: new Date() },
    })
  }

  async removeToken(token: string) {
    await this.db.notificationToken.updateMany({
      where: { token },
      data:  { isActive: false },
    })
  }

  async scheduleReminder(userId: string, dogId: string | null, jobType: string, scheduledFor: Date, payload: object) {
    await this.db.notificationJob.create({
      data: { userId, dogId, jobType, scheduledFor, payload },
    })
  }

  async sendToUser(userId: string, title: string, body: string, data?: object) {
    const tokens = await this.db.notificationToken.findMany({
      where: { userId, isActive: true },
    })

    for (const token of tokens) {
      logger.info({ action: 'push_send', userId, token: token.token.slice(0, 8) + '...', title })
      // APNs delivery implemented in PushDeliveryService
    }
  }
}
