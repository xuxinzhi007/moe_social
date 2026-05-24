import { useState } from 'react'
import { NavLink, Outlet, useLocation } from 'react-router-dom'
import { SettingsDrawer } from '../components/SettingsDrawer'
import { useDeploy } from '../context/DeployContext'

const NAV: { to: string; label: string; end?: boolean }[] = [
  { to: '/', label: '◉ 总览', end: true },
  { to: '/rpc', label: '◫ RPC 监控' },
  { to: '/docker', label: '☁ 云 Docker' },
  { to: '/build', label: '⚙ 构建流水线' },
  { to: '/release', label: '↑ 应用发布' },
  { to: '/jobs', label: '☰ 任务审计' },
]

export function AppShell() {
  const { agentOnline, authOk, toast, baseUrl, agentMeta } = useDeploy()
  const [settingsOpen, setSettingsOpen] = useState(false)
  const location = useLocation()
  const isRpc = location.pathname === '/rpc' || location.pathname.endsWith('/rpc')

  const assetBase = baseUrl.replace(/\/$/, '')
  const legacyRoot = `${assetBase}/`

  const agentChip = agentMeta?.pid
    ? `Agent · PID ${agentMeta.pid} · ${agentMeta.platform_label || agentMeta.platform || ''}`
    : agentOnline
      ? 'Agent 在线'
      : 'Agent 离线'

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <h1>Moe Ops</h1>
          <p>React 运维台 · v0.1</p>
        </div>
        <nav>
          {NAV.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end === true}
              className={({ isActive }) =>
                `nav-item${isActive ? ' active' : ''}`
              }
            >
              {item.label}
            </NavLink>
          ))}
        </nav>
        <div className="tool-links">
          <div className="cap">其他</div>
          <a className="tool-link" href={legacyRoot} target="_blank" rel="noopener">
            HTML 版 Moe Ops ↗
          </a>
          <a
            className="tool-link"
            href={`${assetBase}/devtools.html?tab=memory`}
            target="_blank"
            rel="noopener"
          >
            记忆系统监控 ↗
          </a>
          <a
            className="tool-link"
            href={`${assetBase}/index.html`}
            target="_blank"
            rel="noopener"
          >
            文档导航 ↗
          </a>
        </div>
        <div className="sidebar-foot">Deploy Agent · :19010</div>
      </aside>

      <div className="main">
        <header className="topbar">
          <div className="conn-pill">
            <span
              className={`dot ${agentOnline ? 'ok' : agentOnline === false ? 'err' : ''}`}
            />
            <span>{agentOnline ? 'Agent 在线' : 'Agent 离线'}</span>
          </div>
          <span className="agent-chip" title="Deploy Agent">
            {agentChip}
          </span>
          <span className="tag tag-pending" style={{ fontSize: 11 }}>
            {authOk ? 'Token OK' : authOk === false ? 'Token 无效' : '未验证'}
          </span>
          <button
            type="button"
            className="btn btn-ghost"
            onClick={() => setSettingsOpen(true)}
          >
            ⚙ 连接设置
          </button>
        </header>

        <div className={`content${isRpc ? ' content-rpc' : ''}`}>
          {!isRpc ? (
            <div className="legacy-banner">
              React 版运维台；经典 HTML：
              <a href={legacyRoot}>打开 HTML Moe Ops</a>
            </div>
          ) : null}
          <Outlet />
        </div>
      </div>

      <SettingsDrawer open={settingsOpen} onClose={() => setSettingsOpen(false)} />
      {toast ? <div className="toast">{toast}</div> : null}
    </div>
  )
}
