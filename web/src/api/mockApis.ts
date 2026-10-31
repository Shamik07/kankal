import { record } from '../diagnostics/diagnostics'
import { ApiError, type Item, type ItemInput, type MockApis, type Session } from './types'

const DEMO_EMAIL = 'demo@example.com'
const DEMO_PASSWORD = 'password123'
const DEMO_CODE = '123456'
const DEMO_USER_ID = 'demo-user'

interface StoredItem extends Item {
  ownerId: string
}

export function createMockApis(): MockApis {
  let session: Session | null = null
  const requestedCodes = new Set<string>()
  const storedItems: StoredItem[] = [{
    id: 'sample-item',
    ownerId: DEMO_USER_ID,
    title: 'Sample item',
    description: 'A small example to get started.',
    createdAt: '2026-01-01T00:00:00.000Z',
    updatedAt: '2026-01-01T00:00:00.000Z',
  }]

  function requireSession(): Session {
    if (!session) throw new ApiError('AUTH_REQUIRED')
    return session
  }

  function cleanItem(item: StoredItem): Item {
    return {
      id: item.id,
      title: item.title,
      description: item.description,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    }
  }

  function validateInput(input: ItemInput): ItemInput {
    const title = input.title.trim()
    if (!title) throw new ApiError('TITLE_REQUIRED')
    return { title, description: input.description.trim() }
  }

  function ownedItem(id: string, ownerId: string): StoredItem {
    const item = storedItems.find((candidate) => candidate.id === id && candidate.ownerId === ownerId)
    if (!item) throw new ApiError('ITEM_NOT_FOUND')
    return item
  }

  const auth = {
    async requestEmailCode(email: string): Promise<void> {
      if (email.trim().toLowerCase() !== DEMO_EMAIL) throw new ApiError('EMAIL_NOT_SUPPORTED')
      requestedCodes.add(DEMO_EMAIL)
      record('auth.code_requested')
    },
    async signInWithPassword(input: { email: string; password: string }): Promise<Session> {
      if (input.email.trim().toLowerCase() !== DEMO_EMAIL || input.password !== DEMO_PASSWORD) {
        throw new ApiError('INVALID_CREDENTIALS')
      }
      session = { id: DEMO_USER_ID, email: DEMO_EMAIL }
      record('auth.signed_in')
      return { ...session }
    },
    async signInWithEmailCode(input: { email: string; code: string }): Promise<Session> {
      const email = input.email.trim().toLowerCase()
      if (!requestedCodes.has(email)) throw new ApiError('CODE_NOT_REQUESTED')
      requestedCodes.delete(email)
      if (email !== DEMO_EMAIL || input.code !== DEMO_CODE) throw new ApiError('INVALID_CODE')
      session = { id: DEMO_USER_ID, email: DEMO_EMAIL }
      record('auth.signed_in')
      return { ...session }
    },
    async signOut(): Promise<void> {
      session = null
      record('auth.signed_out')
    },
    async getSession(): Promise<Session | null> {
      return session ? { ...session } : null
    },
  }

  const items = {
    async list(): Promise<Item[]> {
      const current = requireSession()
      return storedItems.filter((item) => item.ownerId === current.id).map(cleanItem)
    },
    async create(input: ItemInput): Promise<Item> {
      const current = requireSession()
      const valid = validateInput(input)
      const now = new Date().toISOString()
      const item: StoredItem = {
        id: crypto.randomUUID(), ownerId: current.id, ...valid, createdAt: now, updatedAt: now,
      }
      storedItems.push(item)
      record('items.created')
      return cleanItem(item)
    },
    async update(id: string, input: ItemInput): Promise<Item> {
      const current = requireSession()
      const valid = validateInput(input)
      const item = ownedItem(id, current.id)
      Object.assign(item, valid, { updatedAt: new Date().toISOString() })
      record('items.updated')
      return cleanItem(item)
    },
    async delete(id: string): Promise<void> {
      const current = requireSession()
      const item = ownedItem(id, current.id)
      storedItems.splice(storedItems.indexOf(item), 1)
      record('items.deleted')
    },
  }

  return { auth, items }
}
