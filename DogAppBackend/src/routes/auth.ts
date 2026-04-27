import { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { AuthService } from '../services/AuthService'
import { ReferralService } from '../services/ReferralService'
import { prisma } from '../lib/prisma'
import { logger } from '../lib/logger'

const RegisterBody = z.object({
  email:          z.string().email(),
  password:       z.string().min(8),
  displayName:    z.string().optional(),
  referralCode:   z.string().optional(),
  marketingOptIn: z.boolean().optional().default(false),
})

const LoginBody = z.object({
  email:    z.string().email(),
  password: z.string().min(1),
})

// Apple sends an identity token (JWT) + optional user info (first sign-in only)
const AppleBody = z.object({
  identityToken: z.string().min(1),
  displayName:   z.string().optional(), // only present on first sign-in from device
})

// Google sends a standard ID token
const GoogleBody = z.object({
  idToken: z.string().min(1),
})

const RefreshBody = z.object({ refreshToken: z.string() })
const LogoutBody  = z.object({ refreshToken: z.string() })
const VerifyBody  = z.object({ token: z.string() })
const ForgotBody  = z.object({ email: z.string().email() })
const ResetBody   = z.object({ token: z.string(), newPassword: z.string().min(8) })

// Consistent shape returned for all auth responses
function userPayload(user: { id: string; email: string; displayName: string | null; marketingOptIn: boolean; authProvider: string }) {
  return {
    id:             user.id,
    email:          user.email,
    displayName:    user.displayName,
    marketingOptIn: user.marketingOptIn,
    authProvider:   user.authProvider,
  }
}

export async function authRoutes(app: FastifyInstance) {
  const svc         = new AuthService(prisma)
  const referralSvc = new ReferralService(prisma)

  // ─── Email / password ───────────────────────────────────────────────────────

  app.post('/auth/register', async (req, reply) => {
    const body   = RegisterBody.parse(req.body)
    const result = await svc.register(body.email, body.password, body.displayName, req.ip, body.marketingOptIn)

    await referralSvc.ensureCode(result.user.id).catch(err =>
      logger.warn({ err }, 'failed to generate referral code on register')
    )

    if (body.referralCode) {
      await referralSvc.applyCode(result.user.id, body.referralCode, req.ip).catch(err =>
        logger.warn({ err, code: body.referralCode }, 'failed to apply referral code on register')
      )
    }

    return reply.code(201).send({
      user:         userPayload(result.user),
      accessToken:  result.accessToken,
      refreshToken: result.refreshToken,
    })
  })

  app.post('/auth/login', async (req, reply) => {
    const body   = LoginBody.parse(req.body)
    const result = await svc.login(body.email, body.password, req.ip)
    return reply.send({
      user:         userPayload(result.user),
      accessToken:  result.accessToken,
      refreshToken: result.refreshToken,
    })
  })

  // ─── Apple Sign In ──────────────────────────────────────────────────────────

  app.post('/auth/apple', async (req, reply) => {
    const body   = AppleBody.parse(req.body)
    const result = await svc.loginWithApple(body.identityToken, body.displayName, req.ip)

    await referralSvc.ensureCode(result.user.id).catch(err =>
      logger.warn({ err }, 'failed to generate referral code for Apple user')
    )

    return reply.send({
      user:         userPayload(result.user),
      accessToken:  result.accessToken,
      refreshToken: result.refreshToken,
    })
  })

  // ─── Google Sign In ─────────────────────────────────────────────────────────

  app.post('/auth/google', async (req, reply) => {
    const body   = GoogleBody.parse(req.body)
    const result = await svc.loginWithGoogle(body.idToken, req.ip)

    await referralSvc.ensureCode(result.user.id).catch(err =>
      logger.warn({ err }, 'failed to generate referral code for Google user')
    )

    return reply.send({
      user:         userPayload(result.user),
      accessToken:  result.accessToken,
      refreshToken: result.refreshToken,
    })
  })

  // ─── Session management ─────────────────────────────────────────────────────

  app.post('/auth/refresh', async (req, reply) => {
    const { refreshToken } = RefreshBody.parse(req.body)
    const tokens = await svc.refresh(refreshToken)
    return reply.send(tokens)
  })

  app.post('/auth/logout', async (req, reply) => {
    const { refreshToken } = LogoutBody.parse(req.body)
    await svc.logout(refreshToken)
    return reply.code(204).send()
  })

  // ─── Email verification ─────────────────────────────────────────────────────

  app.post('/auth/verify-email', async (req, reply) => {
    const { token } = VerifyBody.parse(req.body)
    await svc.verifyEmail(token)
    return reply.send({ verified: true })
  })

  // ─── Password reset ─────────────────────────────────────────────────────────

  app.post('/auth/forgot-password', async (req, reply) => {
    const { email } = ForgotBody.parse(req.body)
    await svc.sendPasswordReset(email)
    return reply.code(204).send()
  })

  app.post('/auth/reset-password', async (req, reply) => {
    const body = ResetBody.parse(req.body)
    await svc.resetPassword(body.token, body.newPassword)
    return reply.send({ reset: true })
  })
}
