import OpenAI from 'openai'
import { z } from 'zod'
import { Models } from '../lib/openai'
import { logger } from '../lib/logger'

// ─── Output schema ────────────────────────────────────────────────────────────

const ParsedActivitySchema = z.object({
  activityType:   z.enum(['walking', 'playing', 'feeding', 'training']).nullable(),
  durationMin:    z.number().int().min(1).max(300).nullable(),
  quality:        z.enum(['great', 'mixed', 'tough']).nullable(),
  notes:          z.string().max(500).nullable(),
  behaviorIssues: z.array(z.string()).max(5),
  emotionalTone:  z.enum(['positive', 'neutral', 'frustrated', 'worried']),
  confidence:     z.number().min(0).max(1),
  rawSummary:     z.string().max(200),   // human-readable confirmation line
})

export type ParsedActivity = z.infer<typeof ParsedActivitySchema>

// ─── Service ──────────────────────────────────────────────────────────────────

export class VoiceLogParserService {
  constructor(private openai: OpenAI) {}

  async parseTranscript(transcript: string, dogName: string): Promise<ParsedActivity> {
    const prompt = `You are a dog training assistant parsing a voice message from a dog owner.

Dog name: ${dogName}

Voice message: "${transcript}"

Extract a structured activity log. Return JSON matching exactly this schema:
- activityType: "walking" | "playing" | "feeding" | "training" | null
- durationMin: integer minutes (estimate if vague: "quick walk" = 15, "long walk" = 45) | null
- quality: "great" | "mixed" | "tough" (based on owner's tone and words) | null
- notes: any specific detail worth saving | null
- behaviorIssues: array of string issues mentioned (e.g., ["pulled on leash", "barked at dog"])
- emotionalTone: "positive" | "neutral" | "frustrated" | "worried"
- confidence: 0.0–1.0 (how clearly the activity type was stated)
- rawSummary: one short sentence describing what you understood (e.g., "30-min walk, some pulling, good overall")

Rules:
- If no specific activity is clear, set activityType null and confidence below 0.4
- Infer duration from context clues ("short" = 10–15 min, "long" = 45+ min)
- behaviorIssues should capture specific problems mentioned, not generic descriptions
- rawSummary is shown to the user as confirmation — make it natural and friendly`

    const response = await this.openai.chat.completions.create({
      model:           Models.extraction,
      temperature:     0.1,
      max_tokens:      400,
      response_format: { type: 'json_object' },
      messages: [
        { role: 'system', content: 'You parse dog owner voice logs into structured JSON. Be accurate and concise.' },
        { role: 'user',   content: prompt },
      ],
    })

    const raw = response.choices[0]?.message?.content ?? '{}'
    try {
      const parsed    = JSON.parse(raw)
      const validated = ParsedActivitySchema.parse(parsed)
      logger.info({ action: 'voice_log_parsed', activityType: validated.activityType, confidence: validated.confidence })
      return validated
    } catch (err) {
      logger.error({ err, raw }, 'voice_log_parse_failed — returning fallback')
      return {
        activityType:   null,
        durationMin:    null,
        quality:        null,
        notes:          transcript.slice(0, 500),
        behaviorIssues: [],
        emotionalTone:  'neutral',
        confidence:     0.1,
        rawSummary:     "Couldn't parse automatically — please fill in the details below.",
      }
    }
  }
}
