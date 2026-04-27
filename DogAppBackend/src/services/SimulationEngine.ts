import OpenAI from 'openai'
import { PrismaClient } from '@prisma/client'
import { Models } from '../lib/openai'
import { logger } from '../lib/logger'

// ─── Scenario seeds per category ─────────────────────────────────────────────
// Each seed is a situation premise. AI expands it into a full scenario.

const SCENARIO_SEEDS: Record<string, string[]> = {
  first_walk: [
    'Your puppy sees another dog across the street and lunges forward, almost pulling the leash from your hand.',
    'Your puppy freezes on the pavement and refuses to walk. People are watching.',
    'Your puppy is walking nicely, then suddenly starts pulling hard toward a smell on the ground.',
    'A child runs up to pet your puppy. Your dog jumps up excitedly.',
  ],
  home_arrival: [
    "It is your puppy's first night home. They whine continuously and will not settle.",
    'You leave the room for 5 minutes and come back to find your puppy has chewed a shoe.',
    'Your puppy keeps following you everywhere and cries when you close a door.',
    'You are eating dinner. Your puppy sits and stares, then starts barking at the table.',
  ],
  feeding: [
    'Your puppy rushes frantically at their food bowl before you have finished putting it down.',
    'You approach your puppy while they are eating and they growl quietly.',
    'Your puppy finishes their meal in 30 seconds and immediately demands more.',
    'Your puppy ignores the food you put down and walks away.',
  ],
  socialization: [
    'Your dog barks and lunges at every dog they see on a walk. Other owners give you looks.',
    'A guest arrives at your home and your puppy goes into a frenzy of jumping and biting.',
    'Your puppy hides under the bed when your friend visits and will not come out.',
    'Your dog is fine with adults but growls when a child approaches.',
  ],
  evening_calm: [
    'It is 10pm. Your puppy is racing around the house, biting furniture, and will not stop.',
    'You try to put your puppy in their crate for the night and they scream for 45 minutes.',
    'Your dog keeps nudging you, barking, and demanding attention while you try to relax.',
    "Your puppy seems exhausted but can't settle — keeps getting up, lying down, moving around.",
  ],
}

const CATEGORIES = Object.keys(SCENARIO_SEEDS)

// ─── System prompt for scenario generation ────────────────────────────────────

const GENERATION_SYSTEM = `You are a dog behavior specialist creating realistic training scenarios for people who are preparing to get their first dog. Your scenarios must feel real, specific, and emotionally honest — not trivial or cartoon-like.

Each scenario presents a single concrete moment the future owner will face. The situation must feel relatable and slightly uncomfortable — not catastrophic, but genuinely challenging.`

const EVALUATION_SYSTEM = `You are a certified dog behavior specialist evaluating a future dog owner's response to a behavioral scenario. Your job is to assess how well they understand dog behavior, state management, and calm handling — not whether they know technical commands.

Evaluate using the Dream Puppy methodology:
- Dogs are not disobedient by nature. Behavior has causes.
- State comes before obedience. Calm must come before commands.
- Owner energy is the most powerful variable.
- Never use punishment, dominance, or emotional pressure.

Be warm and educational. Never make the user feel judged. Your goal is to teach, not to score.`

// ─── Response schemas ─────────────────────────────────────────────────────────

interface GeneratedScenario {
  title: string
  description: string  // 2-3 sentences. What is happening right now, from the owner's perspective.
  hint: string         // 1 sentence. What principle is being tested here, without giving away the answer.
}

interface EvaluationResult {
  score: number           // 0–100
  whatYouUnderstood: string
  whatToImprove: string
  correctApproach: string // 3-4 practical steps, plain language
  learningTags: string[]  // e.g. ["state_management", "leash_tension", "calm_entry"]
}

// ─── Engine ───────────────────────────────────────────────────────────────────

export class SimulationEngine {
  constructor(
    private db:     PrismaClient,
    private openai: OpenAI,
  ) {}

