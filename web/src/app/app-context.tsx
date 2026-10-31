import { createContext, useContext } from 'react'
import type { AuthApi, ItemsApi, Session } from '@/api/types'

export interface AppServices {
  auth: Pick<AuthApi, 'getSession' | 'signInWithPassword' | 'signOut'>
  items: ItemsApi
}

export interface AuthState {
  session: Session | null
  setSession: (session: Session | null) => void
}

export const ServicesContext = createContext<AppServices | null>(null)
export const AuthContext = createContext<AuthState | null>(null)

export function useServices(): AppServices {
  const services = useContext(ServicesContext)
  if (!services) throw new Error('App services are unavailable.')
  return services
}

export function useAuth(): AuthState {
  const auth = useContext(AuthContext)
  if (!auth) throw new Error('Authentication state is unavailable.')
  return auth
}
