import { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { AuthService } from '../services/AuthService'
import { prisma } from '../lib/prisma'

const RegisterBody = z.object({
  email:       z.string().email(),
  password:    z.string().min(8),
  displayName: z.string().optional(),
})

const LoginBody = z.object({
  email:    z.string().email(),
  password: z.string().min(1),
})

const RefreshBody = z.object({ refreshToken: z.string() })
const LogoutBody  = z.object({ refreshToken: z.string() })
const VerifyBody  = z.object({ token: z.string() })

const ForgotBody = z.object({ email: z.string().email() })
const ResetBody  = z.object({ token: z.string(), newPassword: z.string().min(8) })

export async function authRoutes(app: FastifyInstance) {
  const svc = new AuthService(prisma)

  app.post('/auth/register', async (req, reply) => {
    const body = RegisterBody.parse(req.body)
    const result = await svc.register(body.email, body.password, body.displayName, req.ip)
    return reply.code(201).send({
      user:  { id: result.user.id, email: result.user.email, displayName: result.user.displayName },
      accessToken:  result.accessToken,
      refreshToken: result.refreshToken,
    })
  })

  app.post('/auth/login', async (req, reply) => {
    const body   = LoginBody.parse(req.body)
    const result = await svc.login(body.email, body.password, req.ip)
    return reply.send({
      user:  { id: result.user.id, email: result.user.email, displayName: result.user.displayName },
      accessToken:  result.accessToken,
      refreshToken: result.refreshToken,
    })
  })

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

  app.post('/auth/verify-email', async (req, reply) => {
    const { token } = VerifyBody.parse(req.body)
    await svc.verifyEmail(token)
    return reply.send({ verified: true })
  })

  app.post('/auth/forgot-password', async (req, reply) => {
    const { email } = ForgotBody.parse(req.body)
    await svc.sendPasswordReset(email) // token — in prod: send email
    return reply.code(204).send()
  })

  app.post('/auth/reset-password', async (req, reply) => {
    const body = ResetBody.parse(req.body)
    await svc.resetPassword(body.token, body.newPassword)
    return reply.send({ reset: true })
  })
}
