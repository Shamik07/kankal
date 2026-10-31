import ReactDOM from 'react-dom/client'
import { App } from './app/app'
import { ErrorBoundary } from './app/error-boundary'
import { createWorkspaceApis } from './api/workspaceApis'
import './index.css'

const services = createWorkspaceApis()

ReactDOM.createRoot(document.getElementById('root')!).render(
  <ErrorBoundary>
    <App services={services} />
  </ErrorBoundary>,
)
