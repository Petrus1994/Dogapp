import { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { requireAuth } from '../middleware/auth'
import { DogService } from '../services/DogService'
import { prisma } from '../lib/prisma'

const CreateDogBody = z.object({
  name:           z.string().min(1).max(50),
  gender:         z.enum(['male', 'female']),
  ageGroup:       z.string(),
  birthDate:      z.string().datetime().optional(),
  breed:          z.string().optional(),
  isBreedUnknown: z.boolean().default(false),
  size:           z.enum(['small', 'medium', 'large']).optional(),
  activityLevel:  z.enum(['low', 'medium', 'high']),
  issues:         z.array(z.string()).default([]),
})

export async function dogRoutes(app: FastifyInstance) {
  const svc = new DogService(prisma)

  app.post('/dogs', { preHandler: requireAuth }, async (req, reply) => {
    const body = CreateDogBody.parse(req.body)
    const dog  = await svc.createDog(req.user.userId, {
      ...body,
      birthDate: body.birthDate ? new Date(body.birthDate) : undefined,
    })
    return reply.code(201).send(dog)
  })

  app.get('/dogs/active', { preHandler: requireAuth }, async (req) => {
    return svc.getActiveDog(req.user.userId)
  })

  app.patch('/dogs/:dogId', { preHandler: requireAuth }, async (req) => {
    const { dogId } = req.params as { dogId: string }
    const body = CreateDogBody.partial().parse(req.body)
    return svc.updateDog(req.user.userId, dogId, {
      ...body,
      birthDate: body.birthDate ? new Date(body.birthDate as any) : undefined,
    })
  })

  app.delete('/dogs/:dogId', { preHandler: requireAuth }, async (req, reply) => {
    const { dogId } = req.params as { dogId: string }
    await svc.deleteDog(req.user.userId, dogId)
    return reply.code(204).send()
  })
}
