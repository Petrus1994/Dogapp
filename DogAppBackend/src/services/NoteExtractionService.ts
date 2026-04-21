import { PrismaClient } from '@prisma/client'
import OpenAI from 'openai'
import { z } from 'zod'
import { Models } from '../lib/openai'
import { logger } from '../lib/logger'

const ExtractionSchema = z.object({
  signals: z.array(z.object({
    signalType:     z.enum([
      'issue_observed', 'positive_behavior', 'trigger_identified',
      'what_worked', 'what_failed', 'context_clue', 'owner_state', 'environment_factor',
    ]),
    dimension:      z.enum(['foodBehavior', 'activityExcitement', 'ownerContact', 'socialization']).nullable(),
    content:        z.string().max(300),
    sentimentScore: z.number().min(-1).max(1),
    confidence:     z.number().min(0).max(1),
  })),
  triggers:   z.array(z.string().max(100)),
  whatWorked: z.array(z.string().max(200)),
  whatFailed: z.array(z.string().max(200)),
})

const EXTRACTION_PROMPT = `You are a dog behavior analyst. Extract structured signals from this training note.

Return JSON with:
- signals: array of behavioral signals observed
  - signalType: one of issue_observed | positive_behavior | trigger_identified | what_worked | what_failed | context_clue | owner_state | environment_factor
  - dimension: one of foodBehavior | activityExcitement | ownerContact | socialization | null
  - content: brief description (max 50 words)
  - sentimentScore: -1.0 (very negative) to 1.0 (very positive) for the dimension
  - confidence: 0.0 to 1.0 how confident you are in this signal
- triggers: specific triggers observed (max 5 strings)
- whatWorked: techniques that worked (max 3 strings)
- whatFailed: techniques that failed (max 3 strings)

Be conservative — only extract what is clearly stated. Return {"signals":[],"triggers":[],"whatWorked":[],"whatFailed":[]} if nothing meaningful.`

export class NoteExtractionService {
  constructor(private db: PrismaClient, private openai: OpenAI) {}

  async extract(noteId: string): Promise<void> {
    const note = await this.db.userNote.findUniqueOrThrow({
      where:   { id: noteId },
      include: { dog: true },
    })

    if (note.rawText.trim().length < 5) {
      await this.db.userNote.update({ where: { id: noteId }, data: { isExtracted: true } })
      return
    }

    try {
      const response = await this.openai.chat.completions.create({
        model:           Models.extraction,
        temperature:     0.1,
        response_format: { type: 'json_object' },
        messages: [
          { role: 'system', content: EXTRACTION_PROMPT },
          {
            role: 'user',
            content: `Dog: ${note.dog.name}, ${note.dog.ageGroup}, ${note.dog.breed ?? 'mixed'}\nActivity: ${note.sourceType}\nNote: ${note.rawText}`,
          },
        ],
      })

      const raw       = response.choices[0]?.message?.content ?? '{}'
      const parsed    = JSON.parse(raw)
      const validated = ExtractionSchema.parse(parsed)

      await this.db.$transaction(async (tx) => {
        if (validated.signals.length > 0) {
          await tx.extractedNoteSignal.createMany({
            data: validated.signals.map((s) => ({
              noteId:        note.id,
              dogId:         note.dogId,
              signalType:    s.signalType,
              dimension:     s.dimension,
              content:       s.content,
              sentimentScore: s.sentimentScore,
              confidence:    s.confidence,
            })),
          })
        }

        for (const trigger of validated.triggers) {
          await tx.recurringTrigger.upsert({
            where:  { dogId_triggerPattern: { dogId: note.dogId, triggerPattern: trigger } },
            create: { dogId: note.dogId, triggerPattern: trigger, activityContext: note.sourceType },
            update: { occurrenceCount: { increment: 1 }, lastSeen: new Date() },
          })
        }

        // Append what worked / failed to dog memory
        if (validated.whatWorked.length > 0 || validated.whatFailed.length > 0) {
          const memory = await tx.dogMemory.findUnique({ where: { dogId: note.dogId } })
          if (memory) {
            await tx.dogMemory.update({
              where: { dogId: note.dogId },
              data: {
                whatWorked:           { set: [...(memory.whatWorked ?? []), ...validated.whatWorked].slice(-20) },
                whatFailed:           { set: [...(memory.whatFailed ?? []), ...validated.whatFailed].slice(-20) },
                totalNotesProcessed:  { increment: 1 },
              },
            })
          }
        }

        await tx.userNote.update({
          where: { id: noteId },
          data:  { isExtracted: true },
        })
      })

      logger.info({ action: 'note_extracted', noteId, dogId: note.dogId, signalCount: validated.signals.length })

    } catch (err) {
      logger.error({ action: 'note_extraction_failed', noteId, err })
      await this.db.userNote.update({
        where: { id: noteId },
        data:  { extractionError: String(err) },
      })
      throw err
    }
  }
}
