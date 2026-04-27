import {
  S3Client,
  PutObjectCommand,
  DeleteObjectCommand,
  GetObjectCommand,
} from '@aws-sdk/client-s3'
import { getSignedUrl } from '@aws-sdk/s3-request-presigner'
import { config } from '../config'
import { randomUUID } from 'crypto'

const s3 = new S3Client({
  region:   config.storage.region,
  endpoint: config.storage.endpoint,
  credentials: {
    accessKeyId:     config.storage.accessKey,
    secretAccessKey: config.storage.secretKey,
  },
  forcePathStyle: !!config.storage.endpoint, // required for Cloudflare R2 / MinIO
})

export type StorageFolder = 'reference-photos' | 'avatars' | 'thumbnails'

export const AvatarStorageService = {

  async uploadBuffer(
    buffer: Buffer,
    folder: StorageFolder,
    ext: string = 'jpg',
    contentType: string = 'image/jpeg',
  ): Promise<string> {
    const key = `${folder}/${randomUUID()}.${ext}`
    await s3.send(new PutObjectCommand({
      Bucket:      config.storage.bucket,
      Key:         key,
      Body:        buffer,
      ContentType: contentType,
    }))
    return publicUrl(key)
  },

  async uploadBase64(
    base64Data: string,
    folder: StorageFolder,
    ext: string = 'png',
    contentType: string = 'image/png',
  ): Promise<string> {
    const buffer = Buffer.from(base64Data, 'base64')
    return AvatarStorageService.uploadBuffer(buffer, folder, ext, contentType)
  },

  async delete(urlOrKey: string): Promise<void> {
    const key = extractKey(urlOrKey)
    if (!key) return
    await s3.send(new DeleteObjectCommand({
      Bucket: config.storage.bucket,
      Key:    key,
    }))
  },

  async signedUrl(urlOrKey: string, expiresInSeconds = 3600): Promise<string> {
    const key = extractKey(urlOrKey)
    if (!key) return urlOrKey
    const cmd = new GetObjectCommand({ Bucket: config.storage.bucket, Key: key })
    return getSignedUrl(s3, cmd, { expiresIn: expiresInSeconds })
  },

  publicUrl(key: string): string {
    return publicUrl(key)
  },
}

function publicUrl(key: string): string {
  if (config.storage.publicBaseUrl) {
    return `${config.storage.publicBaseUrl.replace(/\/$/, '')}/${key}`
  }
  if (config.storage.endpoint) {
    return `${config.storage.endpoint.replace(/\/$/, '')}/${config.storage.bucket}/${key}`
  }
  return `https://${config.storage.bucket}.s3.${config.storage.region}.amazonaws.com/${key}`
}

function extractKey(urlOrKey: string): string | null {
  try {
    const base = config.storage.publicBaseUrl || config.storage.endpoint
    if (base && urlOrKey.startsWith(base)) {
      return urlOrKey.replace(base.replace(/\/$/, '') + '/', '')
    }
    // If already a key (no http)
    if (!urlOrKey.startsWith('http')) return urlOrKey
    const url = new URL(urlOrKey)
    const parts = url.pathname.split('/')
    // For path-style: /<bucket>/<key...>
    const bucketIdx = parts.indexOf(config.storage.bucket)
    if (bucketIdx !== -1) return parts.slice(bucketIdx + 1).join('/')
    return parts.slice(1).join('/')
  } catch {
    return null
  }
}
