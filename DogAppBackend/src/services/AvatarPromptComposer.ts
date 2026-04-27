export interface DogVisualTraitsInput {
  breedGuessFromImage?: string | null
  confirmedBreed?: string | null
  coatColor?: string | null
  coatPattern?: string | null
  coatLength?: string | null
  coatTexture?: string | null
  earType?: string | null
  muzzleShape?: string | null
  noseColor?: string | null
  eyeColor?: string | null
  tailType?: string | null
  bodyShape?: string | null
  sizeClass?: string | null
  ageStage?: string | null
  distinctiveMarks?: string | null
  dogName?: string | null
}

export const AvatarPromptComposer = {

  buildPositivePrompt(traits: DogVisualTraitsInput): string {
    const breed = traits.confirmedBreed || traits.breedGuessFromImage || 'mixed breed dog'
    const coat = [
      traits.coatColor,
      traits.coatPattern,
      traits.coatLength,
      traits.coatTexture,
    ].filter(Boolean).join(', ')
    const ageStage = traits.ageStage || 'adult'
    const size = traits.sizeClass ? `${traits.sizeClass} sized` : ''
    const name = traits.dogName ? `named ${traits.dogName}` : ''

    return `
Create a realistic, warm, emotionally expressive app avatar portrait of a specific dog.
This must look like the owner's real individual dog — not a generic breed photo.

DOG DETAILS:
- Breed: ${breed} ${name}
- Coat: ${coat || 'natural coat'}
- Ears: ${traits.earType || 'natural'}
- Muzzle: ${traits.muzzleShape || 'natural muzzle'}
- Nose: ${traits.noseColor || 'natural nose color'}
- Eyes: ${traits.eyeColor || 'warm brown eyes'}, warm and soulful expression
- Tail: ${traits.tailType || 'natural tail'}
- Body: ${size} ${traits.bodyShape || 'well-proportioned body'}
- Age stage: ${ageStage}
${traits.distinctiveMarks ? `- Distinctive marks: ${traits.distinctiveMarks}` : ''}

STYLE REQUIREMENTS:
- Realistic photographic quality but warm and friendly
- Clean, neutral light background (soft off-white or warm cream)
- Soft diffused lighting, no harsh shadows
- Dog centered in frame, head and upper body visible (portrait crop)
- Warm, approachable, soulful expression looking slightly toward camera
- High detail on fur texture, eyes, and individual features
- Resolution: suitable for mobile app display (square format preferred)
- Slightly soft bokeh background to keep focus on the dog
- No accessories unless specified
- No text, watermarks, or overlays
- No other animals or people in frame
- No distracting background elements
`.trim()
  },

  buildNegativePrompt(): string {
    return [
      'wrong breed',
      'wrong coat color',
      'cartoonish',
      'anime style',
      'illustration',
      'extra limbs',
      'extra dogs',
      'distorted face',
      'distorted eyes',
      'human-like features',
      'text in image',
      'watermark',
      'dark background',
      'blurry',
      'low quality',
      'cropped head',
      'aggressive expression',
      'scary expression',
      'multiple animals',
    ].join(', ')
  },

  buildEvolutionPrompt(traits: DogVisualTraitsInput, newAgeStage: string, previousAvatarUrl?: string): string {
    const base = AvatarPromptComposer.buildPositivePrompt({ ...traits, ageStage: newAgeStage })
    const ageNote = getAgeEvolutionNote(newAgeStage)

    return `${base}

IMPORTANT — AGE EVOLUTION:
This is an evolved version of the same individual dog at a new life stage.
The dog must be CLEARLY recognizable as the same individual — same breed, coat color, markings, and facial features.
New age stage: ${newAgeStage}
${ageNote}
Preserve the dog's identity completely. Only evolve age-appropriate physical characteristics.
DO NOT change: coat color, breed type, distinctive marks, basic head shape.
${previousAvatarUrl ? 'Reference the existing avatar style for consistency.' : ''}
`.trim()
  },
}

function getAgeEvolutionNote(ageStage: string): string {
  const notes: Record<string, string> = {
    puppy:      'Puppy features: large paws relative to body, round face, bright curious eyes, fluffy puppy coat, slightly uncoordinated posture.',
    juvenile:   'Juvenile dog: gangly proportions, adult coat starting to come in, still youthful face, growing into paws.',
    youngDog:   'Young adult: adult body proportions mostly established, shiny coat, bright energetic eyes, athletic posture.',
    adult:      'Adult prime: fully developed, confident posture, well-proportioned, mature face with expressive eyes.',
    mature:     'Mature adult: slight thickening of muzzle, deeper eyes, calm confident posture, wisdom in expression.',
    senior:     'Senior dog: some gray around muzzle and eyes, deeper fur texture, gentler softer eyes, calm dignified expression.',
  }
  return notes[ageStage] || ''
}
