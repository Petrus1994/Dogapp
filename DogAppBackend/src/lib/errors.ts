export class AppError extends Error {
  constructor(
    public readonly statusCode: number,
    public readonly code:       string,
    message:                    string,
  ) {
    super(message)
    this.name = 'AppError'
  }
}

export const Errors = {
  unauthorized:     () => new AppError(401, 'UNAUTHORIZED', 'Authentication required'),
  forbidden:        (msg = 'Access denied') => new AppError(403, 'FORBIDDEN', msg),
  notFound:         (what = 'Resource') => new AppError(404, 'NOT_FOUND', `${what} not found`),
  conflict:         (msg: string) => new AppError(409, 'CONFLICT', msg),
  badRequest:       (msg: string) => new AppError(400, 'BAD_REQUEST', msg),
  validation:       (msg: string) => new AppError(422, 'VALIDATION_ERROR', msg),
  rateLimited:      () => new AppError(429, 'RATE_LIMITED', 'Too many requests'),
  aiLimitReached:   () => new AppError(429, 'AI_LIMIT_REACHED', 'Daily AI limit reached — upgrade to premium for unlimited access'),
  internal:         (msg = 'Internal server error') => new AppError(500, 'INTERNAL', msg),
}
