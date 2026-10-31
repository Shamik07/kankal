export type ApiErrorCode =
  | 'INVALID_CREDENTIALS'
  | 'EMAIL_NOT_SUPPORTED'
  | 'CODE_NOT_REQUESTED'
  | 'INVALID_CODE'
  | 'AUTH_REQUIRED'
  | 'TITLE_REQUIRED'
  | 'ITEM_NOT_FOUND'

const errorMessages: Record<ApiErrorCode, string> = {
  INVALID_CREDENTIALS: 'Email or password is incorrect.',
  EMAIL_NOT_SUPPORTED: 'This email is not available in the demo.',
  CODE_NOT_REQUESTED: 'Request an email code before signing in.',
  INVALID_CODE: 'The email code is incorrect.',
  AUTH_REQUIRED: 'Sign in to continue.',
  TITLE_REQUIRED: 'Enter an item title.',
  ITEM_NOT_FOUND: 'This item could not be found.',
}

export class ApiError extends Error {
  readonly code: ApiErrorCode

  constructor(code: ApiErrorCode) {
    super(errorMessages[code])
    this.name = 'ApiError'
    this.code = code
  }
}

export interface Session {
  id: string
  email: string
}

export interface Item {
  id: string
  title: string
  description: string
  createdAt: string
  updatedAt: string
}

export interface ItemInput {
  title: string
  description: string
}

export interface AuthApi {
  requestEmailCode(email: string): Promise<void>
  signInWithPassword(input: { email: string; password: string }): Promise<Session>
  signInWithEmailCode(input: { email: string; code: string }): Promise<Session>
  signOut(): Promise<void>
  getSession(): Promise<Session | null>
}

export interface ItemsApi {
  list(): Promise<Item[]>
  create(input: ItemInput): Promise<Item>
  update(id: string, input: ItemInput): Promise<Item>
  delete(id: string): Promise<void>
}

export interface MockApis {
  auth: AuthApi
  items: ItemsApi
}
