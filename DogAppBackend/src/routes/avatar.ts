import { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { requireAuth } from '../middleware/auth'
import { prisma } from '../lib/prisma'
import { AvatarStorageService } from '../lib/storage'
import { DogTraitExtractionService } from '../services/DogTraitExtractionService'
import { DogAvatarGenerationService } from '../services/DogAvatarGenerationService'
import { AvatarEvolutionService } from '../services/AvatarEvolutionService'
import { AvatarBehaviorService, DogStateInput } from '../services/AvatarBehaviorService'
import { Errors } from '../lib/errors'
import { config } from '../config'
import sharp from 'sharp'

// ─── Helpers ──────────────────────────────────────────────────────────────────

async function assertDogOwner(userId: string, dogId: string) {
  const dog = await prisma.dog.findFirst({ where: { id: dogId, userId, deletedAt: null } })
  if (!dog) throw Errors.notFound('Dog not found')
  return dog
}

async function getOrCreateAvatar(dogId: string, userId: string) {
  let avatar = await prisma.dogAvatar.findUnique({ where: { dogId } })
  if (!avatar) {
    avatar = await prisma.dogAvatar.create({
      data: { dogId, userId, maxRegenerations: config.avatar.maxRegenerations },
    })
  }
  return avatar
}

// ─── Routes ───────────────────────────────────────────────────────────────────

export async function avatarRoutes(app: FastifyInstance) {

  // POST /dogs/:dogId/avatar/photos — upload reference photos (multipart)
  app.post('/dogs/:dogId/avatar/photos', { preHandler: requireAuth }, async (req, reply) => {
    const { dogId } = req.params as { dogId: string }
    const dog = await assertDogOwner(req.user.userId, dogId)

    const uploadedUrls: string[] = []

    // @fastify/multipart must be registered on app
    const parts = (req as any).files()
    for await (const part of parts) {
      const allowed = ['image/jpeg', 'image/png', 'image/webp', 'image/heic']
      if (!allowed.includes(part.mimetype)) {
        throw Errors.badRequest('Only JPEG, PNG, WebP, and HEIC images are allowed')
      }

      const rawBuffer = await part.toBuffer()

      // Validate size (max 10MB raw)
      if (rawBuffer.length > 10 * 1024 * 1024) {
        throw Errors.badRequest('Photo too large. Maximum 10MB per photo.')
      }

      // Resize + compress with sharp
      let processed: Buffer
      try {
        processed = await sharp(rawBuffer)
          .resize({ width: 1024, height: 1024, fit: 'inside', withoutEnlargement: true })
          .jpeg({ quality: 85 })
          .toBuffer()
      } catch {
        processed = rawBuffer
      }

      const url = await AvatarStorageService.uploadBuffer(processed, 'reference-photos', 'jpg')
      uploadedUrls.push(url)

      if (uploadedUrls.length >= 3) break
    }

    if (!uploadedUrls.length) throw Errors.badRequest('No valid photos uploaded')

    // Store reference photo URLs on avatar record
    await prisma.$transaction(async (tx) => {
      let avatar = await tx.dogAvatar.findUnique({ where: { dogId } })
      if (!avatar) {
        avatar = await tx.dogAvatar.create({
          data: { dogId, userId: req.user.userId, referencePhotoUrls: uploadedUrls },
        })
      } else {
        await tx.dogAvatar.update({
          where: { dogId },
          data: { referencePhotoUrls: { set: uploadedUrls } },
        })
      }
    })

    return reply.code(200).send({ photoUrls: uploadedUrls, count: uploadedUrls.length })
  })

  // POST /dogs/:dogId/avatar/analyze — run trait extraction
  app.post('/dogs/:dogId/avatar/analyze', { preHandler: requireAuth }, async (req, reply) => {
    const { dogId } = req.params as { dogId: string }
    const dog = await assertDogOwner(req.user.userId, dogId)

    const avatar = await getOrCreateAvatar(dogId, req.user.userId)

    const traits = await DogTraitExtractionService.extractFromPhotos({
      photoUrls:         avatar.referencePhotoUrls,
      userProvidedBreed: dog.breed || undefined,
      coatColor:         dog.coatColor || undefined,
      ageGroup:          dog.ageGroup,
      sex:               dog.gender,
    })

    // Upsert visual traits
    const saved = await prisma.dogVisualTraits.upsert({
      where:  { dogId },
      create: {
        dogId,
        userProvidedBreed:   dog.breed,
        breedGuessFromImage: traits.breedGuessFromImage,
        coatColor:           traits.coatColor,
        coatPattern:         traits.coatPattern,
        coatLength:          traits.coatLength,
        coatTexture:         traits.coatTexture,
        earType:             traits.earType,
        muzzleShape:         traits.muzzleShape,
        noseColor:           traits.noseColor,
        eyeColor:            traits.eyeColor,
        tailType:            traits.tailType,
        bodyShape:           traits.bodyShape,
        sizeClass:           traits.sizeClass,
        ageStage:            traits.ageStage,
        distinctiveMarks:    traits.distinctiveMarks,
        confidenceScore:     traits.confidenceScore,
        warnings:            traits.warnings,
        rawAnalysisJson:     traits as any,
      },
      update: {
        breedGuessFromImage: traits.breedGuessFromImage,
        coatColor:           traits.coatColor,
        coatPattern:         traits.coatPattern,
        coatLength:          traits.coatLength,
        coatTexture:         traits.coatTexture,
        earType:             traits.earType,
        muzzleShape:         traits.muzzleShape,
        noseColor:           traits.noseColor,
        eyeColor:            traits.eyeColor,
        tailType:            traits.tailType,
        bodyShape:           traits.bodyShape,
        sizeClass:           traits.sizeClass,
        ageStage:            traits.ageStage,
        distinctiveMarks:    traits.distinctiveMarks,
        confidenceScore:     traits.confidenceScore,
        warnings:            traits.warnings,
        rawAnalysisJson:     traits as any,
        updatedAt:           new Date(),
      },
    })

    return reply.send({ traits: saved })
  })

  // POST /dogs/:dogId/avatar/generate — generate master avatar
  app.post('/dogs/:dogId/avatar/generate', { preHandler: requireAuth }, async (req, reply) => {
    const { dogId } = req.params as { dogId: string }
    const dog = await assertDogOwner(req.user.userId, dogId)

    const [avatar, visualTraits] = await Promise.all([
      getOrCreateAvatar(dogId, req.user.userId),
      prisma.dogVisualTraits.findUnique({ where: { dogId } }),
    ])

    // Create a generation job record
    const job = await prisma.dogAvatarGenerationJob.create({
      data: {
        dogId,
        userId:        req.user.userId,
        status:        'processing',
        inputPhotoUrls: avatar.referencePhotoUrls,
        promptVersion:  'v1',
      },
    })

    // Mark avatar as generating
    await prisma.dogAvatar.update({
      where: { dogId },
      data:  { generationStatus: 'generating' },
    })

    // Generate avatar asynchronously — we respond immediately then update
    // This keeps response fast even if generation takes 10+ seconds
    generateInBackground(dogId, req.user.userId, job.id, dog, avatar, visualTraits).catch(console.error)

    return reply.code(202).send({
      jobId:            job.id,
      status:           'processing',
      message:          'Avatar generation started. Poll GET /dogs/:dogId/avatar for status.',
    })
  })

  // POST /dogs/:dogId/avatar/regenerate — consume one regeneration credit
  app.post('/dogs/:dogId/avatar/regenerate', { preHandler: requireAuth }, async (req, reply) => {
    const { dogId } = req.params as { dogId: string }
    const dog = await assertDogOwner(req.user.userId, dogId)

    const avatar = await getOrCreateAvatar(dogId, req.user.userId)
    const remaining = avatar.maxRegenerations - avatar.regenerationCount
    if (remaining <= 0) {
      throw Errors.forbidden(`No regenerations remaining (used ${avatar.regenerationCount}/${avatar.maxRegenerations})`)
    }

    const visualTraits = await prisma.dogVisualTraits.findUnique({ where: { dogId } })

    // Optimistically increment — we'll decrement back if generation fails
    await prisma.dogAvatar.update({
      where: { dogId },
      data:  { regenerationCount: { increment: 1 }, generationStatus: 'generating' },
    })

    const job = await prisma.dogAvatarGenerationJob.create({
      data: {
        dogId,
        userId:         req.user.userId,
        status:         'processing',
        inputPhotoUrls: avatar.referencePhotoUrls,
        promptVersion:  'v1',
      },
    })

    generateInBackground(dogId, req.user.userId, job.id, dog, avatar, visualTraits, true).catch(console.error)

    return reply.send({
      jobId:             job.id,
      status:            'processing',
      regenerationsLeft: remaining - 1,
    })
  })

  // GET /dogs/:dogId/avatar — fetch current avatar metadata
  app.get('/dogs/:dogId/avatar', { preHandler: requireAuth }, async (req, reply) => {
    const { dogId } = req.params as { dogId: string }
    await assertDogOwner(req.user.userId, dogId)

    const [avatar, visualTraits] = await Promise.all([
      prisma.dogAvatar.findUnique({ where: { dogId } }),
      prisma.dogVisualTraits.findUnique({ where: { dogId } }),
    ])

    return reply.send({
      avatar:       avatar || null,
      visualTraits: visualTraits || null,
      regenerationsLeft: avatar
        ? Math.max(0, avatar.maxRegenerations - avatar.regenerationCount)
        : config.avatar.maxRegenerations,
    })
  })

  // PATCH /dogs/:dogId/avatar/state — update current avatar state
  app.patch('/dogs/:dogId/avatar/state', { preHandler: requireAuth }, async (req, reply) => {
    const { dogId } = req.params as { dogId: string }
    await assertDogOwner(req.user.userId, dogId)

    const StateBody = z.object({
      dogState: z.object({
        energyLevel:             z.number().min(0).max(1),
        hungerLevel:             z.number().min(0).max(1),
        satisfaction:            z.number().min(0).max(1),
        calmness:                z.number().min(0).max(1),
        focusOnOwner:            z.number().min(0).max(1),
        recentActivityCompleted: z.boolean(),
        missedActivitiesCount:   z.number().int(),
        recentTrainingSuccess:   z.boolean().nullable(),
        recentBehaviorIssues:    z.number().int(),
        streakActive:            z.boolean(),
      }),
    })

    const { dogState } = StateBody.parse(req.body)
    const result = AvatarBehaviorService.computeState(dogState as DogStateInput)

    await prisma.dogAvatarStateHistory.create({
      data: {
        dogId,
        avatarState:   result.state,
        triggerReason: result.stateReason,
      },
    })

    return reply.send(result)
  })

  // POST /dogs/:dogId/avatar/evolve — trigger age evolution check
  app.post('/dogs/:dogId/avatar/evolve', { preHandler: requireAuth }, async (req, reply) => {
    const { dogId } = req.params as { dogId: string }
    await assertDogOwner(req.user.userId, dogId)

    const evolved = await AvatarEvolutionService.evolve(prisma, dogId)
    return reply.send({ evolved, message: evolved ? 'Avatar evolved to new age stage' : 'No evolution needed' })
  })
}

// ─── Background generation helper ─────────────────────────────────────────────

async function generateInBackground(
  dogId: string,
  userId: string,
  jobId: string,
  dog: any,
  avatar: any,
  visualTraits: any,
  isRegeneration = false,
) {
  const traits: import('../services/AvatarPromptComposer').DogVisualTraitsInput = {
    confirmedBreed:      dog.breed || undefined,
    breedGuessFromImage: visualTraits?.breedGuessFromImage || undefined,
    coatColor:           visualTraits?.coatColor || dog.coatColor || undefined,
    coatPattern:         visualTraits?.coatPattern || undefined,
    coatLength:          visualTraits?.coatLength || undefined,
    coatTexture:         visualTraits?.coatTexture || undefined,
    earType:             visualTraits?.earType || undefined,
    muzzleShape:         visualTraits?.muzzleShape || undefined,
    noseColor:           visualTraits?.noseColor || undefined,
    eyeColor:            visualTraits?.eyeColor || undefined,
    tailType:            visualTraits?.tailType || undefined,
    bodyShape:           visualTraits?.bodyShape || undefined,
    sizeClass:           visualTraits?.sizeClass || dog.size || undefined,
    ageStage:            visualTraits?.ageStage || undefined,
    distinctiveMarks:    visualTraits?.distinctiveMarks || undefined,
    dogName:             dog.name,
  }

  try {
    const result = await DogAvatarGenerationService.generate(traits, avatar.referencePhotoUrls)

    await prisma.$transaction([
      prisma.dogAvatar.update({
        where: { dogId },
        data: {
          masterAvatarUrl:  result.avatarUrl,
          generationStatus: 'completed',
          provider:         result.provider,
          avatarVersion:    { increment: 1 },
          updatedAt:        new Date(),
        },
      }),
      prisma.dogAvatarGenerationJob.update({
        where: { id: jobId },
        data: {
          status:      'completed',
          outputUrl:   result.avatarUrl,
          provider:    result.provider,
          completedAt: new Date(),
        },
      }),
    ])

    // Also update photoUrl on Dog for easy access
    await prisma.dog.update({
      where: { id: dogId },
      data:  { photoUrl: result.avatarUrl },
    })

  } catch (err: any) {
    console.error(`[AvatarGen] Generation failed for dog ${dogId}:`, err?.message)

    await prisma.$transaction([
      prisma.dogAvatar.update({
        where: { dogId },
        data: {
          generationStatus: 'failed',
          // Roll back regeneration count if this was a regen
          ...(isRegeneration ? { regenerationCount: { decrement: 1 } } : {}),
        },
      }),
      prisma.dogAvatarGenerationJob.update({
        where: { id: jobId },
        data: {
          status:       'failed',
          errorMessage: err?.message || 'Unknown error',
          completedAt:  new Date(),
        },
      }),
    ])
  }
}
