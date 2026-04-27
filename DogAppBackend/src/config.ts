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

  // Social auth
  // Apple: must match the iOS app Bundle ID (e.g. "com.yourcompany.pawcoach")
  APPLE_BUNDLE_ID:        z.string().default('com.example.pawcoach'),
  // Google: iOS OAuth 2.0 Client ID from Google Cloud Console
  // (the one ending in .apps.googleusercontent.com registered for the iOS platform)
  GOOGLE_IOS_CLIENT_ID:   z.string().default('not-configured'),
  // TODO: Set REFERRAL_APP_LINK_BASE once the App Store listing and landing page are live.
  //       Until then, leave this unset — the API returns only the code, not a shareable link.
  //       Do NOT set a placeholder domain — it would create broken links in user share sheets.
  REFERRAL_APP_LINK_BASE:   z.string().optional(),
  APNS_KEY_ID:              z.string().optional(),
  APNS_TEAM_ID:             z.string().optional(),
  APNS_BUNDLE_ID:           z.string().optional(),
  APNS_KEY_PATH:            z.string().optional(),
  APNS_PRODUCTION:          z.string().default('false'),

  // Avatar generation
  GEMINI_API_KEY:                       z.string().default('not-configured'),
  GEMINI_VISION_MODEL:                  z.string().default('gemini-1.5-pro'),
  GEMINI_IMAGE_MODEL:                   z.string().default('gemini-2.0-flash-preview-image-generation'),
  OPENAI_IMAGE_MODEL:                   z.string().default('dall-e-3'),
  AVATAR_MAX_REGENERATIONS:             z.string().default('2'),
  AVATAR_GENERATION_PROVIDER_PRIORITY:  z.string().default('gemini,openai'),

  // Object storage (S3-compatible: AWS S3, Cloudflare R2, MinIO, etc.)
  STORAGE_PROVIDER:          z.string().default('s3'),
  STORAGE_BUCKET:            z.string().default('pawcoach-avatars'),
  STORAGE_ENDPOINT:          z.string().optional(),
  STORAGE_REGION:            z.string().default('auto'),
  STORAGE_ACCESS_KEY:        z.string().default('not-configured'),
  STORAGE_SECRET_KEY:        z.string().default('not-configured'),
  STORAGE_PUBLIC_BASE_URL:   z.string().optional(),
})

// Never exit — just warn and continue with defaults
const parsed = envSchema.safeParse(process.env)
const data   = parsed.success ? parsed.data : envSchema.parse({}) // use all defaults

if (!parsed.success) {
  console.warn('[CONFIG] Some env vars missing, using defaults:', parsed.error.flatten().fieldErrors)
}

export const config = {
  db:    { url: data.DATABASE_URL },
  auth: {
    appleBundleId:    data.APPLE_BUNDLE_ID,
    googleIosClientId: data.GOOGLE_IOS_CLIENT_ID,
  },
  jwt:   {
    secret:         data.JWT_SECRET,
    refreshSecret:  data.JWT_REFRESH_SECRET,
    accessTtl:      '15m',
    refreshTtlDays: 30,
  },
  openai: {
    apiKey:     data.OPENAI_API_KEY,
    imageModel: data.OPENAI_IMAGE_MODEL,
  },
  gemini: {
    apiKey:      data.GEMINI_API_KEY,
    visionModel: data.GEMINI_VISION_MODEL,
    imageModel:  data.GEMINI_IMAGE_MODEL,
  },
  avatar: {
    maxRegenerations:        parseInt(data.AVATAR_MAX_REGENERATIONS, 10),
    providerPriority:        data.AVATAR_GENERATION_PROVIDER_PRIORITY.split(',').map(s => s.trim()),
  },
  storage: {
    provider:       data.STORAGE_PROVIDER,
    bucket:         data.STORAGE_BUCKET,
    endpoint:       data.STORAGE_ENDPOINT,
    region:         data.STORAGE_REGION,
    accessKey:      data.STORAGE_ACCESS_KEY,
    secretKey:      data.STORAGE_SECRET_KEY,
    publicBaseUrl:  data.STORAGE_PUBLIC_BASE_URL,
  },
  referral: {
    // undefined when env var is not set — consumers must guard before building a URL
    appLinkBase: data.REFERRAL_APP_LINK_BASE as string | undefined,
  },
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
