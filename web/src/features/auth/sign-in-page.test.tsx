import { afterEach, describe, expect, it } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { App } from '@/app/app'
import { createMockApis } from '@/api/mockApis'

afterEach(() => {
  cleanup()
  window.history.replaceState({}, '', '/')
})

describe('sign-in flow', () => {
  it('shows an error for an incorrect password', async () => {
    const user = userEvent.setup()
    render(<App services={createMockApis()} />)
    await user.type(await screen.findByLabelText('Email address'), 'demo@example.com')
    await user.type(screen.getByLabelText('Password'), 'wrong-password')
    await user.click(screen.getByRole('button', { name: 'Sign in' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Email or password is incorrect.')
  })
})
