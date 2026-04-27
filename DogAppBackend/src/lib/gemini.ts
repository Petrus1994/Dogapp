import { GoogleGenerativeAI, HarmCategory, HarmBlockThreshold } from '@google/generative-ai'
import { config } from '../config'

const genAI = new GoogleGenerativeAI(config.gemini.apiKey)

// Safety settings: relaxed for realistic dog imagery
const safetySettings = [
  { category: HarmCategory.HARM_CATEGORY_HARASSMENT,        threshold: HarmBlockThreshold.BLOCK_ONLY_HIGH },
  { category: HarmCategory.HARM_CATEGORY_HATE_SPEECH,       threshold: HarmBlockThreshold.BLOCK_ONLY_HIGH },
  { category: HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT, threshold: HarmBlockThreshold.BLOCK_ONLY_HIGH },
  { category: HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT, threshold: HarmBlockThreshold.BLOCK_ONLY_HIGH },
]

export function getVisionModel() {
  return genAI.getGenerativeModel({
    model:          config.gemini.visionModel,
    safetySettings,
  })
}

export function getImageModel() {
  return genAI.getGenerativeModel({
    model:          config.gemini.imageModel,
    safetySettings,
    generationConfig: { responseModalities: ['Text', 'Image'] } as any,
  })
}

export { genAI }
