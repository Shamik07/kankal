import { useState } from 'react'
import { ArrowUpRight, Check, CircleHelp, Plus } from 'lucide-react'

import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Dialog, DialogClose, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { EmptyState, ErrorState, LoadingState } from '@/components/shared/async-state'

export function UiShowcase() {
  const [feedback, setFeedback] = useState('')
  const [retryAttempted, setRetryAttempted] = useState(false)

  function showDemoFeedback(action: 'create' | 'save') {
    setFeedback(
      action === 'create'
        ? 'Demo only: workspace creation is not connected, so nothing was created.'
        : 'Preview only: these details were not submitted or saved.',
    )
  }

  return (
    <main id="main-content" tabIndex={-1} className="min-h-screen bg-background text-foreground">
      <div className="mx-auto max-w-6xl px-5 py-10 sm:px-8 sm:py-14">
        <header className="flex flex-col gap-8 border-b pb-8 sm:flex-row sm:items-end sm:justify-between">
          <div className="max-w-2xl">
            <p className="mb-3 text-sm font-medium text-muted-foreground">Kankal · Web starter</p>
            <h1 className="text-3xl font-semibold tracking-[-0.03em] sm:text-4xl">A calmer starting point.</h1>
            <p className="mt-3 max-w-xl text-base leading-7 text-muted-foreground">A small set of accessible interface pieces for building useful product screens with a consistent feel.</p>
          </div>
          <Button className="w-fit" onClick={() => showDemoFeedback('create')}>
            <Plus aria-hidden="true" />
            Create workspace
          </Button>
        </header>

        <div className="grid gap-12 py-9 lg:grid-cols-[minmax(0,1fr)_minmax(17rem,0.72fr)] lg:gap-16">
          <section aria-labelledby="form-heading">
            <div className="mb-6">
              <h2 id="form-heading" className="text-lg font-semibold tracking-tight">A clear, familiar form</h2>
              <p className="mt-1 text-sm text-muted-foreground">Labels stay visible and errors point toward a next step.</p>
            </div>
            <Card className="max-w-xl">
              <CardHeader className="border-b">
                <CardTitle>Workspace details</CardTitle>
                <CardDescription>Choose a name your team will recognize.</CardDescription>
              </CardHeader>
              <CardContent className="space-y-5">
                <div className="space-y-2">
                  <Label htmlFor="workspace-name">Workspace name</Label>
                  <Input id="workspace-name" placeholder="For example, Northstar Studio" />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="workspace-email">Your email</Label>
                  <Input id="workspace-email" type="email" placeholder="name@company.com" />
                  <p className="text-xs leading-5 text-muted-foreground">Preview only. This email is not collected or used to sign in.</p>
                </div>
                <div className="flex flex-wrap items-center gap-3 pt-1">
                  <Button onClick={() => showDemoFeedback('save')}>Preview save action</Button>
                  <Dialog>
                    <DialogTrigger asChild><Button variant="outline"><CircleHelp aria-hidden="true" />What happens next?</Button></DialogTrigger>
                    <DialogContent>
                      <DialogHeader>
                        <DialogTitle>Your workspace is ready to shape</DialogTitle>
                        <DialogDescription>These controls are visual examples only. They do not submit or save values. Connect them to your app's data service when you are ready.</DialogDescription>
                      </DialogHeader>
                      <DialogFooter><DialogClose asChild><Button variant="outline">Got it</Button></DialogClose></DialogFooter>
                    </DialogContent>
                  </Dialog>
                </div>
                {feedback && <Alert role="status"><AlertDescription>{feedback}</AlertDescription></Alert>}
              </CardContent>
            </Card>
          </section>

          <section aria-labelledby="states-heading">
            <div className="mb-6">
              <h2 id="states-heading" className="text-lg font-semibold tracking-tight">Helpful feedback</h2>
              <p className="mt-1 text-sm text-muted-foreground">Keep people oriented through every step.</p>
            </div>
            <div className="space-y-3">
              <Alert>
                <Check aria-hidden="true" />
                <AlertTitle>Success state preview</AlertTitle>
                <AlertDescription>Use this pattern after a real action completes.</AlertDescription>
              </Alert>
              {retryAttempted ? (
                <Alert role="status">
                  <AlertTitle>Retry interaction previewed</AlertTitle>
                  <AlertDescription>No items were loaded because this showcase is not connected to an item service.</AlertDescription>
                </Alert>
              ) : (
                <ErrorState title="Error state preview" description="No item service is connected in this showcase." onRetry={() => setRetryAttempted(true)} />
              )}
            </div>
            <div className="mt-8">
              <Tabs defaultValue="empty">
                <TabsList aria-label="Preview feedback states">
                  <TabsTrigger value="empty">Empty</TabsTrigger>
                  <TabsTrigger value="loading">Loading</TabsTrigger>
                </TabsList>
                <TabsContent value="empty" className="pt-3">
                  <EmptyState title="Nothing here yet" description="This preview shows where items can appear after you connect your data." action={{ label: 'Preview create action', onClick: () => showDemoFeedback('create') }} />
                </TabsContent>
                <TabsContent value="loading" className="pt-3"><LoadingState label="Loading your items" /></TabsContent>
              </Tabs>
            </div>
          </section>
        </div>

        <footer className="flex flex-col gap-3 border-t pt-5 text-sm text-muted-foreground sm:flex-row sm:items-center sm:justify-between">
          <span>Built for real flows, ready for your product.</span>
          <a className="inline-flex w-fit items-center gap-1 font-medium text-foreground underline-offset-4 hover:underline" href="https://ui.shadcn.com/" target="_blank" rel="noreferrer">Explore shadcn/ui <ArrowUpRight className="size-3.5" aria-hidden="true" /></a>
        </footer>
      </div>
    </main>
  )
}

export default UiShowcase
