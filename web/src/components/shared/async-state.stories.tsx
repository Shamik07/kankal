import type { Meta, StoryObj } from '@storybook/react-vite'
import { EmptyState, ErrorState, LoadingState } from './async-state'

const meta = {
  title: 'Content/Async states',
  component: LoadingState,
} satisfies Meta<typeof LoadingState>

export default meta
type Story = StoryObj<typeof meta>

export const Loading: Story = { args: { label: 'Loading items' } }
export const Empty: Story = {
  render: () => <EmptyState title="Nothing here yet" description="Create your first item to get started." action={{ label: 'Create item', onClick: () => {} }} />,
}
export const Error: Story = {
  render: () => <ErrorState title="Could not load items" description="Check your connection, then try again." onRetry={() => {}} />,
}
