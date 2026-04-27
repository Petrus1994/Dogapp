import { PrismaClient } from '@prisma/client'
import OpenAI from 'openai'
import { MemoryPreparationService } from './MemoryPreparationService'
import { analyzeComplexity } from './BehaviorComplexityDetector'
import { routeAIModel, RoutingDecision } from './AIModelRouter'
import { Models } from '../lib/openai'
import { Errors } from '../lib/errors'
import { config } from '../config'
import { todayDate } from '../utils/dates'
import { logger } from '../lib/logger'

// ─── Real Dog Mode prompts ────────────────────────────────────────────────────

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

// ─── Advanced (GPT-5.5) coaching depth prompt ─────────────────────────────────
// Injected as an additional system message ONLY when the advanced model is selected.
// Overrides the word limit and demands expert-level structural analysis.

const ADVANCED_COACHING_PROMPT = `PREMIUM COACHING DEPTH ENABLED

You have been selected for this interaction because the situation requires expert-level behavioral analysis.

Your response MUST go significantly deeper than standard advice:
- Identify the behavioral root cause with clinical precision — not surface symptoms
- Reference specific patterns, scores, triggers, and history from the memory context
- Explain WHY this behavior occurs: the neurological, developmental, and environmental mechanics
- Structure your answer: (1) Root cause diagnosis, (2) Immediate management steps, (3) Long-term conditioning protocol
- If the owner has tried approaches that appear in memory, explain specifically why they may not have worked
- Anticipate the next obstacle the owner will face and address it preemptively
- Acknowledge the owner's emotional state if distress signals are present — validate before advising
- You may use up to 400 words when the complexity demands it — never pad, always earn the length

This is a premium subscriber. They deserve the equivalent of a one-on-one session with an expert trainer, not a generic tip list.`

// ─── Future Dog Mode prompts ──────────────────────────────────────────────────

const FUTURE_DOG_SYSTEM_PROMPT = `You are a dog preparation mentor and behavioral educator. You work with people who do not yet have a dog but are preparing to become great dog owners.

Your role is teacher, mentor, and realistic simulator — not a reactive problem-solver.

You NEVER:
- Pretend a real dog is present
- Give advice framed as "your dog is doing this"
- Use reactive, problem-fixing language

You ALWAYS:
- Teach the principles behind dog behavior
- Help the user understand what to EXPECT before it happens
- Simulate how a real dog would respond to different owner approaches
- Build the user's mental model of calm, consistent ownership
- Reference their preparation history when relevant

Core methodology (Dream Puppy):
- State before obedience: a dog in the wrong emotional state cannot learn
- Owner energy is the most powerful variable in every interaction
- Every behavior has a cause — understanding causes matters more than knowing commands
- Routine, calm, and predictability are the foundation of a stable dog
- Gradual exposure always. Never flood, never rush, never punish.`

const FUTURE_DOG_DEVELOPER_PROMPT = `YOU ARE SPEAKING WITH A FUTURE DOG OWNER — they do not have a dog yet.

ROUTING RULES for every message:
1. Is this a question about what to expect? → Explain the likely scenario and the principle behind it.
2. Is this about a specific behavior? → Describe how that behavior works, why dogs do it, and what the owner's response should look like.
3. Is this about preparation? → Give concrete, practical preparation steps they can take NOW.
4. Is this a "what would happen if I did X" question? → Simulate the likely dog response honestly, then explain the better approach.
5. Is this about breed research or home setup? → Give practical guidance based on their profile.

RESPONSE FORMAT:
- Maximum 220 words
- Plain text, no bullet walls
- Start with the principle or concept, then make it practical
- Always end with one thing they can think about, research, or set up TODAY
- Tone: warm educator and experienced mentor — not a chatbot dispensing tips
- Never say "great question" or filler phrases
- If their preparation history shows gaps, gently bring them into the conversation`

// ─── Service ──────────────────────────────────────────────────────────────────

export class AIChatService {
  constructor(
    private db:     PrismaClient,
    private openai: OpenAI,
    private memory: MemoryPreparationService,
  ) {}

