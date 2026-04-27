import bcrypt from 'bcrypt'
import jwt from 'jsonwebtoken'
import crypto from 'crypto'
import { PrismaClient } from '@prisma/client'
import { config } from '../config'
import { Errors } from '../lib/errors'
import { JwtPayload } from '../middleware/auth'
import { verifyAppleToken, verifyGoogleToken } from './SocialAuthVerifier'

export class AuthService {
  constructor(private db: PrismaClient) {}

  // ─── Email / password ───────────────────────────────────────────────────────

  async register(
    email:          string,
    password:       string,
    displayName?:   string,
    ip?:            string,
    marketingOptIn: boolean = false,
  ) {
    const existing = await this.db.user.findUnique({ where: { email } })
    if (existing) {
      if (existing.authProvider !== 'email') {
        throw Errors.conflict(
          `This email is linked to Sign in with ${this.providerLabel(existing.authProvider)}. Please use that to log in.`
        )
      }
      throw Errors.conflict('An account with this email already exists')
    }

    const passwordHash = await bcrypt.hash(password, 12)
    const user = await this.db.user.create({
      data: { email, passwordHash, displayName, authProvider: 'email', marketingOptIn },
    })

    await this.bootstrapUser(user.id)

    const tokens = this.issueTokens(user.id, user.email)
    await this.persistRefreshToken(user.id, tokens.refreshToken, ip)
    return { user, ...tokens }
  }

  async login(email: string, password: string, ip?: string) {
    const user = await this.db.user.findUnique({ where: { email, deletedAt: null } })
    if (!user) throw Errors.unauthorized()

    if (user.authProvider !== 'email' || !user.passwordHash) {
      throw Errors.badRequest(
        `This account uses Sign in with ${this.providerLabel(user.authProvider)}. Please use that to log in.`
      )
    }

    const valid = await bcrypt.compare(password, user.passwordHash)
    if (!valid) throw Errors.unauthorized()

    const tokens = this.issueTokens(user.id, user.email)
    await this.persistRefreshToken(user.id, tokens.refreshToken, ip)
    return { user, ...tokens }
  }

  // ─── Apple Sign In ──────────────────────────────────────────────────────────

  async loginWithApple(
    idToken:     string,
    displayName?: string,
    ip?:          string,
  ) {
    const identity = await verifyAppleToken(idToken, config.auth.appleBundleId)

    // Look up by Apple user ID first, then fall back to email
    let user = await this.db.user.findUnique({ where: { appleUserId: identity.sub } })
    if (user?.deletedAt) user = null

    if (!user && identity.email) {
      user = await this.db.user.findUnique({ where: { email: identity.email } })
      if (user?.deletedAt) user = null

      if (user) {
        // Link Apple to existing email account
        user = await this.db.user.update({
          where: { id: user.id },
          data:  { appleUserId: identity.sub, emailVerified: true },
        })
      }
    }

    if (!user) {
      // New user — create account
      const email = identity.email
      if (!email) throw Errors.badRequest('Apple did not provide an email. Please allow email access during Sign in with Apple.')

      user = await this.db.user.create({
        data: {
          email,
          emailVerified: identity.emailVerified,
          authProvider:  'apple',
          appleUserId:   identity.sub,
          displayName,
          marketingOptIn: false,
        },
      })
      await this.bootstrapUser(user.id)
    }

    const tokens = this.issueTokens(user.id, user.email)
    await this.persistRefreshToken(user.id, tokens.refreshToken, ip)
    return { user, ...tokens }
  }

  // ─── Google Sign In ─────────────────────────────────────────────────────────

  async loginWithGoogle(
    idToken: string,
    ip?:     string,
  ) {
    const identity = await verifyGoogleToken(idToken, config.auth.googleIosClientId)

    let user = await this.db.user.findUnique({ where: { googleUserId: identity.sub } })
    if (user?.deletedAt) user = null

    if (!user && identity.email) {
      user = await this.db.user.findUnique({ where: { email: identity.email } })
      if (user?.deletedAt) user = null

      if (user) {
        user = await this.db.user.update({
          where: { id: user.id },
          data:  { googleUserId: identity.sub, emailVerified: identity.emailVerified },
        })
      }
    }

    if (!user) {
      user = await this.db.user.create({
        data: {
          email:         identity.email,
          emailVerified: identity.emailVerified,
          authProvider:  'google',
          googleUserId:  identity.sub,
          marketingOptIn: false,
        },
      })
      await this.bootstrapUser(user.id)
    }

    const tokens = this.issueTokens(user.id, user.email)
    await this.persistRefreshToken(user.id, tokens.refreshToken, ip)
    return { user, ...tokens }
  }

  // ─── Session management ─────────────────────────────────────────────────────

  async refresh(refreshToken: string) {
    const session = await this.db.session.findUnique({
      where:   { refreshToken },
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

  // ─── Email verification ─────────────────────────────────────────────────────

  async sendVerificationEmail(userId: string): Promise<string> {
    const token     = crypto.randomBytes(32).toString('hex')
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

  // ─── Password reset ─────────────────────────────────────────────────────────

  async sendPasswordReset(email: string): Promise<string | null> {
    const user = await this.db.user.findUnique({ where: { email } })
    if (!user) return null // don't leak existence
    if (user.authProvider !== 'email') return null // social accounts have no password

    const token     = crypto.randomBytes(32).toString('hex')
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
      this.db.user.update({ where: { id: record.userId }, data: { passwordHash, authProvider: 'email' } }),
      this.db.session.updateMany({ where: { userId: record.userId }, data: { revokedAt: new Date() } }),
    ])
  }

  // ─── Internals ──────────────────────────────────────────────────────────────

  private async bootstrapUser(userId: string) {
    await this.db.$transaction([
      this.db.subscription.create({ data: { userId } }),
      this.db.userProgress.create({ data: { userId } }),
    ])
  }

  private providerLabel(provider: string): string {
    const labels: Record<string, string> = { apple: 'Apple', google: 'Google', email: 'Email' }
    return labels[provider] ?? provider
  }

  private issueTokens(userId: string, email: string) {
    const payload: JwtPayload = { userId, email }
    const accessToken  = jwt.sign(payload, config.jwt.secret,        { expiresIn: config.jwt.accessTtl as any })
    const refreshToken = jwt.sign(payload, config.jwt.refreshSecret,  { expiresIn: `${config.jwt.refreshTtlDays}d` })
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
