import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { ErrorBoundary } from './components/ErrorBoundary'
import { RequireAdmin } from './components/RequireAdmin'
import { AdminAuthProvider } from './context/AdminAuthContext'
import { DeployProvider } from './context/DeployContext'
import { PlatformProvider } from './context/PlatformContext'
import { AppShell } from './layout/AppShell'
import { BuildPage } from './pages/BuildPage'
import { DashboardPage } from './pages/DashboardPage'
import { DockerPage } from './pages/DockerPage'
import { FeedbackPage } from './pages/FeedbackPage'
import { JobsPage } from './pages/JobsPage'
import { LoginPage } from './pages/LoginPage'
import { OverviewPage } from './pages/OverviewPage'
import { PlaceholderPage } from './pages/PlaceholderPage'
import { ReleasePage } from './pages/ReleasePage'
import { RpcPage } from './pages/RpcPage'
import { UsersPage } from './pages/UsersPage'
import { VipPlansPage } from './pages/VipPlansPage'
import { GiftsPage } from './pages/GiftsPage'
import { WalletOrdersPage } from './pages/WalletOrdersPage'
import { PostsPage } from './pages/PostsPage'
import { CommentsPage } from './pages/CommentsPage'
import { CommunityGroupsPage } from './pages/CommunityGroupsPage'
import { ReportsPage } from './pages/ReportsPage'

export default function App() {
  return (
    <ErrorBoundary>
      <DeployProvider>
        <PlatformProvider>
          <AdminAuthProvider>
            <BrowserRouter basename="/ops">
              <Routes>
                <Route path="/login" element={<LoginPage />} />
                <Route element={<RequireAdmin />}>
                  <Route element={<AppShell />}>
                    <Route index element={<DashboardPage />} />
                    <Route path="users" element={<UsersPage />} />
                    <Route path="vip/plans" element={<VipPlansPage />} />
                    <Route path="wallet/orders" element={<WalletOrdersPage />} />
                    <Route path="gifts/catalog" element={<GiftsPage />} />
                    <Route path="content/posts" element={<PostsPage />} />
                    <Route path="content/comments" element={<CommentsPage />} />
                    <Route path="content/community" element={<CommunityGroupsPage />} />
                    <Route path="content/reports" element={<ReportsPage />} />
                    <Route path="feedback" element={<FeedbackPage />} />
                    <Route path="deploy" element={<OverviewPage />} />
                    <Route path="rpc" element={<RpcPage />} />
                    <Route path="docker" element={<DockerPage />} />
                    <Route path="build" element={<BuildPage />} />
                    <Route path="release" element={<ReleasePage />} />
                    <Route path="jobs" element={<JobsPage />} />
                    <Route path="app/*" element={<PlaceholderPage />} />
                    <Route path="system/*" element={<PlaceholderPage />} />
                    <Route path="*" element={<Navigate to="/" replace />} />
                  </Route>
                </Route>
              </Routes>
            </BrowserRouter>
          </AdminAuthProvider>
        </PlatformProvider>
      </DeployProvider>
    </ErrorBoundary>
  )
}
