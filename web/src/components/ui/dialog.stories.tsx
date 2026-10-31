import type { Meta, StoryObj } from '@storybook/react-vite'
import { Button } from './button'
import { Dialog, DialogClose, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from './dialog'

function ConfirmationDialog() {
  return (
    <Dialog>
      <DialogTrigger asChild><Button variant="destructive">Delete item</Button></DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Delete this item?</DialogTitle>
          <DialogDescription>This example shows the confirmation pattern. No data is changed.</DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <DialogClose asChild><Button variant="outline">Cancel</Button></DialogClose>
          <DialogClose asChild><Button variant="destructive">Confirm deletion</Button></DialogClose>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

const meta = {
  title: 'Controls/Confirmation dialog',
  component: ConfirmationDialog,
} satisfies Meta<typeof ConfirmationDialog>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {}
