import { afterEach, describe, expect, it } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { App } from '@/app/app'
import { createMockApis } from '@/api/mockApis'

afterEach(() => {
  cleanup()
  window.history.replaceState({}, '', '/')
})

describe('application shell', () => {
  it('opens the workspace after signing in', async () => {
    const user = userEvent.setup()
    render(<App services={createMockApis()} />)

    await user.type(await screen.findByLabelText('Email address'), 'demo@example.com')
    await user.type(await screen.findByLabelText('Password', { selector: 'input' }), 'password123')
    await user.click(screen.getByRole('button', { name: 'Sign in' }))

    expect(await screen.findByRole('heading', { name: 'Items' })).toBeInTheDocument()
  })

  it('lets keyboard users skip to the sign-in page main content', async () => {
    const user = userEvent.setup()
    render(<App services={createMockApis()} />)

    await screen.findByRole('heading', { name: 'Welcome back' })
    await user.tab()
    expect(screen.getByRole('link', { name: 'Skip to main content' })).toHaveFocus()

    await user.keyboard('{Enter}')
    expect(document.getElementById('main-content')).toHaveFocus()
  })

  it('gives an unknown route a semantic page heading', async () => {
    window.history.replaceState({}, '', '/missing')
    render(<App services={createMockApis()} />)

    expect(await screen.findByRole('heading', { level: 1, name: 'Page not found' })).toBeInTheDocument()
  })
})
