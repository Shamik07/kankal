import { describe, expect, it } from 'vitest'
import { createMockApis } from './mockApis'
import { ApiError } from './types'

describe('mock authentication', () => {
  it('requires a requested code and consumes that code after one attempt', async () => {
    const { auth } = createMockApis()

    await expect(auth.signInWithEmailCode({ email: 'demo@example.com', code: '123456' }))
      .rejects.toMatchObject({ code: 'CODE_NOT_REQUESTED' })
    await auth.requestEmailCode('demo@example.com')
    await expect(auth.signInWithEmailCode({ email: 'demo@example.com', code: '000000' }))
      .rejects.toMatchObject({ code: 'INVALID_CODE' })
    await expect(auth.signInWithEmailCode({ email: 'demo@example.com', code: '123456' }))
      .rejects.toMatchObject({ code: 'CODE_NOT_REQUESTED' })
  })

  it('supports password sign-in and returns to a signed-out state', async () => {
    const { auth } = createMockApis()
    await expect(auth.signInWithPassword({ email: 'demo@example.com', password: 'password123' }))
      .resolves.toMatchObject({ email: 'demo@example.com' })
    await auth.signOut()
    await expect(auth.getSession()).resolves.toBeNull()
  })

  it('rejects unsupported emails and signs in with the requested demo code', async () => {
    const { auth } = createMockApis()
    await expect(auth.requestEmailCode('private@example.com'))
      .rejects.toMatchObject({ code: 'EMAIL_NOT_SUPPORTED' })
    await auth.requestEmailCode('demo@example.com')
    await expect(auth.signInWithEmailCode({ email: 'demo@example.com', code: '123456' }))
      .resolves.toMatchObject({ email: 'demo@example.com' })
  })

  it('uses fixed error codes and messages without echoing submitted secrets', async () => {
    const { auth } = createMockApis()
    const password = 'my-secret-password'
    try {
      await auth.signInWithPassword({ email: 'private@example.com', password })
      throw new Error('expected sign-in to fail')
    } catch (error) {
      expect(error).toBeInstanceOf(ApiError)
      expect(error).toMatchObject({ code: 'INVALID_CREDENTIALS', message: 'Email or password is incorrect.' })
      expect(JSON.stringify(error)).not.toContain(password)
    }
  })
})

describe('mock items', () => {
  it('starts with Sample item and supports create, update, and delete', async () => {
    const { auth, items } = createMockApis()
    await auth.signInWithPassword({ email: 'demo@example.com', password: 'password123' })
    await expect(items.list()).resolves.toMatchObject([{ title: 'Sample item' }])

    const created = await items.create({ title: '  Plan launch  ', description: '  First draft  ' })
    expect(created).toMatchObject({ title: 'Plan launch', description: 'First draft' })
    await expect(items.update(created.id, { title: 'Launch plan', description: 'Ready' }))
      .resolves.toMatchObject({ title: 'Launch plan', description: 'Ready' })
    await items.delete(created.id)
    await expect(items.list()).resolves.toHaveLength(1)
  })

  it('requires a trimmed title and rejects missing item ids with safe errors', async () => {
    const { auth, items } = createMockApis()
    await auth.signInWithPassword({ email: 'demo@example.com', password: 'password123' })
    await expect(items.create({ title: '  ', description: '' })).rejects.toMatchObject({ code: 'TITLE_REQUIRED' })
    await expect(items.update('missing-id', { title: 'Valid', description: '' }))
      .rejects.toMatchObject({ code: 'ITEM_NOT_FOUND' })
    await expect(items.delete('missing-id')).rejects.toMatchObject({ code: 'ITEM_NOT_FOUND' })
  })

  it('keeps item reads and writes behind the signed-in session boundary', async () => {
    const { auth, items } = createMockApis()
    await expect(items.list()).rejects.toMatchObject({ code: 'AUTH_REQUIRED' })
    await expect(items.create({ title: 'Hidden', description: '' })).rejects.toMatchObject({ code: 'AUTH_REQUIRED' })
    await auth.signInWithPassword({ email: 'demo@example.com', password: 'password123' })
    await expect(items.list()).resolves.toHaveLength(1)
    await auth.signOut()
    await expect(items.list()).rejects.toMatchObject({ code: 'AUTH_REQUIRED' })
  })

  it('records fixed operation names without logging user content', async () => {
    const messages: string[] = []
    const originalInfo = console.info
    console.info = (...values: unknown[]) => messages.push(values.join(' '))
    try {
      const { auth, items } = createMockApis()
      await auth.signInWithPassword({ email: 'demo@example.com', password: 'password123' })
      await items.create({ title: 'Private item title', description: 'Private item details' })
    } finally {
      console.info = originalInfo
    }
    expect(messages).toEqual(['[kankal] auth.signed_in', '[kankal] items.created'])
    expect(messages.join(' ')).not.toContain('Private item')
  })
})
