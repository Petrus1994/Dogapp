import bcrypt from 'bcrypt'
import jwt from 'jsonwebtoken'
import crypto from 'crypto'
import { PrismaClient } from '@prisma/client'
import { config } from '../config'
import { Errors } from '../lib/errors'
import { JwtPayload } from '../middleware/auth'
import { todayDate } from '../utils/dates'

export class AuthService {
  constructor(private db: PrismaClient) {}

  async register(email: string, password: string, displayName?: string, ip?: string) {
    const existing = await this.db.user.findUnique({ where: { email } })
    if (existing) throw Errors.conflict('An account with this email already exists')

    const passwordHash = await bcrypt.hash(password, 12)
    const user = await this.db.user.create({
      data: { email, passwordHash, displayName },
    })

    // Bootstrap subscription and progress rows
    await this.db.$transaction([
      this.db.subscription.create({ data: { userId: user.id } }),
      this.db.userProgress.create({ data: { userId: user.id } }),
    ])

    const tokens = this.issueTokens(user.id, user.email)
    await this.persistRefreshToken(user.id, tokens.refreshToken, ip)
    return { user, ...tokens }
  }

  async login(email: string, password: string, ip?: string) {
    const user = await this.db.user.findUnique({ where: { email, deletedAt: null } })
    if (!user) throw Errors.unauthorized()

    const valid = await bcrypt.compare(password, user.passwordHash)
    if (!valid) throw Errors.unauthorized()

    const tokens = this.issueTokens(user.id, user.email)
    await this.persistRefreshToken(user.id, tokens.refreshToken, ip)
    return { user, ...tokens }
  }

  async refresh(refreshToken: string) {
    const session = await this.db.session.findUnique({
      where: { refreshToken },
      include: { user: true },
    })

    if (!session || session.revokedAt || session.expiresAt < new Date()) {
      throw Errors.unauthorized()
    }

    // Rotate refresh token
    await this.db.session.update({ where: { id: session.id }, data: { revokedAt: new Date() } })

    const tokens = this.issueTokens(session.user.id, session.user.email)
    await this.persistRefreshToken(session.user.id, tokens.refreshToken)
    return tokens
  }

  async logout(refreshToken: string) {
    await this.db.session.updateMany({
      where: { refreshToken },
      data:  { revokedAt: new Date() },
    })
  }

  async sendVerificationEmail(userId: string): Promise<string> {
    const token = crypto.randomBytes(32).toString('hex')
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000) // 24h
    await this.db.emailVerificationToken.create({ data: { userId, token, expiresAt } })
    return token // caller sends the email
  }

  async verifyEmail(token: string) {
    const record = await this.db.emailVerificationToken.findUnique({ where: { token } })
    if (!record || record.usedAt || record.expiresAt < new Date()) {
      throw Errors.validation('Invalid or expired verification link')
    }
    await this.db.$transaction([
      this.db.emailVerificationToken.update({ where: { id: record.id }, data: { usedAt: new Date() } }),
      this.db.user.update({ where: { id: record.userId }, data: { emailVerified: true } }),
    ])
  }

  async sendPasswordReset(email: string): Promise<string | null> {
    const user = await this.db.user.findUnique({ where: { email } })
    if (!user) return null // don't leak existence

    const token = crypto.randomBytes(32).toString('hex')
    const expiresAt = new Date(Date.now() + 2 * 60 * 60 * 1000) // 2h
    await this.db.passwordResetToken.create({ data: { userId: user.id, token, expiresAt } })
    return token
  }

  async resetPassword(token: string, newPassword: string) {
    const record = await this.db.passwordResetToken.findUnique({ where: { token } })
    if (!record || record.usedAt || record.expiresAt < new Date()) {
      throw Errors.validation('Invalid or expired reset link')
    }
    const passwordHash = await bcrypt.hash(newPassword, 12)
    await this.db.$transaction([
      this.db.passwordResetToken.update({ where: { id: record.id }, data: { usedAt: new Date() } }),
      this.db.user.update({ where: { id: record.userId }, data: { passwordHash } }),
      // Revoke all sessions on password change
      this.db.session.updateMany({ where: { userId: record.userId }, data: { revokedAt: new Date() } }),
    ])
  }

  private issueTokens(userId: string, email: string) {
    const payload: JwtPayload = { userId, email }
    const accessToken = jwt.sign(payload, config.jwt.secret, { expiresIn: config.jwt.accessTtl as any })
    const refreshToken = jwt.sign(payload, config.jwt.refreshSecret, { expiresIn: `${config.jwt.refreshTtlDays}d` })
    return { accessToken, refreshToken }
  }

  private async persistRefreshToken(userId: string, refreshToken: string, ip?: string) {
    const expiresAt = new Date()
    expiresAt.setDate(expiresAt.getDate() + config.jwt.refreshTtlDays)
    await this.db.session.create({
      data: { userId, refreshToken, expiresAt, ipAddress: ip },
    })
  }
}

