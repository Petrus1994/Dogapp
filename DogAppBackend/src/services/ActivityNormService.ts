export type ActivityLevel = 'low' | 'medium' | 'high'

export interface ActivityNorm {
  ageGroup:       string
  activityLevel:  ActivityLevel
  minMinutes:     number
  maxMinutes:     number
  minKm:          number
  maxKm:          number
  minSessions:    number
  maxSessions:    number
  minPlayRatio:   number
  maxPlayRatio:   number
}

// Canonical norm table — all values from the product spec
const NORM_TABLE: ActivityNorm[] = [
  // 2–3 months
  { ageGroup: '2-3m', activityLevel: 'low',    minMinutes: 20,  maxMinutes: 40,  minKm: 0.5, maxKm: 1,   minSessions: 6, maxSessions: 8, minPlayRatio: 0.6, maxPlayRatio: 0.7 },
  { ageGroup: '2-3m', activityLevel: 'medium', minMinutes: 30,  maxMinutes: 60,  minKm: 1,   maxKm: 1.5, minSessions: 6, maxSessions: 8, minPlayRatio: 0.6, maxPlayRatio: 0.7 },
  { ageGroup: '2-3m', activityLevel: 'high',   minMinutes: 40,  maxMinutes: 70,  minKm: 1.5, maxKm: 2,   minSessions: 6, maxSessions: 8, minPlayRatio: 0.6, maxPlayRatio: 0.7 },
  // 4–6 months
  { ageGroup: '4-6m', activityLevel: 'low',    minMinutes: 40,  maxMinutes: 60,  minKm: 1,   maxKm: 2,   minSessions: 4, maxSessions: 6, minPlayRatio: 0.5, maxPlayRatio: 0.6 },
  { ageGroup: '4-6m', activityLevel: 'medium', minMinutes: 60,  maxMinutes: 90,  minKm: 2,   maxKm: 3,   minSessions: 4, maxSessions: 6, minPlayRatio: 0.5, maxPlayRatio: 0.6 },
  { ageGroup: '4-6m', activityLevel: 'high',   minMinutes: 90,  maxMinutes: 120, minKm: 3,   maxKm: 4,   minSessions: 4, maxSessions: 6, minPlayRatio: 0.5, maxPlayRatio: 0.6 },
  // 6–9 months
  { ageGroup: '6-9m', activityLevel: 'low',    minMinutes: 60,  maxMinutes: 80,  minKm: 2,   maxKm: 3,   minSessions: 2, maxSessions: 4, minPlayRatio: 0.4, maxPlayRatio: 0.5 },
  { ageGroup: '6-9m', activityLevel: 'medium', minMinutes: 80,  maxMinutes: 120, minKm: 3,   maxKm: 5,   minSessions: 2, maxSessions: 4, minPlayRatio: 0.4, maxPlayRatio: 0.5 },
  { ageGroup: '6-9m', activityLevel: 'high',   minMinutes: 120, maxMinutes: 160, minKm: 5,   maxKm: 7,   minSessions: 2, maxSessions: 4, minPlayRatio: 0.4, maxPlayRatio: 0.5 },
  // 9–12 months
  { ageGroup: '9-12m', activityLevel: 'low',    minMinutes: 60,  maxMinutes: 90,  minKm: 2,   maxKm: 3,   minSessions: 2, maxSessions: 3, minPlayRatio: 0.3, maxPlayRatio: 0.4 },
  { ageGroup: '9-12m', activityLevel: 'medium', minMinutes: 90,  maxMinutes: 140, minKm: 3,   maxKm: 6,   minSessions: 2, maxSessions: 3, minPlayRatio: 0.3, maxPlayRatio: 0.4 },
  { ageGroup: '9-12m', activityLevel: 'high',   minMinutes: 140, maxMinutes: 180, minKm: 6,   maxKm: 8,   minSessions: 2, maxSessions: 3, minPlayRatio: 0.3, maxPlayRatio: 0.4 },
  // 1–2 years
  { ageGroup: '1-2y', activityLevel: 'low',    minMinutes: 60,  maxMinutes: 90,  minKm: 2,   maxKm: 4,   minSessions: 1, maxSessions: 2, minPlayRatio: 0.25, maxPlayRatio: 0.3 },
  { ageGroup: '1-2y', activityLevel: 'medium', minMinutes: 90,  maxMinutes: 150, minKm: 4,   maxKm: 8,   minSessions: 1, maxSessions: 2, minPlayRatio: 0.25, maxPlayRatio: 0.3 },
  { ageGroup: '1-2y', activityLevel: 'high',   minMinutes: 150, maxMinutes: 210, minKm: 8,   maxKm: 12,  minSessions: 1, maxSessions: 2, minPlayRatio: 0.25, maxPlayRatio: 0.3 },
  // 2–7 years
  { ageGroup: '2-7y', activityLevel: 'low',    minMinutes: 60,  maxMinutes: 80,  minKm: 2,   maxKm: 3,   minSessions: 1, maxSessions: 2, minPlayRatio: 0.2, maxPlayRatio: 0.25 },
  { ageGroup: '2-7y', activityLevel: 'medium', minMinutes: 90,  maxMinutes: 140, minKm: 4,   maxKm: 8,   minSessions: 1, maxSessions: 2, minPlayRatio: 0.2, maxPlayRatio: 0.25 },
  { ageGroup: '2-7y', activityLevel: 'high',   minMinutes: 120, maxMinutes: 180, minKm: 6,   maxKm: 10,  minSessions: 1, maxSessions: 2, minPlayRatio: 0.2, maxPlayRatio: 0.25 },
  // 7–10 years
  { ageGroup: '7-10y', activityLevel: 'low',    minMinutes: 40,  maxMinutes: 60,  minKm: 1,   maxKm: 2,   minSessions: 1, maxSessions: 2, minPlayRatio: 0.2, maxPlayRatio: 0.25 },
  { ageGroup: '7-10y', activityLevel: 'medium', minMinutes: 60,  maxMinutes: 100, minKm: 2,   maxKm: 5,   minSessions: 1, maxSessions: 2, minPlayRatio: 0.2, maxPlayRatio: 0.25 },
  { ageGroup: '7-10y', activityLevel: 'high',   minMinutes: 90,  maxMinutes: 140, minKm: 4,   maxKm: 7,   minSessions: 1, maxSessions: 2, minPlayRatio: 0.2, maxPlayRatio: 0.25 },
  // 10+ years
  { ageGroup: '10+y', activityLevel: 'low',    minMinutes: 20,  maxMinutes: 40,  minKm: 0.5, maxKm: 1,   minSessions: 1, maxSessions: 2, minPlayRatio: 0.2, maxPlayRatio: 0.25 },
  { ageGroup: '10+y', activityLevel: 'medium', minMinutes: 40,  maxMinutes: 70,  minKm: 1,   maxKm: 3,   minSessions: 1, maxSessions: 2, minPlayRatio: 0.2, maxPlayRatio: 0.25 },
  { ageGroup: '10+y', activityLevel: 'high',   minMinutes: 60,  maxMinutes: 100, minKm: 2,   maxKm: 5,   minSessions: 1, maxSessions: 2, minPlayRatio: 0.2, maxPlayRatio: 0.25 },
]

