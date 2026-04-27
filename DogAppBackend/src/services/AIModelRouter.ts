import { Models } from '../lib/openai'
import { ComplexityAnalysis } from './BehaviorComplexityDetector'

// ─── Types ────────────────────────────────────────────────────────────────────

export type ModelTier = 'standard' | 'advanced'

export interface RoutingContext {
  isPremium:    boolean
  isFutureDog:  boolean
  complexity:   ComplexityAnalysis
}

export interface RoutingDecision {
  tier:      ModelTier
  modelId:   string
  maxTokens: number
  reason:    string
}

// ─── Thresholds ───────────────────────────────────────────────────────────────

// complexity.score must exceed this for advanced model (premium only)
const ADVANCED_SCORE_THRESHOLD = 0.70

// Token budgets
const TOKENS_STANDARD = 600
const TOKENS_ADVANCED = 900  // GPT-5.5 can go deeper when needed

// ─── Router ───────────────────────────────────────────────────────────────────

export function routeAIModel(ctx: RoutingContext): RoutingDecision {

  // Rule 1: Future Dog Mode is never upgraded — it's a free preparation feature
  if (ctx.isFutureDog) {
    return {
      tier:      'standard',
      modelId:   Models.chat,
      maxTokens: TOKENS_STANDARD,
      reason:    'future_dog_mode',
    }
  }

  // Rule 2: Free users always get the standard model
  if (!ctx.isPremium) {
    return {
      tier:      'standard',
      modelId:   Models.chat,
      maxTokens: TOKENS_STANDARD,
      reason:    'free_tier',
    }
  }

  // Rule 3: Premium users — escalate to advanced on critical moments or high complexity
  // "critical moment" (first message, owner distress, regression) always escalates regardless of score
  if (ctx.complexity.isCriticalMoment || ctx.complexity.score >= ADVANCED_SCORE_THRESHOLD) {
    return {
      tier:      'advanced',
      modelId:   Models.advanced,
      maxTokens: TOKENS_ADVANCED,
      reason:    ctx.complexity.isCriticalMoment
        ? `critical_moment(${ctx.complexity.signals.join(',')})`
        : `high_complexity(score=${ctx.complexity.score.toFixed(2)})`,
    }
  }

  // Rule 4: Premium user, routine question — standard is sufficient
  return {
    tier:      'standard',
    modelId:   Models.chat,
    maxTokens: TOKENS_STANDARD,
    reason:    `standard_complexity(score=${ctx.complexity.score.toFixed(2)})`,
  }
}
