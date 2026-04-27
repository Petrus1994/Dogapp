// Pure heuristic — no I/O, no AI calls. Scores the cognitive complexity
// of a user message so the model router can decide escalation threshold.

export interface ComplexityAnalysis {
  score:            number    // 0.0 – 1.0
  signals:          string[]  // human-readable reasons (for logging)
  isCriticalMoment: boolean   // override flag — always triggers advanced for premium
}

// ─── Keyword sets ─────────────────────────────────────────────────────────────

// Root behavioral problems — each unique match adds weight
const BEHAVIOR_ROOTS = [
  'bark', 'bite', 'aggress', 'snap', 'growl', 'lunge', 'react',
  'anxiet', 'fear', 'phobia', 'panic', 'stress', 'separat',
  'jump', 'pull', 'drag', 'lunge',
  'potty', 'toilet', 'accident', 'indoor',
  'obsess', 'compulsiv', 'repetit',
  'resource', 'guard', 'possessiv',
  'destroy', 'chew', 'dig', 'escape',
  'avoid', 'cower', 'hide', 'submit',
  'mount', 'hump', 'dominan',
  'food', 'feeding', 'eating', 'refuse',
  'socialization', 'stranger', 'other dog',
]

// Signals that the user has tried things and they're not working
const CONFLICT_SIGNALS = [
  'but ', 'however', 'although', 'yet ',
  'i tried', 'we tried', 'tried everything', 'tried that',
  "doesn't work", 'not working', 'still does', 'still happening',
  'keeps doing', 'keeps barking', 'keeps biting', 'keeps jumping',
  'nothing helps', 'nothing works', 'mixed signals', 'inconsistent',
  'unpredictable', 'sometimes works', 'not always',
]

// Multi-factor complexity — multiple issues in one message
const MULTI_FACTOR_SIGNALS = [
  'and also', 'on top of that', 'another issue', 'another problem',
  'at the same time', 'multiple', 'several issues', 'various',
  'different situations', 'both ', 'as well as',
]

// Distress — owner is emotionally struggling → critical moment
const DISTRESS_SIGNALS = [
  'frustrated', 'frustrating', 'desperate', 'hopeless',
  "don't know what to do", "don't know why", "don't understand",
  'giving up', 'given up', 'at my wit', 'end of my rope',
  'can\'t take it', 'can\'t handle', 'overwhelmed',
  'exhausted', 'lost', 'help me', 'please help',
  'crying', 'upset', 'devastated', 'regret',
]

// Regression — things were working, now they aren't → critical moment
const REGRESSION_SIGNALS = [
  'getting worse', 'worse than before', 'went backward', 'going backward',
  'used to be fine', 'used to work', 'stopped working',
  'regressed', 'regression', 'back to square', 'undone all',
  'lost progress', 'lost all progress',
]

// ─── Scorer ───────────────────────────────────────────────────────────────────

export function analyzeComplexity(
  message:       string,
  historyLength: number,   // 0 = first message in conversation
): ComplexityAnalysis {
  const lower   = message.toLowerCase()
  const signals: string[] = []
  let score     = 0.15  // baseline — even simple questions deserve some weight
  let isCriticalMoment = false

  // ── First message in conversation (onboarding / fresh start) ──────────────
  // Per spec: "FIRST AI RESPONSE must use GPT-5.5" → always critical
  if (historyLength === 0) {
    score += 0.30
    isCriticalMoment = true
    signals.push('first_message')
  }

  // ── Behavioral root keywords ──────────────────────────────────────────────
  const matchedBehaviors = BEHAVIOR_ROOTS.filter(k => lower.includes(k))
  const behaviorScore    = Math.min(matchedBehaviors.length * 0.10, 0.30)
  if (behaviorScore > 0) {
    score += behaviorScore
    signals.push(`behavioral_keywords(${matchedBehaviors.slice(0, 3).join(',')})`)
  }

  // ── Conflict / "I tried but" signals ─────────────────────────────────────
  const hasConflict = CONFLICT_SIGNALS.some(k => lower.includes(k))
  if (hasConflict) {
    score += 0.15
    signals.push('conflict_signal')
  }

  // ── Multi-factor complexity ───────────────────────────────────────────────
  const isMultiFactor = MULTI_FACTOR_SIGNALS.some(k => lower.includes(k))
  if (isMultiFactor) {
    score += 0.10
    signals.push('multi_factor')
  }

  // ── Message length ────────────────────────────────────────────────────────
  if (message.length > 300) {
    score += 0.10
    signals.push('long_message')
  } else if (message.length > 150) {
    score += 0.05
    signals.push('medium_message')
  }

  // ── Multiple sentences ────────────────────────────────────────────────────
  const sentenceCount = (message.match(/[.!?]/g) ?? []).length
  if (sentenceCount >= 4) {
    score += 0.05
    signals.push('multi_sentence')
  }

  // ── Distress signals → critical moment ───────────────────────────────────
  const hasDistress = DISTRESS_SIGNALS.some(k => lower.includes(k))
  if (hasDistress) {
    score += 0.30
    isCriticalMoment = true
    signals.push('owner_distress')
  }

  // ── Regression signals → critical moment ─────────────────────────────────
  const hasRegression = REGRESSION_SIGNALS.some(k => lower.includes(k))
  if (hasRegression) {
    score += 0.20
    isCriticalMoment = true
    signals.push('behavior_regression')
  }

  return {
    score:            Math.min(score, 1.0),
    signals,
    isCriticalMoment,
  }
}