// Breed → default activity level. Used only when the user hasn't set activityLevelOverride.
const BREED_LEVEL_MAP: Record<string, ActivityLevel> = {
  // Low-energy breeds
  'basset hound': 'low', 'bulldog': 'low', 'french bulldog': 'low',
  'chow chow': 'low', 'shih tzu': 'low', 'pug': 'low',
  'maltese': 'low', 'bichon frise': 'low', 'cavalier king charles spaniel': 'low',
  'boston terrier': 'low', 'great dane': 'low', 'mastiff': 'low',
  'saint bernard': 'low', 'bloodhound': 'low', 'chinese shar-pei': 'low',
  // Medium-energy breeds
  'labrador retriever': 'medium', 'golden retriever': 'medium',
  'german shepherd': 'medium', 'poodle': 'medium', 'beagle': 'medium',
  'dachshund': 'medium', 'rottweiler': 'medium', 'boxer': 'medium',
  'husky': 'medium', 'doberman': 'medium', 'cocker spaniel': 'medium',
  'schnauzer': 'medium', 'samoyed': 'medium', 'akita': 'medium',
  'alaskan malamute': 'medium',
  // High-energy breeds
  'border collie': 'high', 'belgian malinois': 'high', 'jack russell terrier': 'high',
  'australian shepherd': 'high', 'vizsla': 'high', 'weimaraner': 'high',
  'dalmatian': 'high', 'pointer': 'high', 'springer spaniel': 'high',
  'irish setter': 'high', 'siberian husky': 'high', 'whippet': 'high',
  'rat terrier': 'high', 'rhodesian ridgeback': 'high',
}

// Maps iOS ageGroup strings to norm table keys
const AGE_GROUP_ALIAS: Record<string, string> = {
  '2-3 months': '2-3m', '2_3_months': '2-3m', 'puppy_2_3': '2-3m',
  '4-6 months': '4-6m', '4_6_months': '4-6m', 'puppy_4_6': '4-6m',
  '6-9 months': '6-9m', '6_9_months': '6-9m', 'puppy_6_9': '6-9m',
  '9-12 months': '9-12m', '9_12_months': '9-12m', 'puppy_9_12': '9-12m',
  '1-2 years': '1-2y', '1_2_years': '1-2y', 'junior': '1-2y',
  '2-7 years': '2-7y', '2_7_years': '2-7y', 'adult': '2-7y',
  '7-10 years': '7-10y', '7_10_years': '7-10y', 'senior': '7-10y',
  '10+ years': '10+y', '10_plus_years': '10+y', 'elderly': '10+y',
}

export class ActivityNormService {
  /** Returns the activity norm for a dog. Never returns null — falls back to medium adult. */
  static getNorm(ageGroup: string, activityLevel: ActivityLevel): ActivityNorm {
    const normalizedAge   = AGE_GROUP_ALIAS[ageGroup] ?? ageGroup
    const found = NORM_TABLE.find(
      (n) => n.ageGroup === normalizedAge && n.activityLevel === activityLevel
    )
    return found ?? NORM_TABLE.find((n) => n.ageGroup === '2-7y' && n.activityLevel === 'medium')!
  }

  /** Infer activity level from breed name (lowercase). Returns undefined if breed is unknown. */
  static levelForBreed(breed: string | null | undefined): ActivityLevel | undefined {
    if (!breed) return undefined
    return BREED_LEVEL_MAP[breed.toLowerCase().trim()]
  }

  /** Resolve the effective activity level for a dog, respecting the override. */
  static resolveLevel(
    dogActivityLevel: string,
    activityLevelOverride?: string | null,
    breed?: string | null
  ): ActivityLevel {
    if (activityLevelOverride) return activityLevelOverride as ActivityLevel
    const mapped: ActivityLevel = (dogActivityLevel as ActivityLevel) ?? 'medium'
    return mapped
  }

  /** Split total walk minutes into individual sessions based on the norm. */
  static buildSessions(norm: ActivityNorm, targetMinutes: number): number[] {
    const count   = norm.minSessions
    const perSess = Math.round(targetMinutes / count)
    return Array(count).fill(perSess)
  }
}
