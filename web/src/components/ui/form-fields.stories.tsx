import type { Meta, StoryObj } from '@storybook/react-vite'
import { Input } from './input'
import { Label } from './label'
import { Textarea } from './textarea'

function FormFields({ invalid = false }: { invalid?: boolean }) {
  return (
    <div className="space-y-5">
      <div className="space-y-2">
        <Label htmlFor="story-name">Workspace name</Label>
        <Input id="story-name" placeholder="Northstar Studio" aria-invalid={invalid} aria-describedby={invalid ? 'story-error' : undefined} />
        {invalid && <p id="story-error" className="text-sm text-destructive">Enter a workspace name.</p>}
      </div>
      <div className="space-y-2">
        <Label htmlFor="story-notes">Notes</Label>
        <Textarea id="story-notes" placeholder="Add a short description" />
      </div>
    </div>
  )
}

const meta = {
  title: 'Controls/Form fields',
  component: FormFields,
} satisfies Meta<typeof FormFields>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {}
export const ValidationError: Story = { args: { invalid: true } }
