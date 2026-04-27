import OpenAI, { toFile } from 'openai'
import { logger } from '../lib/logger'

export class TranscribeService {
  constructor(private openai: OpenAI) {}

  async transcribeBuffer(
    buffer: Buffer,
    filename: string,
    mimetype: string,
  ): Promise<{ text: string; durationSeconds: number | null }> {
    const file = await toFile(buffer, filename, { type: mimetype })

    const response = await this.openai.audio.transcriptions.create({
      file,
      model: 'whisper-1',
      response_format: 'verbose_json',
      language: 'en',
    })

    const text = response.text.trim()
    const durationSeconds = (response as any).duration ?? null

    logger.info({
      action: 'voice_transcribed',
      chars: text.length,
      durationSeconds,
    })

    return { text, durationSeconds }
  }
}
