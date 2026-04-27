import crypto from 'crypto'
import jwt from 'jsonwebtoken'
import { logger } from '../lib/logger'

// ─── Types ────────────────────────────────────────────────────────────────────

export interface SocialIdentity {
  sub:           string   // provider's user ID
  email:         string
  emailVerified: boolean
}

// ─── JWKS cache ───────────────────────────────────────────────────────────────

interface CachedJwks {
  keys:      any[]
  fetchedAt: number
}

const jwksCache = new Map<string, CachedJwks>()
const JWKS_TTL_MS = 60 * 60 * 1000 // 1 hour

async function fetchJwks(url: string): Promise<any[]> {
  const cached = jwksCache.get(url)
  if (cached && Date.now() - cached.fetchedAt < JWKS_TTL_MS) {
    return cached.keys
  }

  const res = await fetch(url, { signal: AbortSignal.timeout(5000) })
  if (!res.ok) throw new Error(`JWKS fetch failed: ${res.status}`)
  const data = await res.json() as { keys: any[] }
  jwksCache.set(url, { keys: data.keys, fetchedAt: Date.now() })
  return data.keys
}

// ─── JWK → PEM ────────────────────────────────────────────────────────────────
// Uses Node.js built-in crypto (v15+). No external package needed.

function jwkToPem(jwk: object): string {
  const key = crypto.createPublicKey({ key: jwk as crypto.JsonWebKey, format: 'jwk' })
  return key.export({ type: 'spki', format: 'pem' }) as string
}

// ─── Generic JWKS-based JWT verification ─────────────────────────────────────

async function verifyJwksJwt(
  token:    string,
  jwksUrl:  string,
  options:  { issuer: string | [string, ...string[]]; audience: string },
): Promise<jwt.JwtPayload> {
  // Decode header to find the right key
  const decoded = jwt.decode(token, { complete: true })
  if (!decoded || typeof decoded === 'string') {
    throw new Error('Malformed identity token')
  }

  const kid = decoded.header.kid
  let keys  = await fetchJwks(jwksUrl)
  let key   = keys.find(k => k.kid === kid)

  // Retry once with fresh keys in case the set rotated
  if (!key) {
    jwksCache.delete(jwksUrl)
    keys  = await fetchJwks(jwksUrl)
    key   = keys.find(k => k.kid === kid)
  }

  if (!key) throw new Error(`No matching JWKS key for kid=${kid}`)

  const pem    = jwkToPem(key)
  const payload = jwt.verify(token, pem, {
    algorithms: ['RS256'],
    issuer:     options.issuer,
    audience:   options.audience,
  }) as jwt.JwtPayload

  return payload
}

// ─── Apple Sign In ────────────────────────────────────────────────────────────
// Apple identity token docs: https://developer.apple.com/documentation/sign_in_with_apple/sign_in_with_apple_rest_api/authenticating_users_with_sign_in_with_apple

const APPLE_JWKS_URL = 'https://appleid.apple.com/auth/keys'
const APPLE_ISSUER   = 'https://appleid.apple.com'

export async function verifyAppleToken(
  idToken:  string,
  bundleId: string,          // must match `aud` claim — your iOS bundle ID
): Promise<SocialIdentity> {
  try {
    const payload = await verifyJwksJwt(idToken, APPLE_JWKS_URL, {
      issuer:   APPLE_ISSUER,
      audience: bundleId,
    })

    const sub   = payload.sub
    const email = payload.email

    if (!sub)   throw new Error('Apple token missing sub')
    if (!email) throw new Error('Apple token missing email')

    return {
      sub,
      email:         email as string,
      emailVerified: payload.email_verified === true || payload.email_verified === 'true',
    }
  } catch (err) {
    logger.warn({ err }, 'Apple token verification failed')
    throw new Error('Invalid Apple identity token')
  }
}

// ─── Google Sign In ───────────────────────────────────────────────────────────
// Google ID token docs: https://developers.google.com/identity/gsi/web/guides/verify-google-id-token

const GOOGLE_JWKS_URL = 'https://www.googleapis.com/oauth2/v3/certs'
const GOOGLE_ISSUERS: [string, ...string[]] = ['accounts.google.com', 'https://accounts.google.com']

export async function verifyGoogleToken(
  idToken:  string,
  clientId: string,          // iOS OAuth client ID from Google Cloud Console
): Promise<SocialIdentity> {
  try {
    const payload = await verifyJwksJwt(idToken, GOOGLE_JWKS_URL, {
      issuer:   GOOGLE_ISSUERS,
      audience: clientId,
    })

    const sub   = payload.sub
    const email = payload.email

    if (!sub)   throw new Error('Google token missing sub')
    if (!email) throw new Error('Google token missing email')

    return {
      sub,
      email:         email as string,
      emailVerified: payload.email_verified === true,
    }
  } catch (err) {
    logger.warn({ err }, 'Google token verification failed')
    throw new Error('Invalid Google identity token')
  }
}
