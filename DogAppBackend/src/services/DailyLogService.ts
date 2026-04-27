import { PrismaClient } from '@prisma/client'
import PgBoss from 'pg-boss'
import { Jobs } from '../lib/jobs'
import { todayDate } from '../utils/dates'

export interface LogWalkInput {
  loggedAt?:       Date
  durationMinutes: number
  distanceKm?:     number
  walkQuality?:    string
  stepCount?:      number
  notes?:          string
}

export interface LogFeedingInput {
  loggedAt?:      Date
  foodType?:      string
  feedingNumber?: number
  durationMin?:   number
  notes?:         string
}

export interface LogPlayInput {
  loggedAt?:      Date
  durationMinutes: number
  playActivity?:  string
  notes?:         string
}

export interface LogTrainingInput {
  loggedAt?:       Date
  durationMinutes: number
  notes?:          string
}

export interface LogToiletInput {
  occurredAt:                 Date
  outcome:                    string
  minutesAfterLastFeeding?:   number
  minutesAfterLastSleep?:     number
  notes?:                     string
}

export interface LogBehaviorInput {
  occurredAt:   Date
  activityType?: string
  issues:        string[]
  notes?:        string
}

export class DailyLogService {
  constructor(private db: PrismaClient, private boss: PgBoss) {}

  async logWalk(dogId: string, input: LogWalkInput) {
    const dailyLog = await this.getOrCreateDailyLog(dogId)
    const walk = await this.db.walkLog.create({
      data: {
        dailyLogId:  dailyLog.id,
        dogId,
        loggedAt:    input.loggedAt ?? new Date(),
        durationMin: input.durationMinutes,
        distanceKm:  input.distanceKm,
        walkQuality: input.walkQuality,
        stepCount:   input.stepCount,
        notes:       input.notes ?? '',
      },
    })
    await this.postLogJobs(dogId, 'walk', walk.id, input.notes)
    return walk
  }

  async logFeeding(dogId: string, input: LogFeedingInput) {
    const dailyLog = await this.getOrCreateDailyLog(dogId)
    const feeding = await this.db.feedingLog.create({
      data: {
        dailyLogId:    dailyLog.id,
        dogId,
        loggedAt:      input.loggedAt ?? new Date(),
        foodType:      input.foodType,
        feedingNumber: input.feedingNumber,
        durationMin:   input.durationMin,
        notes:         input.notes ?? '',
      },
    })
    await this.postLogJobs(dogId, 'feeding', feeding.id, input.notes)
    return feeding
  }

  async logPlay(dogId: string, input: LogPlayInput) {
    const dailyLog = await this.getOrCreateDailyLog(dogId)
    const play = await this.db.playLog.create({
      data: {
        dailyLogId:   dailyLog.id,
        dogId,
        loggedAt:     input.loggedAt ?? new Date(),
        durationMin:  input.durationMinutes,
        playActivity: input.playActivity,
        notes:        input.notes ?? '',
      },
    })
    await this.postLogJobs(dogId, 'play', play.id, input.notes)
    return play
  }

  async logTraining(dogId: string, input: LogTrainingInput) {
    const dailyLog = await this.getOrCreateDailyLog(dogId)
    const session = await this.db.trainingSessionLog.create({
      data: {
        dailyLogId:  dailyLog.id,
        dogId,
        loggedAt:    input.loggedAt ?? new Date(),
        durationMin: input.durationMinutes,
        notes:       input.notes ?? '',
      },
    })
    await this.postLogJobs(dogId, 'training', session.id, input.notes)
    return session
  }

  async logToilet(dogId: string, input: LogToiletInput) {
    const dailyLog = await this.getOrCreateDailyLog(dogId)
    const event = await this.db.toiletEvent.create({
      data: {
        dogId,
        dailyLogId:               dailyLog.id,
        occurredAt:               input.occurredAt,
        outcome:                  input.outcome,
        minutesAfterLastFeeding:  input.minutesAfterLastFeeding,
        minutesAfterLastSleep:    input.minutesAfterLastSleep,
        notes:                    input.notes ?? '',
      },
    })
    // Update adaptive pattern learning
    await this.boss.send(Jobs.SCORES_RECALCULATE, { dogId })
    return event
  }

  async logBehavior(dogId: string, input: LogBehaviorInput) {
    const dailyLog = await this.getOrCreateDailyLog(dogId)
    const event = await this.db.behaviorEvent.create({
      data: {
        dogId,
        dailyLogId:   dailyLog.id,
        activityType: input.activityType,
        notes:        input.notes ?? '',
        occurredAt:   input.occurredAt,
        issues: {
          createMany: {
            data: input.issues.map((issue) => ({ issue })),
          },
        },
      },
      include: { issues: true },
    })
    await this.boss.send(Jobs.SCORES_RECALCULATE, { dogId })
    return event
  }

  async getTodayLogs(dogId: string) {
    const today = todayDate()
    const dailyLog = await this.db.dailyLog.findUnique({
      where: { dogId_logDate: { dogId, logDate: today } },
      include: {
        feedingLogs:    true,
        walkLogs:       true,
        playLogs:       true,
        trainingLogs:   true,
        toiletEvents:   true,
        behaviorEvents: { include: { issues: true } },
      },
    })
    return dailyLog ?? { date: today, walks: [], feedings: [], plays: [], trainingSessions: [], toiletEvents: [], behaviorEvents: [] }
  }

  async getLogsForRange(dogId: string, from: Date, to: Date) {
    const dailyLogs = await this.db.dailyLog.findMany({
      where: {
        dogId,
        logDate: { gte: from, lte: to },
      },
      include: {
        feedingLogs:    true,
        walkLogs:       true,
        playLogs:       true,
        trainingLogs:   true,
        toiletEvents:   true,
        behaviorEvents: { include: { issues: true } },
      },
      orderBy: { logDate: 'asc' },
    })
    return dailyLogs
  }

  private async getOrCreateDailyLog(dogId: string) {
    const today = todayDate()
    return this.db.dailyLog.upsert({
      where:  { dogId_logDate: { dogId, logDate: today } },
      create: { dogId, logDate: today },
      update: {},
    })
  }

  private async postLogJobs(dogId: string, sourceType: string, sourceId: string, notes?: string) {
    const work: Promise<any>[] = [
      this.boss.send(Jobs.MEMORY_REFRESH, { dogId }, { singletonKey: `memory:${dogId}` }),
    ]
    if (notes?.trim()) {
      work.push(
        this.db.userNote.create({
          data: { dogId, sourceType, sourceId, rawText: notes },
        }).then((note) =>
          this.boss.send(Jobs.NOTE_EXTRACT, { noteId: note.id, dogId })
        )
      )
    }
    await Promise.all(work)
  }
}
