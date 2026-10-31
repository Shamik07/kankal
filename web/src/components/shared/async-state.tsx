import { AlertCircle, Inbox, LoaderCircle } from 'lucide-react'

import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import { Button } from '@/components/ui/button'

type LoadingStateProps = {
  label?: string
}

export function LoadingState({ label = 'Loading' }: LoadingStateProps) {
  return (
    <div className="flex min-h-40 flex-col items-center justify-center gap-3 rounded-xl border border-dashed bg-card px-6 py-10 text-center" role="status" aria-live="polite">
      <LoaderCircle className="size-5 animate-spin text-muted-foreground" aria-hidden="true" />
      <span className="text-sm font-medium text-muted-foreground">{label}</span>
    </div>
  )
}

type EmptyStateProps = {
  title: string
  description: string
  action?: { label: string; onClick: () => void }
}

export function EmptyState({ title, description, action }: EmptyStateProps) {
  return (
    <div className="flex min-h-52 flex-col items-center justify-center rounded-xl border border-dashed bg-card px-6 py-10 text-center">
      <span className="mb-4 flex size-11 items-center justify-center rounded-full bg-muted text-muted-foreground">
        <Inbox className="size-5" aria-hidden="true" />
      </span>
      <h3 className="text-sm font-semibold">{title}</h3>
      <p className="mt-1 max-w-sm text-sm leading-6 text-muted-foreground">{description}</p>
      {action && <Button className="mt-5" size="sm" onClick={action.onClick}>{action.label}</Button>}
    </div>
  )
}

type ErrorStateProps = {
  title?: string
  description: string
  onRetry?: () => void
}

export function ErrorState({ title = 'Something went wrong', description, onRetry }: ErrorStateProps) {
  return (
    <Alert variant="destructive" role="alert">
      <AlertCircle className="size-4" aria-hidden="true" />
      <AlertTitle>{title}</AlertTitle>
      <AlertDescription className="flex flex-wrap items-center justify-between gap-3">
        <span>{description}</span>
        {onRetry && <Button variant="outline" size="sm" onClick={onRetry}>Try again</Button>}
      </AlertDescription>
    </Alert>
  )
}
