import { FastifyRequest, FastifyReply } from 'fastify'
import jwt from 'jsonwebtoken'
import { config } from '../config'
import { Errors } from '../lib/errors'

export interface JwtPayload {
  userId: string
  email:  string
}

declare module 'fastify' {
  interface FastifyRequest {
    user: JwtPayload
  }
}

export async function requireAuth(req: FastifyRequest, reply: FastifyReply): Promise<void> {
  const header = req.headers.authorization
  if (!header?.startsWith('Bearer ')) {
    throw Errors.unauthorized()
  }

  const token = header.slice(7)
  try {
    const payload = jwt.verify(token, config.jwt.secret) as JwtPayload
    req.user = payload
  } catch {
    throw Errors.unauthorized()
  }
}
