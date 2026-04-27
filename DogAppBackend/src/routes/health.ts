import { FastifyInstance } from 'fastify'
import { config } from '../config'
import { AvatarStorageService } from '../lib/storage'

// Standalone health check — no DB dependency, always responds
export async function healthRoutes(app: FastifyInstance) {
  app.get('/health', async (_req, reply) => {
    return reply.code(200).send({ status: 'ok', timestamp: new Date().toISOString() })
  })

  // Temporary storage diagnostic — exposes non-secret config + a sample public URL
  // Remove after verifying storage is wired correctly
  app.get('/health/storage', async (_req, reply) => {
    const sampleKey = 'avatars/test-sample.png'
    const samplePublicUrl = AvatarStorageService.publicUrl(sampleKey)
    return reply.send({
      bucket:        config.storage.bucket,
      endpoint:      config.storage.endpoint ?? '(not set)',
      publicBaseUrl: config.storage.publicBaseUrl ?? '(not set)',
      region:        config.storage.region,
      sampleKey,
      samplePublicUrl,
      accessKeyConfigured: config.storage.accessKey !== 'not-configured',
      secretKeyConfigured: config.storage.secretKey !== 'not-configured',
    })
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
