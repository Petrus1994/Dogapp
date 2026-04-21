import { PrismaClient } from '@prisma/client'
import OpenAI from 'openai'
import { z } from 'zod'
import { Models } from '../lib/openai'
import { Errors } from '../lib/errors'
import { logger } from '../lib/logger'

const PlanOutputSchema = z.object({
  title:       z.string(),
  planType:    z.string(),
  goal:        z.string(),
  weeklyFocus: z.string(),
  tips:        z.array(z.string()).max(5),
  tasks: z.array(z.object({
    title:           z.string(),
    description:     z.string(),
    category:        z.string(),
    difficulty:      z.number().int().min(1).max(5),
    expectedOutcome: z.string(),
    scheduledDay:    z.number().int().min(1).max(7),
  })).max(20),
})

export class PlanService {
  constructor(private db: PrismaClient, private openai: OpenAI) {}

  async generatePlan(userId: string, dogId: string | null) {
    let dogContext = ''
    if (dogId) {
      const dog = await this.db.dog.findFirst({
        where:   { id: dogId, userId },
        include: { issues: true },
      })
      if (!dog) throw Errors.notFound('Dog')
      dogContext = `Dog: ${dog.name}, ${dog.ageGroup}, ${dog.breed ?? 'mixed'}, ${dog.activityLevel} energy, issues: ${dog.issues.map((i) => i.issue).join(', ') || 'none'}`
    }

    const response = await this.openai.chat.completions.create({
      model:           Models.plan,
      temperature:     0.4,
      max_tokens:      2048,
      response_format: { type: 'json_object' },
      messages: [
        {
          role: 'system',
          content: `You are a certified dog trainer. Generate a 7-day personalized training plan.
Return JSON with: title, planType (puppyPlan|adultDogCorrectionPlan|preDogPreparationPlan|breedPreparationPlan), goal, weeklyFocus, tips (array of 3-5 strings), tasks (array with title, description, category, difficulty 1-5, expectedOutcome, scheduledDay 1-7).
Plan must be practical, specific, and tailored to the dog's profile.`,
        },
        { role: 'user', content: dogContext || 'Generate a general dog preparation plan for a new dog owner.' },
      ],
    })

    const raw       = response.choices[0]?.message?.content ?? '{}'
    const parsed    = JSON.parse(raw)
    const validated = PlanOutputSchema.parse(parsed)

    const plan = await this.db.trainingPlan.create({
      data: {
        userId,
        dogId,
        title:       validated.title,
        planType:    validated.planType,
        goal:        validated.goal,
        weeklyFocus: validated.weeklyFocus,
        tips:        validated.tips,
        startDate:   new Date(),
        tasks: {
          createMany: {
            data: validated.tasks.map((t) => ({
              title:           t.title,
              description:     t.description,
              category:        t.category,
              difficulty:      t.difficulty,
              expectedOutcome: t.expectedOutcome,
              scheduledDay:    t.scheduledDay,
            })),
          },
        },
      },
      include: { tasks: true },
    })

    logger.info({ action: 'plan_generated', userId, dogId, planId: plan.id })
    return plan
  }

  async getActivePlan(userId: string, dogId?: string) {
    return this.db.trainingPlan.findFirst({
      where:   { userId, dogId: dogId ?? undefined, isActive: true },
      orderBy: { createdAt: 'desc' },
      include: { tasks: true },
    })
  }

  async updateTaskStatus(userId: string, taskId: string, status: string, notes?: string) {
    const task = await this.db.trainingTask.findFirst({
      where:   { id: taskId },
      include: { plan: true },
    })
    if (!task || task.plan.userId !== userId) throw Errors.notFound('Task')

    return this.db.trainingTask.update({
      where: { id: taskId },
      data:  { status, notes: notes ?? task.notes },
    })
  }

  async submitFeedback(userId: string, dogId: string | null, taskId: string, input: {
    result:          string
    timingNote?:     string
    situationNote?:  string
    dogBehaviorNote?: string
    freeText?:       string
  }) {
    const task = await this.db.trainingTask.findFirst({
      where:   { id: taskId },
      include: { plan: true },
    })
    if (!task || task.plan.userId !== userId) throw Errors.notFound('Task')

    const feedback = await this.db.taskFeedback.create({
      data: { taskId, dogId, ...input },
    })

    // Update task status to match feedback
    await this.db.trainingTask.update({
      where: { id: taskId },
      data:  { status: input.result },
    })

    return feedback
  }
}
