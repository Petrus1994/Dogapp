import OpenAI from 'openai'
import { config } from '../config'

export const openai = new OpenAI({ apiKey: config.openai.apiKey })

export const Models = {
  // High-frequency, structured tasks — cheap, fast
  extraction: 'gpt-4.1-nano',

  // Standard coaching, plan generation, simulation evaluation
  chat:    'gpt-4.1-mini',
  plan:    'gpt-4.1-mini',
  insight: 'gpt-4.1-mini',

  // Premium deep coaching — selective use only (see AIModelRouter)
  advanced: 'gpt-5.5',
} as const

export type ModelId = typeof Models[keyof typeof Models]
