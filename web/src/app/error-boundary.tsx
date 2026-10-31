import { Component, type ErrorInfo, type ReactNode } from 'react'
import { recordError } from '@/diagnostics/diagnostics'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'

type ErrorBoundaryProps = { children: ReactNode }
type ErrorBoundaryState = { hasError: boolean }

export class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  state: ErrorBoundaryState = { hasError: false }

  static getDerivedStateFromError(): ErrorBoundaryState {
    return { hasError: true }
  }

  componentDidCatch(_error: Error, _errorInfo: ErrorInfo): void {
    recordError('app.render_failed')
  }

  private retry = (): void => {
    this.setState({ hasError: false })
  }

  render() {
    if (!this.state.hasError) return this.props.children

    return (
      <main
        id="main-content"
        tabIndex={-1}
        className="grid min-h-screen place-items-center bg-background p-4"
      >
        <Card className="w-full max-w-md">
          <CardContent className="grid gap-4">
            <Alert variant="destructive">
              <AlertTitle>Something went wrong</AlertTitle>
              <AlertDescription>
                This screen could not be displayed. Try again to reopen it.
              </AlertDescription>
            </Alert>
            <Button onClick={this.retry}>Try again</Button>
          </CardContent>
        </Card>
      </main>
    )
  }
}
