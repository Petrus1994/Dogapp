import Fastify, { FastifyInstance } from 'fastify'
import cors    from '@fastify/cors'
import helmet  from '@fastify/helmet'
import { Server, IncomingMessage, ServerResponse } from 'http'
import { AppError } from './lib/errors'

import { authRoutes }         from './routes/auth'
import { dogRoutes }          from './routes/dogs'
import { logRoutes }          from './routes/logs'
import { chatRoutes }         from './routes/chat'
import { planRoutes }         from './routes/plans'
import { progressRoutes }     from './routes/progress'
import { subscriptionRoutes } from './routes/subscriptions'
import { referralRoutes }     from './routes/referrals'
import { notificationRoutes } from './routes/notifications'
import { activityRoutes }     from './routes/activity'
// Note: health routes are handled directly by the raw http server in server.ts

export async function buildApp(existingServer?: Server): Promise<FastifyInstance> {
  const app = Fastify({
    logger: false,
    // If caller passes an existing http.Server, reuse it (don't create a new one)
    serverFactory: existingServer
      ? (handler: (req: IncomingMessage, res: ServerResponse) => void) => {
          // We do NOT add handler here — server.ts sets fastifyHandler = app.routing
          // This just returns our existing server so Fastify knows about it
          return existingServer
        }
      : undefined,
  })

  // Security headers
  await app.register(helmet, { global: true })

  // CORS
  await app.register(cors, {
    origin:      process.env.NODE_ENV === 'production' ? ['https://pawcoach.app'] : true,
    credentials: true,
  })

  // Global error handler
  app.setErrorHandler((err, _req, reply) => {
    if (err instanceof AppError) {
      return reply.code(err.statusCode).send({ error: err.code, message: err.message })
    }
    if (err.name === 'ZodError') {
      return reply.code(422).send({ error: 'VALIDATION_ERROR', message: 'Invalid request data', details: (err as any).errors })
    }
    console.error('[ERROR]', err)
    return reply.code(500).send({ error: 'INTERNAL', message: 'An unexpected error occurred' })
  })

  // Routes — all under /v1
  await app.register(authRoutes,         { prefix: '/v1' })
  await app.register(dogRoutes,          { prefix: '/v1' })
  await app.register(logRoutes,          { prefix: '/v1' })
  await app.register(chatRoutes,         { prefix: '/v1' })
  await app.register(planRoutes,         { prefix: '/v1' })
  await app.register(progressRoutes,     { prefix: '/v1' })
  await app.register(subscriptionRoutes, { prefix: '/v1' })
  await app.register(referralRoutes,     { prefix: '/v1' })
  await app.register(notificationRoutes, { prefix: '/v1' })
  await app.register(activityRoutes,     { prefix: '/v1' })

  return app
}
