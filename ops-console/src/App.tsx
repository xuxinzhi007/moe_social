import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { ErrorBoundary } from './components/ErrorBoundary'
import { DeployProvider } from './context/DeployContext'
import { AppShell } from './layout/AppShell'
import { BuildPage } from './pages/BuildPage'
import { DockerPage } from './pages/DockerPage'
import { JobsPage } from './pages/JobsPage'
import { OverviewPage } from './pages/OverviewPage'
import { ReleasePage } from './pages/ReleasePage'
import { RpcPage } from './pages/RpcPage'

export default function App() {
  return (
    <ErrorBoundary>
      <DeployProvider>
        <BrowserRouter basename="/ops">
          <Routes>
            <Route element={<AppShell />}>
              <Route index element={<OverviewPage />} />
              <Route path="rpc" element={<RpcPage />} />
              <Route path="docker" element={<DockerPage />} />
              <Route path="build" element={<BuildPage />} />
              <Route path="release" element={<ReleasePage />} />
              <Route path="jobs" element={<JobsPage />} />
              <Route path="*" element={<Navigate to="/" replace />} />
            </Route>
          </Routes>
        </BrowserRouter>
      </DeployProvider>
    </ErrorBoundary>
  )
}
