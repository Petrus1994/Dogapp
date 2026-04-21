import { PrismaClient } from '@prisma/client'
import { Errors } from '../lib/errors'

export interface CreateDogInput {
  name:                  string
  gender:                string
  ageGroup:              string
  birthDate?:            Date
  breed?:                string
  isBreedUnknown:        boolean
  size?:                 string
  activityLevel:         string
  activityLevelOverride?: string
  coatColor?:            string
  issues:                string[]
}

export class DogService {
  constructor(private db: PrismaClient) {}

  async createDog(userId: string, input: CreateDogInput) {
    // Deactivate any previous active dog
    await this.db.dog.updateMany({
      where: { userId, isActive: true },
      data:  { isActive: false },
    })

    const dog = await this.db.dog.create({
      data: {
        userId,
        name:                  input.name,
        gender:                input.gender,
        ageGroup:              input.ageGroup,
        birthDate:             input.birthDate,
        breed:                 input.breed,
        isBreedUnknown:        input.isBreedUnknown,
        size:                  input.size,
        activityLevel:         input.activityLevel,
        activityLevelOverride: input.activityLevelOverride,
        coatColor:             input.coatColor,
        issues: {
          createMany: {
            data: input.issues.map((issue) => ({ issue })),
          },
        },
      },
      include: { issues: true },
    })

    // Bootstrap memory and adaptive pattern
    await this.db.$transaction([
      this.db.dogMemory.create({ data: { dogId: dog.id } }),
      this.db.adaptivePattern.create({ data: { dogId: dog.id } }),
      ...(['foodBehavior', 'activityExcitement', 'ownerContact', 'socialization'] as const).map(
        (dimension) =>
          this.db.behaviorDimension.create({ data: { dogId: dog.id, dimension } })
      ),
    ])

    return dog
  }

  async getActiveDog(userId: string) {
    const dog = await this.db.dog.findFirst({
      where:   { userId, isActive: true, deletedAt: null },
      include: { issues: true, memory: true, behaviorDimensions: true },
    })
    if (!dog) throw Errors.notFound('Dog profile')
    return dog
  }

  async updateDog(userId: string, dogId: string, input: Partial<CreateDogInput>) {
    await this.assertOwnership(userId, dogId)

    const { issues, ...fields } = input

    return this.db.$transaction(async (tx) => {
      if (issues !== undefined) {
        await tx.dogIssue.deleteMany({ where: { dogId } })
        await tx.dogIssue.createMany({
          data: issues.map((issue) => ({ dogId, issue })),
        })
      }
      return tx.dog.update({
        where:   { id: dogId },
        data:    fields,
        include: { issues: true },
      })
    })
  }

  async deleteDog(userId: string, dogId: string) {
    await this.assertOwnership(userId, dogId)
    await this.db.dog.update({
      where: { id: dogId },
      data:  { deletedAt: new Date(), isActive: false },
    })
  }

  async assertOwnership(userId: string, dogId: string) {
    const dog = await this.db.dog.findFirst({ where: { id: dogId, userId, deletedAt: null } })
    if (!dog) throw Errors.notFound('Dog')
    return dog
  }
}
