import { useState, type FormEvent } from 'react'
import { Link, Navigate, useNavigate } from 'react-router-dom'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { ApiError } from '@/api/types'
import { recordError } from '@/diagnostics/diagnostics'
import { useAuth, useServices } from '@/app/app-context'

export function SignInPage() {
  const { session, setSession } = useAuth()
  const { auth } = useServices()
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  if (session) return <Navigate to="/items" replace />

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setError('')
    setBusy(true)
    try {
      setSession(await auth.signInWithPassword({ email, password }))
      navigate('/items', { replace: true })
    } catch (caught) {
      setError(caught instanceof ApiError ? caught.message : 'We could not sign you in. Please try again.')
      if (!(caught instanceof ApiError)) recordError('auth.signed_in')
    } finally { setBusy(false) }
  }

  return <main id="main-content" tabIndex={-1} className="grid min-h-screen place-items-center bg-muted/40 px-4 py-10">
    <div className="w-full max-w-md">
      <div className="mb-6 text-center"><div className="mx-auto mb-3 grid size-11 place-items-center rounded-xl bg-primary text-lg font-bold text-primary-foreground">K</div><p className="text-sm font-medium text-muted-foreground">Kankal workspace</p></div>
      <Card>
        <CardHeader className="space-y-2"><CardTitle role="heading" aria-level={1} className="text-2xl">Welcome back</CardTitle><CardDescription>Sign in to open your workspace.</CardDescription></CardHeader>
        <CardContent>
          {error && <Alert variant="destructive" className="mb-4" role="alert"><AlertTitle>Sign-in failed</AlertTitle><AlertDescription>{error}</AlertDescription></Alert>}
          <form onSubmit={submit} className="space-y-4">
            <div className="space-y-2"><Label htmlFor="password-email">Email address</Label><Input id="password-email" name="email" type="email" autoComplete="email" spellCheck={false} value={email} onChange={(event) => setEmail(event.target.value)} required /></div>
            <div className="space-y-2"><Label htmlFor="password">Password</Label><Input id="password" name="password" type="password" autoComplete="current-password" value={password} onChange={(event) => setPassword(event.target.value)} required /></div>
            <Button className="w-full" type="submit" disabled={busy}>{busy ? 'Signing in…' : 'Sign in'}</Button>
          </form>
        </CardContent>
      </Card>
      <p className="mt-5 text-center text-sm text-muted-foreground">Explore the <Link to="/ui" className="font-medium text-foreground underline underline-offset-4">UI showcase</Link></p>
    </div>
  </main>
}
