import { useState } from 'react'
import { Outlet, useLocation, useNavigate } from 'react-router-dom'
import { SidebarNav } from '../components/SidebarNav'
import { SettingsDrawer } from '../components/SettingsDrawer'
import { READY_ROUTES } from '../config/menu'
import { useAdminAuth } from '../context/AdminAuthContext'
import { useDeploy } from '../context/DeployContext'
import { usePlatform } from '../context/PlatformContext'
import type { ApiTarget } from '../lib/apiTarget'

export function AppShell() {
  const { agentOnline, authOk, toast, baseUrl, agentMeta } = useDeploy()
  const { user, logout } = useAdminAuth()
  const navigate = useNavigate()
  const { apiTarget, setApiTarget, apiTargetLabel, health } = usePlatform()
  const [settingsOpen, setSettingsOpen] = useState(false)
  const location = useLocation()
  const isRpc = location.pathname === '/rpc' || location.pathname.endsWith('/rpc')

  const path = location.pathname.replace(/\/$/, '') || '/'
  const isReadyHome = READY_ROUTES.has(path)

  const assetBase = baseUrl.replace(/\/$/, '')
  const legacyRoot = `${assetBase}/`
  const devtoolsHref = `${assetBase}/devtools.html?tab=memory`

  const agentChip = agentMeta?.pid
    ? `Agent · PID ${agentMeta.pid}`
    : agentOnline
      ? 'Agent 在线'
      : 'Agent 离线'

  const apiOnline =
    apiTarget === 'cloud' ? health?.cloud_api?.online : health?.local_api?.online

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="sidebar-brand-wrap">
          <div className="brand">
            <h1>Moe Admin</h1>
            <p>Moe Social 管理后台</p>
          </div>
        </div>
        <div className="sidebar-nav-wrap">
          <SidebarNav legacyHref={legacyRoot} devtoolsHref={devtoolsHref} />
        </div>
        <div className="sidebar-foot">业务 API · Deploy Agent</div>
      </aside>

      <div className="main">
        <header className="topbar">
          <div className="conn-pill">
            <span
              className={`dot ${agentOnline ? 'ok' : agentOnline === false ? 'err' : ''}`}
            />
            <span>{agentOnline ? '网关在线' : '网关离线'}</span>
          </div>

          <label className="env-switch" title="切换业务 API 数据源">
            <span className="env-switch-label">数据环境</span>
            <select
              className="select-inline"
              value={apiTarget}
              onChange={(e) => setApiTarget(e.target.value as ApiTarget)}
            >
              <option value="local">本机 API</option>
              <option value="cloud">云端 API</option>
            </select>
            <span
              className={`tag ${apiOnline ? 'tag-ok' : 'tag-fail'}`}
              style={{ marginLeft: 6 }}
            >
              {apiOnline ? '可达' : '不可达'}
            </span>
          </label>

          <span className="agent-chip" title="Deploy Agent">
            {agentChip}
          </span>
          {user ? (
            <span className="tag tag-ok" style={{ fontSize: 11 }} title={user.role}>
              {user.username}
            </span>
          ) : null}
          {authOk === true ? (
            <span className="tag tag-ok" style={{ fontSize: 11 }}>
              部署 Token
            </span>
          ) : (
            <span className="tag tag-pending" style={{ fontSize: 11 }}>
              部署未授权
            </span>
          )}
          <button
            type="button"
            className="btn btn-ghost"
            onClick={() => {
              logout()
              navigate('/login')
            }}
          >
            退出
          </button>
          <button
            type="button"
            className="btn btn-ghost"
            onClick={() => setSettingsOpen(true)}
          >
            设置
          </button>
        </header>

        <div className={`content${isRpc ? ' content-rpc' : ''}`}>
          {!isRpc && !isReadyHome ? (
            <div className="legacy-banner">
              部署类操作需有效 Deploy Token；业务数据使用顶栏{' '}
              <strong>{apiTargetLabel}</strong>。
            </div>
          ) : null}
          <div className={isRpc ? undefined : 'admin-page'}>
            <Outlet />
          </div>
        </div>
      </div>

      <SettingsDrawer open={settingsOpen} onClose={() => setSettingsOpen(false)} />
      {toast ? <div className="toast">{toast}</div> : null}
    </div>
  )
}
