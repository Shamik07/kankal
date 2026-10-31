import type { Preview } from '@storybook/react-vite'
import '../src/index.css'

const preview: Preview = {
  decorators: [
    (Story) => (
      <div className="min-h-screen bg-background p-6 text-foreground">
        <div className="mx-auto max-w-lg"><Story /></div>
      </div>
    ),
  ],
  parameters: {
    layout: 'fullscreen',
  },
}

export default preview
