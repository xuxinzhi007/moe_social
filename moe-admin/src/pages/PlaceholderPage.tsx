import { Link, useLocation } from 'react-router-dom'
import { PLACEHOLDER_PAGES } from '../config/placeholders'

export function PlaceholderPage() {
  const location = useLocation()
  const key = location.pathname.replace(/^\//, '').replace(/\/$/, '')
  const meta = PLACEHOLDER_PAGES[key]

  if (!meta) {
    return (
      <div className="panel">
        <div className="panel-body">
          <h2>页面未配置</h2>
          <p className="muted">路径：{location.pathname}</p>
          <Link to="/">返回工作台</Link>
        </div>
      </div>
    )
  }

  return (
    <>
      <div className="page-head">
        <h2>{meta.title}</h2>
        <p>
          规划阶段 <strong>{meta.phase}</strong> · 对应 App：{meta.appDomain}
        </p>
      </div>

      <div className="panel">
        <div className="panel-body placeholder-body">
          <div className="placeholder-tag">待开发</div>
          <p>{meta.summary}</p>
          <h3>计划接口</h3>
          <ul>
            {meta.apis.map((api) => (
              <li key={api}>
                <code>{api}</code>
              </li>
            ))}
          </ul>
          <p className="muted">
            侧栏已按 App 业务域分组；本页上线后需在后端增加{' '}
            <code>/api/admin/*</code> 并在 React 中实现列表/表单。设计见{' '}
            <code>docs/dev/moe-admin-platform-design.md</code>。
          </p>
          <div className="btn-row" style={{ marginTop: 16 }}>
            <Link to="/" className="btn btn-primary">
              返回工作台
            </Link>
            <Link to="/users" className="btn btn-ghost">
              先去用户列表
            </Link>
          </div>
        </div>
      </div>
    </>
  )
}
