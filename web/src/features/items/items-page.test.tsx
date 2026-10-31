import { afterEach, describe, expect, it } from 'vitest'
import { cleanup, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { App } from '@/app/app'
import { createMockApis } from '@/api/mockApis'

afterEach(() => {
  cleanup()
  window.history.replaceState({}, '', '/')
})

describe('item management', () => {
  it('keeps item creation unavailable until a failed item load is retried successfully', async () => {
    const services = createMockApis()
    await services.auth.signInWithPassword({ email: 'demo@example.com', password: 'password123' })
    const listItems = services.items.list.bind(services.items)
    let listAttempts = 0
    services.items.list = async () => {
      listAttempts += 1
      if (listAttempts === 1) throw new Error('Temporary load failure')
      return listItems()
    }

    render(<App services={services} />)
    expect(await screen.findByText('Items could not be loaded')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Create item' })).toBeDisabled()

    await userEvent.setup().click(screen.getByRole('button', { name: 'Try again' }))
    expect(await screen.findByText('Sample item')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Create item' })).toBeEnabled()
  })

  it('requires a title and keeps the editor open with a useful validation message', async () => {
    const user = userEvent.setup()
    const services = createMockApis()
    await services.auth.signInWithPassword({ email: 'demo@example.com', password: 'password123' })
    render(<App services={services} />)
    await user.click(await screen.findByRole('button', { name: 'Create item' }))
    await user.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Create item' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Enter an item title.')
    expect(screen.getByRole('heading', { name: 'Create an item' })).toBeInTheDocument()
  })
})
