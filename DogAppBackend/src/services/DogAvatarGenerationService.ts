import { getImageModel } from '../lib/gemini'
import { openai } from '../lib/openai'
import { AvatarStorageService } from '../lib/storage'
import { AvatarPromptComposer, DogVisualTraitsInput } from './AvatarPromptComposer'
import { config } from '../config'

export interface GenerationResult {
  avatarUrl: string
  thumbnailUrl?: string
  provider: string
  promptVersion: string
}

export const DogAvatarGenerationService = {

  async generate(traits: DogVisualTraitsInput, referencePhotoUrls: string[] = []): Promise<GenerationResult> {
    const providers = config.avatar.providerPriority // ['gemini', 'openai']
    let lastError: Error | null = null

    for (const provider of providers) {
      try {
        if (provider === 'gemini') {
          return await generateWithGemini(traits)
        }
        if (provider === 'openai') {
          return await generateWithOpenAI(traits)
        }
      } catch (err: any) {
        console.warn(`[AvatarGen] Provider ${provider} failed:`, err?.message)
        lastError = err
        continue
      }
    }

    throw lastError || new Error('All avatar generation providers failed')
  },
}

async function generateWithGemini(traits: DogVisualTraitsInput): Promise<GenerationResult> {
  const prompt = AvatarPromptComposer.buildPositivePrompt(traits)
  const model  = getImageModel()

  const result = await model.generateContent(prompt)
  const response = result.response

  // Gemini image generation returns inline image data
  const candidates = (response as any).candidates || []
  for (const candidate of candidates) {
    for (const part of candidate?.content?.parts || []) {
      if (part.inlineData?.mimeType?.startsWith('image/')) {
        const url = await AvatarStorageService.uploadBase64(
          part.inlineData.data,
          'avatars',
          'png',
          part.inlineData.mimeType,
        )
        return { avatarUrl: url, provider: 'gemini', promptVersion: 'v1' }
      }
    }
  }
  throw new Error('Gemini returned no image data')
}

async function generateWithOpenAI(traits: DogVisualTraitsInput): Promise<GenerationResult> {
  const prompt   = AvatarPromptComposer.buildPositivePrompt(traits)
  const negative = AvatarPromptComposer.buildNegativePrompt()

  const fullPrompt = `${prompt}\n\nAvoid: ${negative}`

  const response = await (openai.images as any).generate({
    model:   config.openai.imageModel,
    prompt:  fullPrompt.slice(0, 4000), // API character limit
    n:       1,
    size:    '1024x1024',
    quality: 'standard',
    response_format: 'b64_json',
  })

  const b64 = response.data?.[0]?.b64_json
  if (!b64) throw new Error('OpenAI returned no image data')

  const url = await AvatarStorageService.uploadBase64(b64, 'avatars', 'png', 'image/png')
  return { avatarUrl: url, provider: 'openai', promptVersion: 'v1' }
}
