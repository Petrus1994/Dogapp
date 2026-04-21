import { PrismaClient } from '@prisma/client'
import OpenAI from 'openai'
import { MemoryPreparationService } from './MemoryPreparationService'
import { Models } from '../lib/openai'
import { Errors } from '../lib/errors'
import { config } from '../config'
import { todayDate } from '../utils/dates'
import { logger } from '../lib/logger'

const SYSTEM_PROMPT = `You are an expert certified dog trainer and behavior consultant.
You operate exclusively within positive reinforcement methodology.

Core principles you NEVER violate:
- A dog never behaves for no reason. Always look for the cause.
- State before obedience: a dog that is stressed, overexcited, or unmet in its needs cannot learn.
- Trust is built through consistency, clarity, and calm leadership.
- You do not punish. You redirect, adjust environment, and reinforce what works.
- You always understand the dog's developmental stage before giving advice.

You think like a trainer who has seen thousands of dogs — not like a general chatbot.
Every response is grounded in the specific dog's profile and history stored in memory.`

const DEVELOPER_PROMPT = `ROUTING RULES — follow in order for every message:
1. Classify the issue: is this about behavior, training technique, routine, health concern, or emotional support?
2. Identify the dog's current state from memory context: overexcited / stressed / balanced / undertrained?
3. Check for recurring triggers in memory — if a known trigger is involved, reference it.
4. Distinguish: is this a capability problem (dog doesn't know) or motivation problem (dog knows but won't)?
5. Build your answer in this order: root cause → immediate action → longer-term approach
6. If the owner is contributing to the problem (inconsistency, timing errors, emotional state), address it diplomatically.
7. Always end with one concrete thing to try TODAY.

RESPONSE FORMAT RULES:
- Maximum 250 words unless the topic demands more detail
- Use plain text — no markdown headers, no bullet walls
- One paragraph for diagnosis, one for action
- Use the dog's name from memory
- Tone: warm, direct, professional — like a trainer speaking at a session
- Never say "great question" or similar filler
- If you lack enough context, ask one focused question`

export class AIChatService {
  constructor(
    private db:     PrismaClient,
    private openai: OpenAI,
    private memory: MemoryPreparationService,
  ) {}

  async chat(userId: string, dogId: string | null, conversationId: string | null, userMessage: string) {
    // Enforce free tier limits
    await this.checkUsageLimit(userId)

    // Get or create conversation
    const conv = conversationId
      ? await this.db.aiConversation.findFirst({ where: { id: conversationId, userId } })
      : await this.db.aiConversation.create({ data: { userId, dogId } })

    if (!conv) throw Errors.notFound('Conversation')

    // Load history (last 20 messages = 10 exchanges)
    const history = await this.db.aiMessage.findMany({
      where:   { conversationId: conv.id },
      orderBy: { createdAt: 'asc' },
      take:    20,
    })

    // Build memory block
    const memoryBlock = dogId ? await this.memory.getSnapshot(dogId) : ''

    // Compose messages
    const messages: OpenAI.Chat.ChatCompletionMessageParam[] = [
      { role: 'system',    content: SYSTEM_PROMPT },
      { role: 'system',    content: DEVELOPER_PROMPT },
      ...(memoryBlock ? [{ role: 'system' as const, content: memoryBlock }] : []),
      ...history.map((m) => ({
        role:    m.role as 'user' | 'assistant',
        content: m.content,
      })),
      { role: 'user', content: userMessage },
    ]

    const start = Date.now()
    const completion = await this.withRetry(() =>
      this.openai.chat.completions.create({
        model:       Models.chat,
        messages,
        temperature: 0.7,
        max_tokens:  600,
      })
    )
    const latencyMs = Date.now() - start
    const reply     = completion.choices[0]?.message?.content ?? 'I could not generate a response. Please try again.'
    const tokens    = completion.usage?.total_tokens ?? 0

    logger.info({ action: 'ai_chat', userId, dogId, latencyMs, tokens, model: Models.chat })

    // Persist in transaction
    await this.db.$transaction([
      this.db.aiMessage.create({
        data: { conversationId: conv.id, role: 'user', content: userMessage },
      }),
      this.db.aiMessage.create({
        data: { conversationId: conv.id, role: 'assistant', content: reply, tokensUsed: tokens, latencyMs },
      }),
      this.db.aiConversation.update({
        where: { id: conv.id },
        data:  { lastMessageAt: new Date() },
      }),
      this.db.aiUsage.upsert({
        where:  { userId_usageDate: { userId, usageDate: todayDate() } },
        create: { userId, usageDate: todayDate(), requestCount: 1, tokenCount: tokens },
        update: { requestCount: { increment: 1 }, tokenCount: { increment: tokens } },
      }),
    ])

    return { reply, conversationId: conv.id }
  }

  async getHistory(userId: string, conversationId: string) {
    const conv = await this.db.aiConversation.findFirst({ where: { id: conversationId, userId } })
    if (!conv) throw Errors.notFound('Conversation')

    return this.db.aiMessage.findMany({
      where:   { conversationId },
      orderBy: { createdAt: 'asc' },
      select:  { role: true, content: true, createdAt: true },
    })
  }

  private async checkUsageLimit(userId: string) {
    const sub = await this.db.subscription.findUnique({ where: { userId } })
    if (sub?.tier === 'premium') return // no limit

    const today = todayDate()
    const usage = await this.db.aiUsage.findUnique({
      where: { userId_usageDate: { userId, usageDate: today } },
    })
    if ((usage?.requestCount ?? 0) >= config.limits.freeAiRequestsPerDay) {
      throw Errors.aiLimitReached()
    }
  }

  private async withRetry<T>(fn: () => Promise<T>, attempts = 3): Promise<T> {
    for (let i = 0; i < attempts; i++) {
      try {
        return await fn()
      } catch (err: any) {
        if (i === attempts - 1) throw err
        await new Promise((r) => setTimeout(r, 1500 * Math.pow(2, i)))
      }
    }
    throw new Error('unreachable')
  }
}
