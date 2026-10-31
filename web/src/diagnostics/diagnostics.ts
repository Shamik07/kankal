export type DiagnosticEvent =
  | 'auth.code_requested'
  | 'auth.signed_in'
  | 'auth.signed_out'
  | 'items.load'
  | 'items.created'
  | 'items.updated'
  | 'items.deleted'
  | 'app.render_failed'

const events = new Set<DiagnosticEvent>([
  'auth.code_requested',
  'auth.signed_in',
  'auth.signed_out',
  'items.load',
  'items.created',
  'items.updated',
  'items.deleted',
  'app.render_failed',
])

/** Records fixed event names only; callers cannot attach user supplied details. */
export function record(event: DiagnosticEvent): void {
  if (events.has(event)) console.info(`[kankal] ${event}`)
}

/** Records an unexpected failure's fixed operation name without its error details. */
export function recordError(event: DiagnosticEvent): void {
  if (events.has(event)) console.info(`[kankal] ${event}.error`)
}
