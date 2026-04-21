import { FastifyInstance } from 'fastify'

// Standalone health check — no DB dependency, always responds
export async function healthRoutes(app: FastifyInstance) {
  app.get('/health', async (_req, reply) => {
    return reply.code(200).send({ status: 'ok', timestamp: new Date().toISOString() })
  })

  app.get('/health/detailed', async (_req, reply) => {
    let dbOk = false
    let dbLatencyMs = -1
    try {
      const { PrismaClient } = await import('@prisma/client')
      const db    = new PrismaClient()
      const start = Date.now()
      await db.$queryRaw`SELECT 1`
      dbLatencyMs = Date.now() - start
      dbOk        = true
      await db.$disconnect()
    } catch {}

    return reply.code(dbOk ? 200 : 503).send({
      status:      dbOk ? 'ok' : 'degraded',
      db:          dbOk ? 'ok' : 'error',
      dbLatencyMs,
      timestamp:   new Date().toISOString(),
    })
  })
}
