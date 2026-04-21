// config.ts — never calls process.exit() so /health always starts
import { z } from 'zod'

const envSchema = z.object({
  DATABASE_URL:             z.string().min(1).default('not-set'),
  JWT_SECRET:               z.string().min(8).default('dev-secret-change-in-production'),
  JWT_REFRESH_SECRET:       z.string().min(8).default('dev-refresh-secret-change-in-production'),
  OPENAI_API_KEY:           z.string().min(1).default('not-configured'),
  PORT:                     z.string().default('3000'),
  NODE_ENV:                 z.string().default('production'),
  LOG_LEVEL:                z.string().default('info'),
  FREE_AI_REQUESTS_PER_DAY: z.string().default('10'),
  APNS_KEY_ID:              z.string().optional(),
  APNS_TEAM_ID:             z.string().optional(),
  APNS_BUNDLE_ID:           z.string().optional(),
  APNS_KEY_PATH:            z.string().optional(),
  APNS_PRODUCTION:          z.string().default('false'),
})

// Never exit — just warn and continue with defaults
const parsed = envSchema.safeParse(process.env)
const data   = parsed.success ? parsed.data : envSchema.parse({}) // use all defaults

if (!parsed.success) {
  console.warn('[CONFIG] Some env vars missing, using defaults:', parsed.error.flatten().fieldErrors)
}

export const config = {
  db:    { url: data.DATABASE_URL },
  jwt:   {
    secret:         data.JWT_SECRET,
    refreshSecret:  data.JWT_REFRESH_SECRET,
    accessTtl:      '15m',
    refreshTtlDays: 30,
  },
  openai: { apiKey: data.OPENAI_API_KEY },
  server: {
    port:     parseInt(data.PORT, 10),
    nodeEnv:  data.NODE_ENV,
    logLevel: data.LOG_LEVEL as any,
  },
  limits: {
    freeAiRequestsPerDay: parseInt(data.FREE_AI_REQUESTS_PER_DAY, 10),
  },
  apns: {
    keyId:      data.APNS_KEY_ID,
    teamId:     data.APNS_TEAM_ID,
    bundleId:   data.APNS_BUNDLE_ID,
    keyPath:    data.APNS_KEY_PATH,
    production: data.APNS_PRODUCTION === 'true',
  },
}