  async generateScenario(
    userId:            string,
    futureDogProfileId: string,
    requestedCategory?: string,
  ): Promise<{ sessionId: string; category: string; title: string; description: string; hint: string }> {

    // Pick category — avoid recent repeats
    const category = requestedCategory ?? await this.pickCategory(futureDogProfileId)

    // Pick a seed at random
    const seeds = SCENARIO_SEEDS[category]
    const seed  = seeds[Math.floor(Math.random() * seeds.length)]

    // Fetch profile context
    const profile = await this.db.futureDogProfile.findUnique({
      where: { id: futureDogProfileId },
    })

    const profileContext = profile
      ? `User profile: lifestyle=${profile.lifestyle}, home=${profile.homeType}, time=${profile.timeAvailability}${profile.preferredBreed ? `, preferred breed=${profile.preferredBreed}` : ''}`
      : ''

    const prompt = `Expand this scenario seed into a vivid, realistic 2–3 sentence situation description that feels like it is happening RIGHT NOW.

Seed: "${seed}"
${profileContext}

Return ONLY valid JSON matching this schema exactly:
{
  "title": "short scenario name (4–6 words)",
  "description": "2–3 sentences describing the exact moment, from the owner's first-person perspective. Do not add commentary or advice. Just the situation.",
  "hint": "1 sentence naming which behavior principle this tests, WITHOUT giving away the correct answer. E.g. 'This tests how you manage your own energy before responding to your dog.'"
}`

    const completion = await this.openai.chat.completions.create({
      model:       Models.chat,
      messages:    [
        { role: 'system', content: GENERATION_SYSTEM },
        { role: 'user',   content: prompt },
      ],
      temperature:     0.8,
      max_tokens:      300,
      response_format: { type: 'json_object' },
    })

    const raw = completion.choices[0]?.message?.content ?? '{}'
    let parsed: GeneratedScenario
    try {
      parsed = JSON.parse(raw) as GeneratedScenario
    } catch {
      logger.warn({ raw }, 'SimulationEngine: failed to parse scenario JSON, using fallback')
      parsed = {
        title:       'Unexpected situation',
        description: seed,
        hint:        'Think about your dog\'s emotional state before deciding what to do.',
      }
    }

    // Persist the session (response is null until user submits)
    const session = await this.db.simulationSession.create({
      data: {
        userId,
        futureDogProfileId,
        category,
        title:       parsed.title,
        description: parsed.description,
        completed:   false,
      },
    })

    return {
      sessionId:   session.id,
      category,
      title:       parsed.title,
      description: parsed.description,
      hint:        parsed.hint,
    }
  }

  async evaluateResponse(
    sessionId:    string,
    userId:       string,
    userResponse: string,
  ): Promise<{
    score: number
    whatYouUnderstood: string
    whatToImprove: string
    correctApproach: string
    learningTags: string[]
  }> {

    const session = await this.db.simulationSession.findFirst({
      where: { id: sessionId, userId, completed: false },
    })
    if (!session) throw new Error('Session not found or already completed')

    const prompt = `Evaluate this future dog owner's response to a scenario.

SCENARIO
Category: ${session.category}
Situation: ${session.description}

OWNER'S RESPONSE
"${userResponse}"

Return ONLY valid JSON matching this schema:
{
  "score": <integer 0–100>,
  "whatYouUnderstood": "<1–2 sentences. Start with what they got right, even partially. Be specific. Find something genuine to affirm.>",
  "whatToImprove": "<1–2 sentences. The single most important thing they missed or misjudged. Be kind but honest.>",
  "correctApproach": "<3–4 short numbered steps. What an experienced owner would actually do in this exact situation. Plain language, no jargon.>",
  "learningTags": ["<2–4 short concept labels, e.g. state_management, calm_first, leash_tension, owner_energy, resource_trust>"]
}

Scoring guide:
90–100: Shows instinctive understanding of state-first thinking and calm ownership
70–89: Mostly correct, minor misses (e.g. correct action but wrong timing or reason)
50–69: Partially correct — some right instincts, some significant gaps
30–49: Misses the core principle but shows some awareness
0–29: Relies on punishment, dominance, or emotional reaction`

    const completion = await this.openai.chat.completions.create({
      model:       Models.chat,
      messages:    [
        { role: 'system', content: EVALUATION_SYSTEM },
        { role: 'user',   content: prompt },
      ],
      temperature:     0.4,
      max_tokens:      500,
      response_format: { type: 'json_object' },
    })

    const raw = completion.choices[0]?.message?.content ?? '{}'
    let result: EvaluationResult
    try {
      result = JSON.parse(raw) as EvaluationResult
    } catch {
      logger.warn({ raw }, 'SimulationEngine: failed to parse evaluation JSON')
      result = {
        score:             50,
        whatYouUnderstood: 'You showed thoughtfulness in your response.',
        whatToImprove:     'Focus on your dog\'s emotional state before taking action.',
        correctApproach:   '1. Stop and breathe. 2. Assess what state your dog is in. 3. Respond calmly and clearly.',
        learningTags:      ['state_management'],
      }
    }

    // Persist evaluation
    await this.db.simulationSession.update({
      where: { id: sessionId },
      data:  {
        userResponse:   userResponse,
        aiEvaluation:   result.correctApproach,
        correctApproach: result.correctApproach,
        whatUnderstood: result.whatYouUnderstood,
        whatToImprove:  result.whatToImprove,
        score:          result.score,
        completed:      true,
        completedAt:    new Date(),
      },
    })

    return result
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  private async pickCategory(futureDogProfileId: string): Promise<string> {
    // Find the category the user has done least recently
    const recentSessions = await this.db.simulationSession.findMany({
      where:   { futureDogProfileId, completed: true },
      orderBy: { completedAt: 'desc' },
      take:    10,
      select:  { category: true },
    })

    const recentCategories = new Set(recentSessions.slice(0, 3).map(s => s.category))
    const available = CATEGORIES.filter(c => !recentCategories.has(c))

    if (available.length > 0) {
      return available[Math.floor(Math.random() * available.length)]
    }
    return CATEGORIES[Math.floor(Math.random() * CATEGORIES.length)]
  }
}
