// server.ts — minimal static imports, port binds before anything else
import 'dotenv/config'
import { createServer, IncomingMessage, ServerResponse } from 'http'

// ── Global safety net (catches any crash in dynamic code below) ───────────────
process.on('uncaughtException',  (err) => console.error('[CRASH] Uncaught:', err))
process.on('unhandledRejection', (err) => console.error('[CRASH] Rejection:', err))

const PORT = parseInt(process.env.PORT || '3000', 10)

// ── Diagnostic boot log (visible in Railway logs) ─────────────────────────────
console.log('[BOOT] PawCoach API starting')
console.log('[BOOT] PORT:', PORT)
console.log('[BOOT] NODE_ENV:', process.env.NODE_ENV)
console.log('[BOOT] DATABASE_URL set:', !!process.env.DATABASE_URL)
console.log('[BOOT] JWT_SECRET set:', !!process.env.JWT_SECRET)
console.log('[BOOT] JWT_REFRESH_SECRET set:', !!process.env.JWT_REFRESH_SECRET)
console.log('[BOOT] OPENAI_API_KEY set:', !!process.env.OPENAI_API_KEY)

// ── Fastify request handler — set once Fastify is ready ───────────────────────
type Handler = (req: IncomingMessage, res: ServerResponse) => void
let fastifyHandler: Handler | null = null

// ── Raw HTTP server — binds port immediately, no dependencies ─────────────────
const rawServer = createServer((req, res) => {
  const url = req.url ?? '/'

  // /health always responds, regardless of Fastify state
  if (url === '/health' || url === '/health/') {
    res.writeHead(200, { 'Content-Type': 'application/json' })
    res.end(JSON.stringify({ status: 'ok', timestamp: new Date().toISOString() }))
    return
  }

  // /health/storage — non-secret storage config diagnostic (temporary)
  if (url === '/health/storage') {
    const bucket        = process.env.STORAGE_BUCKET        ?? '(not set)'
    const endpoint      = process.env.STORAGE_ENDPOINT      ?? '(not set)'
    const publicBaseUrl = process.env.STORAGE_PUBLIC_BASE_URL ?? '(not set)'
    const region        = process.env.STORAGE_REGION        ?? 'auto'
    const sampleKey     = 'avatars/test-sample.png'
    const samplePublicUrl = publicBaseUrl !== '(not set)'
      ? `${publicBaseUrl.replace(/\/$/, '')}/${sampleKey}`
      : endpoint !== '(not set)'
        ? `${endpoint.replace(/\/$/, '')}/${bucket}/${sampleKey}`
        : `https://${bucket}.s3.${region}.amazonaws.com/${sampleKey}`
    res.writeHead(200, { 'Content-Type': 'application/json' })
    res.end(JSON.stringify({
      bucket,
      endpoint,
      publicBaseUrl,
      region,
      sampleKey,
      samplePublicUrl,
      accessKeyConfigured: (process.env.STORAGE_ACCESS_KEY ?? 'not-configured') !== 'not-configured',
      secretKeyConfigured: (process.env.STORAGE_SECRET_KEY ?? 'not-configured') !== 'not-configured',
    }))
    return
  }

  // Forward to Fastify once loaded, otherwise 503
  if (fastifyHandler) {
    fastifyHandler(req, res)
  } else {
    res.writeHead(503, { 'Content-Type': 'application/json' })
    res.end(JSON.stringify({ status: 'starting', message: 'API initializing — try again in a moment' }))
  }
})

rawServer.listen(PORT, '0.0.0.0', () => {
  console.log('[OK] Port', PORT, 'bound — /health is live')
  // Load full app after port is bound (failure here never crashes the health check)
  loadApp()
})

// ── Async app loader — all complex imports happen here ────────────────────────
async function loadApp() {
  try {
    console.log('[INIT] Loading Fastify app...')

    // Dynamic import so module-level errors in app/* don't crash the http server
    const { buildApp } = await import('./app')

    // Pass our raw server so Fastify reuses it instead of creating a new one
    const app = await buildApp(rawServer)
    await app.ready()

    // Fastify is now ready — hand all non-health requests to it
    fastifyHandler = app.routing.bind(app)
    console.log('[OK] Fastify ready — full API serving')

    // Push DB schema (non-fatal, async)
    pushSchema()

    // Start background jobs (non-fatal, async)
    startJobs(app)

  } catch (err: any) {
    console.error('[FAIL] Fastify load error:', err?.message ?? err)
    console.error(err?.stack ?? '')
    // rawServer keeps running — /health still responds
  }
}

async function pushSchema() {
  try {
    const { execSync } = await import('child_process')
    console.log('[DB] Pushing schema...')
    execSync('npx prisma db push --accept-data-loss', { stdio: 'inherit', timeout: 30_000 })
    console.log('[DB] Schema up to date')
  } catch (err: any) {
    console.error('[DB] Schema push failed (non-fatal):', err?.message ?? err)
  }
}

async function startJobs(app: any) {
  try {
    const { boss }         = await import('./lib/jobs')
    const { prisma }       = await import('./lib/prisma')
    const { openai }       = await import('./lib/openai')
    const { registerJobs } = await import('./jobs/registry')
    await boss.start()
    await registerJobs(boss, prisma, openai)
    console.log('[OK] Background jobs started')
  } catch (err: any) {
    console.error('[JOBS] Job queue failed (non-fatal):', err?.message ?? err)
  }
}

// ── Graceful shutdown ─────────────────────────────────────────────────────────
async function shutdown() {
  console.log('[SHUTDOWN] Graceful shutdown...')
  rawServer.close()
  try {
    const { boss }   = await import('./lib/jobs')
    const { prisma } = await import('./lib/prisma')
    await boss.stop()
    await prisma.$disconnect()
  } catch {}
  process.exit(0)
}

process.on('SIGTERM', shutdown)
process.on('SIGINT',  shutdown)
