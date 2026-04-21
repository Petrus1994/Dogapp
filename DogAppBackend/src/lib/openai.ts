import OpenAI from 'openai'
import { config } from '../config'

export const openai = new OpenAI({ apiKey: config.openai.apiKey })

export const Models = {
  chat:       'gpt-4.1-mini',
  extraction: 'gpt-4.1-nano',
  plan:       'gpt-4.1-mini',
  insight:    'gpt-4.1-mini',
} as const
