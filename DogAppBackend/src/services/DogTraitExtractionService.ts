import { getVisionModel } from '../lib/gemini'
import { config } from '../config'

export interface ExtractedDogTraits {
  breedGuessFromImage?: string
  coatColor?: string
  coatPattern?: string
  coatLength?: string
  coatTexture?: string
  earType?: string
  muzzleShape?: string
  noseColor?: string
  eyeColor?: string
  tailType?: string
  bodyShape?: string
  sizeClass?: string
  ageStage?: string
  distinctiveMarks?: string
  confidenceScore: number
  warnings: string[]
}

export const DogTraitExtractionService = {

  async extractFromPhotos(params: {
    photoUrls: string[]
    userProvidedBreed?: string
    coatColor?: string
    ageGroup?: string
    sex?: string
    notes?: string
  }): Promise<ExtractedDogTraits> {

    if (!params.photoUrls.length) {
      return buildFallback(params.userProvidedBreed, params.coatColor, params.ageGroup)
    }

    // Fetch photos and convert to base64 for Gemini
    const imageParts = await Promise.allSettled(
      params.photoUrls.slice(0, 3).map(url => fetchImagePart(url))
    )
    const validParts = imageParts
      .filter((r): r is PromiseFulfilledResult<any> => r.status === 'fulfilled')
      .map(r => r.value)

    if (!validParts.length) {
      return buildFallback(params.userProvidedBreed, params.coatColor, params.ageGroup)
    }

    const prompt = buildExtractionPrompt(params)

    try {
      const model = getVisionModel()
      const result = await model.generateContent([prompt, ...validParts])
      const text = result.response.text()
      return parseExtractionResponse(text, params)
    } catch (err: any) {
      console.warn('[TraitExtraction] Gemini vision failed:', err?.message)
      return buildFallback(params.userProvidedBreed, params.coatColor, params.ageGroup)
    }
  },
}

function buildExtractionPrompt(params: {
  userProvidedBreed?: string
  coatColor?: string
  ageGroup?: string
  sex?: string
  notes?: string
}): string {
  return `
Analyze the dog photos provided and extract visual traits for avatar generation.
User-provided info: Breed: ${params.userProvidedBreed || 'unknown'}, Coat color: ${params.coatColor || 'unknown'}, Age group: ${params.ageGroup || 'unknown'}, Sex: ${params.sex || 'unknown'}.
${params.notes ? `Owner notes: ${params.notes}` : ''}

If user-provided breed differs from what you see in the photo, note it as a warning but keep both.

Respond ONLY with valid JSON in this exact structure:
{
  "breedGuessFromImage": "string or null",
  "coatColor": "string describing exact colors",
  "coatPattern": "solid|bicolor|tricolor|merle|brindle|spotted|ticked or null",
  "coatLength": "short|medium|long|double or null",
  "coatTexture": "smooth|wavy|curly|wiry|fluffy or null",
  "earType": "floppy|erect|semi-erect|rose|button or null",
  "muzzleShape": "long|medium|short|flat or null",
  "noseColor": "black|brown|pink|liver|blue or null",
  "eyeColor": "brown|amber|blue|green|hazel|heterochromia or null",
  "tailType": "long|medium|short|docked|curled|plumed or null",
  "bodyShape": "slender|athletic|stocky|compact or null",
  "sizeClass": "toy|small|medium|large|giant or null",
  "ageStage": "puppy|juvenile|youngDog|adult|mature|senior",
  "distinctiveMarks": "describe any unique marks, white patches, spots, etc. or null",
  "confidenceScore": 0.0-1.0,
  "warnings": ["any warnings about photo quality, breed mismatch, multiple dogs, etc."]
}
`.trim()
}

async function fetchImagePart(url: string) {
  const res = await fetch(url)
  if (!res.ok) throw new Error(`Failed to fetch image: ${url}`)
  const buffer = await res.arrayBuffer()
  const contentType = res.headers.get('content-type') || 'image/jpeg'
  return {
    inlineData: {
      data:     Buffer.from(buffer).toString('base64'),
      mimeType: contentType,
    },
  }
}

function parseExtractionResponse(text: string, params: { userProvidedBreed?: string; coatColor?: string; ageGroup?: string }): ExtractedDogTraits {
  try {
    const jsonMatch = text.match(/\{[\s\S]*\}/)
    if (!jsonMatch) throw new Error('No JSON found')
    const parsed = JSON.parse(jsonMatch[0])
    return {
      breedGuessFromImage: parsed.breedGuessFromImage || undefined,
      coatColor:           parsed.coatColor || params.coatColor || undefined,
      coatPattern:         parsed.coatPattern || undefined,
      coatLength:          parsed.coatLength || undefined,
      coatTexture:         parsed.coatTexture || undefined,
      earType:             parsed.earType || undefined,
      muzzleShape:         parsed.muzzleShape || undefined,
      noseColor:           parsed.noseColor || undefined,
      eyeColor:            parsed.eyeColor || undefined,
      tailType:            parsed.tailType || undefined,
      bodyShape:           parsed.bodyShape || undefined,
      sizeClass:           parsed.sizeClass || undefined,
      ageStage:            parsed.ageStage || ageGroupToStage(params.ageGroup),
      distinctiveMarks:    parsed.distinctiveMarks || undefined,
      confidenceScore:     typeof parsed.confidenceScore === 'number' ? parsed.confidenceScore : 0.6,
      warnings:            Array.isArray(parsed.warnings) ? parsed.warnings : [],
    }
  } catch {
    return buildFallback(params.userProvidedBreed, params.coatColor, params.ageGroup)
  }
}

function buildFallback(breed?: string, coatColor?: string, ageGroup?: string): ExtractedDogTraits {
  return {
    breedGuessFromImage: breed,
    coatColor:           coatColor || 'mixed',
    ageStage:            ageGroupToStage(ageGroup),
    confidenceScore:     0.3,
    warnings:            ['No photo analysis — using profile data only'],
  }
}

function ageGroupToStage(ageGroup?: string): string {
  const map: Record<string, string> = {
    'under_2_months': 'puppy',
    '2_3_months':     'puppy',
    '3_5_months':     'puppy',
    '6_8_months':     'juvenile',
    '8_12_months':    'youngDog',
    '1_3_years':      'adult',
    '3_7_years':      'mature',
    'over_7_years':   'senior',
    'over_1_year':    'adult',
  }
  return map[ageGroup || ''] || 'adult'
}
