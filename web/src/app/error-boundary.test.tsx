import { cleanup, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { ErrorBoundary } from './error-boundary'

describe('ErrorBoundary', () => {
  afterEach(() => {
    cleanup()
    vi.restoreAllMocks()
  })

  it('shows a generic recovery action when a screen crashes during render', () => {
    const diagnostic = vi.spyOn(console, 'info').mockImplementation(() => {})

    function BrokenScreen(): never {
      throw new Error('sentinel crash')
    }

    render(
      <ErrorBoundary>
        <BrokenScreen />
      </ErrorBoundary>,
    )

    expect(screen.getByRole('alert')).toHaveTextContent('Something went wrong')
    expect(screen.getByRole('button', { name: 'Try again' })).toBeInTheDocument()
    expect(screen.getByRole('main')).toHaveAttribute('id', 'main-content')
    expect(screen.getByRole('main')).toHaveAttribute('tabindex', '-1')
    expect(screen.queryByText('sentinel crash')).not.toBeInTheDocument()
    expect(diagnostic).toHaveBeenCalledWith('[kankal] app.render_failed.error')
    expect(diagnostic).not.toHaveBeenCalledWith(expect.stringContaining('sentinel crash'))
  })

  it('retries rendering the screen when the user asks', async () => {
    const user = userEvent.setup()
    vi.spyOn(console, 'info').mockImplementation(() => {})
    let recovered = false

    function UnavailableScreen() {
      if (!recovered) throw new Error('render unavailable')
      return <p>Screen restored</p>
    }

    render(<ErrorBoundary><UnavailableScreen /></ErrorBoundary>)
    expect(screen.getByRole('button', { name: 'Try again' })).toBeInTheDocument()

    recovered = true
    await user.click(screen.getByRole('button', { name: 'Try again' }))
    expect(screen.getByText('Screen restored')).toBeInTheDocument()
  })
})
