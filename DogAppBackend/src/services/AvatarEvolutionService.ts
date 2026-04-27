import { PrismaClient } from '@prisma/client'
import { DogAvatarGenerationService } from './DogAvatarGenerationService'
import { AvatarPromptComposer } from './AvatarPromptComposer'
import { AvatarStorageService } from '../lib/storage'
import { getImageModel } from '../lib/gemini'
import { openai } from '../lib/openai'
import { config } from '../config'

export type AgeStage = 'puppy' | 'juvenile' | 'youngDog' | 'adult' | 'mature' | 'senior'

// Evolution schedule: maps age-in-months breakpoints to stage
const AGE_STAGE_BREAKPOINTS: Array<{ maxMonths: number; stage: AgeStage }> = [
  { maxMonths: 3,   stage: 'puppy'    },
  { maxMonths: 6,   stage: 'puppy'    },
  { maxMonths: 9,   stage: 'juvenile' },
  { maxMonths: 12,  stage: 'juvenile' },
  { maxMonths: 24,  stage: 'youngDog' },
  { maxMonths: 84,  stage: 'adult'    },
  { maxMonths: 120, stage: 'mature'   },
]

export const AvatarEvolutionService = {

  stageFromAgeMonths(months: number): AgeStage {
    for (const bp of AGE_STAGE_BREAKPOINTS) {
      if (months <= bp.maxMonths) return bp.stage
    }
    return 'senior'
  },

  needsEvolution(currentStage: AgeStage, newStage: AgeStage): boolean {
    const order: AgeStage[] = ['puppy', 'juvenile', 'youngDog', 'adult', 'mature', 'senior']
    return order.indexOf(newStage) > order.indexOf(currentStage)
  },

  async evolve(prisma: PrismaClient, dogId: string): Promise<boolean> {
    const dog = await prisma.dog.findUnique({
      where: { id: dogId },
      include: { avatar: true, visualTraits: true },
    })

    if (!dog || !dog.avatar || !dog.visualTraits) return false

    // Compute current age
    const birthDate = dog.birthDate
    if (!birthDate) return false
    const ageMonths = (Date.now() - birthDate.getTime()) / (1000 * 60 * 60 * 24 * 30.44)
    const newStage  = AvatarEvolutionService.stageFromAgeMonths(ageMonths)

    if (!AvatarEvolutionService.needsEvolution(dog.avatar.currentAgeStage as AgeStage, newStage)) {
      return false
    }

    // Generate evolved avatar
    try {
      const traits: import('./AvatarPromptComposer').DogVisualTraitsInput = {
        confirmedBreed:      dog.breed || undefined,
        breedGuessFromImage: dog.visualTraits.breedGuessFromImage || undefined,
        coatColor:           dog.visualTraits.coatColor || dog.coatColor || undefined,
        coatPattern:         dog.visualTraits.coatPattern || undefined,
        coatLength:          dog.visualTraits.coatLength || undefined,
        coatTexture:         dog.visualTraits.coatTexture || undefined,
        earType:             dog.visualTraits.earType || undefined,
        muzzleShape:         dog.visualTraits.muzzleShape || undefined,
        noseColor:           dog.visualTraits.noseColor || undefined,
        eyeColor:            dog.visualTraits.eyeColor || undefined,
        tailType:            dog.visualTraits.tailType || undefined,
        bodyShape:           dog.visualTraits.bodyShape || undefined,
        sizeClass:           dog.visualTraits.sizeClass || undefined,
        ageStage:            newStage,
        distinctiveMarks:    dog.visualTraits.distinctiveMarks || undefined,
        dogName:             dog.name,
      }

      const result = await DogAvatarGenerationService.generate(traits, dog.avatar.referencePhotoUrls)

      await prisma.dogAvatar.update({
        where: { dogId },
        data: {
          masterAvatarUrl:  result.avatarUrl,
          currentAgeStage:  newStage,
          avatarVersion:    { increment: 1 },
          generationStatus: 'completed',
          provider:         result.provider,
          updatedAt:        new Date(),
        },
      })

      return true
    } catch (err: any) {
      console.error('[Evolution] Failed to evolve avatar:', err?.message)
      return false
    }
  },
}
