import { useEffect, useState, type ReactNode } from 'react'
import { BrowserRouter, Navigate, Route, Routes, Link, Outlet, useNavigate } from 'react-router-dom'
import type { AppServices } from './app-context'
import { ApiError, type Session } from '@/api/types'
import { recordError } from '@/diagnostics/diagnostics'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { LoadingState } from '@/components/shared/async-state'
import { AuthContext, ServicesContext, useAuth, useServices } from './app-context'
import { SignInPage } from '@/features/auth/sign-in-page'
import { ItemsPage } from '@/features/items/items-page'
import { UiShowcase } from '@/components/showcase/ui-showcase'

function AppFrame() {
  const { session, setSession } = useAuth()
  const { auth } = useServices()
  const navigate = useNavigate()
  const [signingOut, setSigningOut] = useState(false)
  const [signOutError, setSignOutError] = useState('')

  async function signOut() {
    setSigningOut(true)
    setSignOutError('')
    try {
      await auth.signOut()
      setSession(null)
      navigate('/sign-in', { replace: true })
    } catch (error) {
      if (error instanceof ApiError && error.code === 'AUTH_REQUIRED') {
        setSession(null)
        navigate('/sign-in', { replace: true })
        return
      }
      setSignOutError('We could not sign you out. Please try again.')
      recordError('auth.signed_out')
    } finally {
      setSigningOut(false)
    }
  }

  return (
    <div className="min-h-screen bg-background text-foreground">
      <header className="border-b bg-card">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-5 py-4">
          <Link to="/items" className="text-lg font-semibold tracking-tight">Kankal <span className="font-normal text-muted-foreground">workspace</span></Link>
          <div className="flex items-center gap-3">
            <span className="hidden text-sm text-muted-foreground sm:inline">{session?.email}</span>
            <Button variant="ghost" size="sm" asChild><Link to="/ui">UI showcase</Link></Button>
            <Button variant="outline" size="sm" onClick={signOut} disabled={signingOut}>
              {signingOut ? 'Signing out…' : 'Sign out'}
            </Button>
          </div>
        </div>
      </header>
      {signOutError && <div className="mx-auto max-w-6xl px-5 pt-4"><Alert variant="destructive" role="alert"><AlertDescription>{signOutError}</AlertDescription></Alert></div>}
      <main id="main-content" tabIndex={-1} className="mx-auto max-w-6xl px-5 py-8"><Outlet /></main>
    </div>
  )
}

function ProtectedRoute() {
  const { session } = useAuth()
  return session ? <AppFrame /> : <Navigate to="/sign-in" replace />
}

function SessionLoader({ children }: { children: ReactNode }) {
  const { auth } = useServices()
  const [session, setSession] = useState<Session | null>(null)
  const [loading, setLoading] = useState(true)
  const [loadError, setLoadError] = useState(false)

  useEffect(() => {
    let active = true
    auth.getSession().then((value) => { if (active) setSession(value) }).catch(() => { if (active) setLoadError(true) }).finally(() => { if (active) setLoading(false) })
    return () => { active = false }
  }, [auth])

  if (loading) return <main id="main-content" tabIndex={-1} className="min-h-screen p-5"><LoadingState label="Checking your session…" /></main>
  if (loadError) return <main id="main-content" tabIndex={-1} className="grid min-h-screen place-items-center p-5"><Card className="w-full max-w-md"><CardHeader><CardTitle role="heading" aria-level={1}>Workspace unavailable</CardTitle><CardDescription>We could not check your session.</CardDescription></CardHeader><CardContent><Button onClick={() => window.location.reload()}>Try again</Button></CardContent></Card></main>
  return <AuthContext.Provider value={{ session, setSession }}>{children}</AuthContext.Provider>
}

function NotFoundPage() {
  return <main id="main-content" tabIndex={-1} className="grid min-h-screen place-items-center p-5"><Card className="w-full max-w-md"><CardHeader><h1 className="text-lg font-semibold leading-none">Page not found</h1><CardDescription>The page you requested does not exist.</CardDescription></CardHeader><CardContent><Button asChild><Link to="/items">Go to workspace</Link></Button></CardContent></Card></main>
}

function SkipToMain() {
  return <a
    href="#main-content"
    onClick={() => document.getElementById('main-content')?.focus()}
    className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-50 focus:rounded-md focus:bg-background focus:px-4 focus:py-2 focus:text-foreground focus:shadow-md focus:outline-none focus:ring-2 focus:ring-ring"
  >Skip to main content</a>
}

export function App({ services }: { services: AppServices }) {
  return <ServicesContext.Provider value={services}><BrowserRouter><SkipToMain /><SessionLoader><Routes>
    <Route path="/sign-in" element={<SignInPage />} />
    <Route path="/ui" element={<UiShowcase />} />
    <Route element={<ProtectedRoute />}><Route path="/" element={<Navigate to="/items" replace />} /><Route path="/items" element={<ItemsPage />} /></Route>
    <Route path="*" element={<NotFoundPage />} />
  </Routes></SessionLoader></BrowserRouter></ServicesContext.Provider>
}
