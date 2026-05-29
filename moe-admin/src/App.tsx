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
import { GrowthPage } from './pages/GrowthPage'
import { AnnouncementsPage } from './pages/AnnouncementsPage'
import { NotifyPage } from './pages/NotifyPage'
import { AiAgentsPage } from './pages/AiAgentsPage'
import { MoeBotsPage } from './pages/MoeBotsPage'
import { MoeBrainPage } from './pages/MoeBrainPage'
import { MoeBotFlowPage } from './pages/MoeBotFlowPage'
import { MoeToolsPage } from './pages/MoeToolsPage'
import { AiChatLogsPage } from './pages/AiChatLogsPage'
import { AnalyticsPage } from './pages/AnalyticsPage'
import { TagsCenterPage } from './pages/TagsCenterPage'
import { SocialPage } from './pages/SocialPage'
import { AdminAccountsPage } from './pages/AdminAccountsPage'
import { MenusPage } from './pages/MenusPage'
import { AuditLogsPage } from './pages/AuditLogsPage'
import { MediaGalleryPage } from './pages/MediaGalleryPage'
import { PlatformPage } from './pages/PlatformPage'

function PlatformRedirect({ tab }: { tab: string }) {
  return <Navigate to={`/system/platform?tab=${tab}`} replace />
}

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
                    <Route path="app/growth" element={<GrowthPage />} />
                    <Route path="app/announcements" element={<AnnouncementsPage />} />
                    <Route path="app/notify" element={<NotifyPage />} />
                    <Route path="app/ai" element={<AiAgentsPage />} />
                    <Route path="app/moe-bots" element={<MoeBotsPage />} />
                    <Route path="app/moe-bots/:agentKey/brain" element={<MoeBrainPage />} />
                    <Route path="app/moe-brain" element={<MoeBrainPage />} />
                    <Route path="app/moe-flow" element={<MoeBotFlowPage />} />
                    <Route path="app/moe" element={<MoeToolsPage />} />
                    <Route path="app/ai/chat-logs" element={<AiChatLogsPage />} />
                    <Route path="app/analytics" element={<AnalyticsPage />} />
                    <Route path="app/tags" element={<TagsCenterPage />} />
                    <Route path="app/social" element={<SocialPage />} />
                    <Route path="system/admins" element={<AdminAccountsPage />} />
                    <Route path="system/menus" element={<MenusPage />} />
                    <Route path="system/platform" element={<PlatformPage />} />
                    <Route path="system/data" element={<PlatformRedirect tab="data" />} />
                    <Route path="system/app-config" element={<PlatformRedirect tab="config" />} />
                    <Route path="system/media-gallery" element={<MediaGalleryPage />} />
                    <Route path="system/media" element={<Navigate to="/system/media-gallery" replace />} />
                    <Route path="system/audit" element={<AuditLogsPage />} />
                    <Route path="deploy" element={<OverviewPage />} />
                    <Route path="rpc" element={<RpcPage />} />
                    <Route path="docker" element={<DockerPage />} />
                    <Route path="build" element={<BuildPage />} />
                    <Route path="release" element={<ReleasePage />} />
                    <Route path="jobs" element={<JobsPage />} />
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
