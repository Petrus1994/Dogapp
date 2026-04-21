import pino from 'pino'
import { config } from '../config'

export const logger = pino({
  level: config.server.logLevel,
  base:  { service: 'pawcoach-api', env: config.server.nodeEnv },
  redact: [
    'req.headers.authorization',
    'req.headers.cookie',
    '*.password',
    '*.passwordHash',
    '*.token',
    '*.refreshToken',
    '*.apiKey',
  ],
  transport: config.server.nodeEnv === 'development'
    ? { target: 'pino-pretty', options: { colorize: true } }
    : undefined,
})

export type Logger = typeof logger