  async chat(userId: string, dogId: string | null, conversationId: string | null, userMessage: string) {
    // Check limit and get tier in one DB call
    const { isPremium } = await this.checkUsageLimitAndGetTier(userId)

    // Auto-detect mode: active dog → real dog mode; else check for future dog profile
    const hasDog = dogId != null || !!(await this.db.dog.findFirst({ where: { userId, isActive: true, deletedAt: null } }))
    const futureDogProfile = !hasDog
      ? await this.db.futureDogProfile.findUnique({ where: { userId } })
      : null
    const isFutureDog = futureDogProfile != null

    // Select prompts
    const systemPrompt = isFutureDog ? FUTURE_DOG_SYSTEM_PROMPT : SYSTEM_PROMPT
    const devPrompt    = isFutureDog ? FUTURE_DOG_DEVELOPER_PROMPT : DEVELOPER_PROMPT

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
    let memoryBlock: string
    if (isFutureDog) {
      memoryBlock = await this.buildFutureDogContext(futureDogProfile!.id)
    } else if (dogId) {
      memoryBlock = await this.memory.getSnapshot(dogId)
    } else {
      memoryBlock = ''
    }

    // ── Model routing ─────────────────────────────────────────────────────────
    // historyLength = assistant messages only — measures how far into the conversation we are
    const assistantMessageCount = history.filter(m => m.role === 'assistant').length
    const complexity = analyzeComplexity(userMessage, assistantMessageCount)
    const routing    = routeAIModel({ isPremium, isFutureDog, complexity })

    logger.info({
      action:      'ai_model_routed',
      userId,
      dogId,
      tier:        routing.tier,
      model:       routing.modelId,
      reason:      routing.reason,
      score:       complexity.score.toFixed(2),
      critical:    complexity.isCriticalMoment,
      signals:     complexity.signals,
    })

    // ── Compose messages ──────────────────────────────────────────────────────
    const baseMessages: OpenAI.Chat.ChatCompletionMessageParam[] = [
      { role: 'system', content: systemPrompt },
      { role: 'system', content: devPrompt },
      ...(memoryBlock ? [{ role: 'system' as const, content: memoryBlock }] : []),
    ]

    // Inject depth instructions for advanced model — placed just before history
    // so the model sees the depth requirement closest to the actual conversation
    if (routing.tier === 'advanced') {
      baseMessages.push({ role: 'system', content: ADVANCED_COACHING_PROMPT })
    }

    const messages: OpenAI.Chat.ChatCompletionMessageParam[] = [
      ...baseMessages,
      ...history.map((m) => ({ role: m.role as 'user' | 'assistant', content: m.content })),
      { role: 'user', content: userMessage },
    ]

    // ── Execute with fallback ─────────────────────────────────────────────────
    const { completion, actualModelId } = await this.executeWithFallback(
      messages,
      routing,
      userId,
      dogId,
    )

    const latencyMs = completion._latencyMs
    const reply     = completion.choices[0]?.message?.content ?? 'I could not generate a response. Please try again.'
    const tokens    = completion.usage?.total_tokens ?? 0
    const isAdvanced = actualModelId === Models.advanced

    logger.info({
      action:    'ai_chat',
      userId,
      dogId,
      latencyMs,
      tokens,
      model:     actualModelId,
      tier:      routing.tier,
      fallback:  actualModelId !== routing.modelId,
    })

    // ── Persist ───────────────────────────────────────────────────────────────
    await this.db.$transaction([
      this.db.aiMessage.create({
        data: { conversationId: conv.id, role: 'user', content: userMessage },
      }),
      this.db.aiMessage.create({
        data: {
          conversationId: conv.id,
          role:       'assistant',
          content:    reply,
          modelUsed:  actualModelId,
          tokensUsed: tokens,
          latencyMs,
        },
      }),
      this.db.aiConversation.update({
        where: { id: conv.id },
        data:  { lastMessageAt: new Date() },
      }),
      this.db.aiUsage.upsert({
        where:  { userId_usageDate: { userId, usageDate: todayDate() } },
        create: {
          userId,
          usageDate:            todayDate(),
          requestCount:         1,
          tokenCount:           tokens,
          advancedRequestCount: isAdvanced ? 1 : 0,
        },
        update: {
          requestCount:         { increment: 1 },
          tokenCount:           { increment: tokens },
          ...(isAdvanced && { advancedRequestCount: { increment: 1 } }),
        },
      }),
    ])

    return { reply, conversationId: conv.id, modelTier: routing.tier }
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

  // ─── Private: model execution with fallback ───────────────────────────────

  private async executeWithFallback(
    messages:  OpenAI.Chat.ChatCompletionMessageParam[],
    routing:   RoutingDecision,
    userId:    string,
    dogId:     string | null,
  ): Promise<{ completion: any; actualModelId: string }> {
    const start = Date.now()

    const callModel = async (modelId: string, maxTokens: number) => {
      const result = await this.openai.chat.completions.create({
        model:       modelId,
        messages,
        temperature: 0.7,
        max_tokens:  maxTokens,
      }) as any
      result._latencyMs = Date.now() - start
      return result
    }

    try {
      const completion = await this.withRetry(
        () => callModel(routing.modelId, routing.maxTokens),
        routing.tier === 'advanced' ? 2 : 3,   // fewer retries for expensive model
      )
      return { completion, actualModelId: routing.modelId }
    } catch (err: any) {
      if (routing.tier !== 'advanced') throw err

      // Fallback: GPT-5.5 failed → drop to standard model, log, continue
      logger.error({
        action:  'gpt5_fallback',
        userId,
        dogId,
        reason:  err?.message ?? String(err),
        routing: routing.reason,
      })

      const completion = await this.withRetry(
        () => callModel(Models.chat, 600),
        3,
      )
      return { completion, actualModelId: Models.chat }
    }
  }

  // ─── Private: future dog context block ───────────────────────────────────

  private async buildFutureDogContext(futureDogProfileId: string): Promise<string> {
    const [fdProfile, learningProfile] = await Promise.all([
      this.db.futureDogProfile.findUnique({ where: { id: futureDogProfileId } }),
      this.db.userLearningProfile.findUnique({ where: { futureDogProfileId } }),
    ])
    if (!fdProfile) return ''

    let block = `\nFUTURE DOG OWNER PROFILE\n`
    block += `Lifestyle: ${fdProfile.lifestyle}, Home: ${fdProfile.homeType}, Time availability: ${fdProfile.timeAvailability}\n`
    if (fdProfile.preferredBreed) block += `Preferred breed: ${fdProfile.preferredBreed}\n`
    if (fdProfile.expectedSize)   block += `Expected size: ${fdProfile.expectedSize}\n`
    block += `Preparation stage: ${fdProfile.preparationStage}\n`

    if (learningProfile) {
      block += `Scenarios completed: ${learningProfile.scenariosCompleted}\n`
      block += `Consistency score: ${Math.round(Number(learningProfile.consistencyScore) * 100)}%\n`
      block += `Readiness: ${Math.round(Number(learningProfile.overallReadinessScore) * 100)}%\n`
      if (learningProfile.knownStrengths.length > 0) block += `Known strengths: ${learningProfile.knownStrengths.join(', ')}\n`
      if (learningProfile.knownGaps.length > 0)      block += `Known gaps: ${learningProfile.knownGaps.join(', ')}\n`
    }

    block += `\nThis user does NOT have a dog yet. Speak as a preparation mentor, not a reactive coach.\n`
    return block
  }

  // ─── Private: usage limit + tier check ───────────────────────────────────
  // Returns isPremium so we avoid a second subscription query for the router.

  private async checkUsageLimitAndGetTier(userId: string): Promise<{ isPremium: boolean }> {
    const sub = await this.db.subscription.findUnique({ where: { userId } })
    const isPremium = sub?.tier === 'premium'
    if (isPremium) return { isPremium: true }

    const today = todayDate()
    const usage = await this.db.aiUsage.findUnique({
      where: { userId_usageDate: { userId, usageDate: today } },
    })
    if ((usage?.requestCount ?? 0) >= config.limits.freeAiRequestsPerDay) {
      throw Errors.aiLimitReached()
    }

    return { isPremium: false }
  }

  // ─── Private: exponential-backoff retry ──────────────────────────────────

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
