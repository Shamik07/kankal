import type { Meta, StoryObj } from '@storybook/react-vite'
import { Button } from './button'

const meta = {
  title: 'Controls/Button',
  component: Button,
  args: { children: 'Continue' },
} satisfies Meta<typeof Button>

export default meta
type Story = StoryObj<typeof meta>

export const Primary: Story = {}
export const Outline: Story = { args: { variant: 'outline' } }
export const Destructive: Story = { args: { variant: 'destructive', children: 'Delete item' } }
export const Disabled: Story = { args: { disabled: true } }
