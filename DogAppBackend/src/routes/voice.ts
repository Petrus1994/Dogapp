import { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { requireAuth } from '../middleware/auth'
import { VoiceLogParserService } from '../services/VoiceLogParserService'
import { TranscribeService } from '../services/TranscribeService'
import { prisma } from '../lib/prisma'
import { openai } from '../lib/openai'
import { Errors } from '../lib/errors'

const ParseLogBody = z.object({
  transcript: z.string().min(3).max(2000),
  dogId:      z.string(),
})

const MAX_AUDIO_BYTES = 10 * 1024 * 1024 // 10 MB

export async function voiceRoutes(app: FastifyInstance) {
  const parser      = new VoiceLogParserService(openai)
  const transcriber = new TranscribeService(openai)

  // POST /v1/voice/transcribe
  // Accepts multipart audio (m4a / wav) → Whisper → returns clean transcript
  app.post('/voice/transcribe', { preHandler: requireAuth }, async (req, reply) => {
    const data = await req.file()
    if (!data) throw Errors.badRequest('No audio file uploaded')

    const buffer = await data.toBuffer()
    if (buffer.length > MAX_AUDIO_BYTES) throw Errors.badRequest('Audio too large (max 10 MB)')
    if (buffer.length < 100) throw Errors.badRequest('Audio file is empty')

    const result = await transcriber.transcribeBuffer(buffer, data.filename, data.mimetype)
    return reply.code(200).send(result)
  })

  // POST /v1/voice/parse-log
  // Client sends transcript → AI parses into structured activity log
  app.post('/voice/parse-log', { preHandler: requireAuth }, async (req, reply) => {
    const body = ParseLogBody.parse(req.body)

    const dog = await prisma.dog.findFirst({
      where: { id: body.dogId, userId: req.user.userId },
    })
    if (!dog) throw Errors.notFound('Dog')

    const parsed = await parser.parseTranscript(body.transcript, dog.name)
    return reply.code(200).send({ parsed, dogId: body.dogId })
  })
}
