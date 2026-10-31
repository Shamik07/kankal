import { Code, ConnectError, createClient } from '@connectrpc/connect'
import { createGrpcWebTransport } from '@connectrpc/connect-web'
import { WorkspaceService } from './gen/kankal/workspace/v1/workspace_pb'
import { ApiError, type Item, type Session } from './types'
import type { AppServices } from '@/app/app-context'

const client = createClient(WorkspaceService, createGrpcWebTransport({ baseUrl: window.location.origin }))

function required<T>(value: T | undefined): T {
  if (!value) throw new Error('Incomplete response')
  return value
}

function mapError(error: unknown): never {
  if (error instanceof ConnectError) {
    if (error.code === Code.Unauthenticated) throw new ApiError('AUTH_REQUIRED')
    if (error.code === Code.NotFound) throw new ApiError('ITEM_NOT_FOUND')
  }
  throw error
}

export function createWorkspaceApis(): AppServices {
  return {
    auth: {
      async getSession(): Promise<Session | null> {
        try { return required((await client.getSession({})).session) }
        catch (error) {
          if (error instanceof ConnectError && error.code === Code.Unauthenticated) return null
          throw error
        }
      },
      async signInWithPassword(input): Promise<Session> {
        try { return required((await client.signIn(input)).session) }
        catch (error) {
          if (error instanceof ConnectError && error.code === Code.Unauthenticated) throw new ApiError('INVALID_CREDENTIALS')
          throw error
        }
      },
      async signOut() { try { await client.signOut({}) } catch (error) { mapError(error) } },
    },
    items: {
      async list(): Promise<Item[]> { try { return (await client.listItems({})).items } catch (error) { return mapError(error) } },
      async create(input): Promise<Item> { try { return required((await client.createItem(input)).item) } catch (error) { return mapError(error) } },
      async update(id, input): Promise<Item> { try { return required((await client.updateItem({ id, ...input })).item) } catch (error) { return mapError(error) } },
      async delete(id) { try { await client.deleteItem({ id }) } catch (error) { mapError(error) } },
    },
  }
}
