import { useState, type FormEvent } from 'react'
import { Navigate, useLocation, useNavigate } from 'react-router-dom'
import { useAdminAuth } from '../context/AdminAuthContext'
import { usePlatform } from '../context/PlatformContext'
import type { ApiTarget } from '../lib/apiTarget'

export function LoginPage() {
  const { token, login, loggingIn, bootstrapped } = useAdminAuth()
  const { apiTarget, setApiTarget, apiTargetLabel } = usePlatform()
  const navigate = useNavigate()
  const location = useLocation()
  const [username, setUsername] = useState('admin')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')

  const from =
    (location.state as { from?: string } | null)?.from?.replace(/^\/ops/, '') ||
    '/'

  if (bootstrapped && token) {
    return <Navigate to={from} replace />
  }

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    setError('')
    const err = await login(username.trim(), password)
    if (err) {
      setError(err)
      return
    }
    navigate(from, { replace: true })
  }

  return (
    <div className="login-page">
      <div className="login-layout">
        <div className="login-aside">
          <h2>Moe Admin</h2>
          <p>Moe Social 专属管理后台</p>
          <ul className="login-aside-list">
            <li>App 用户与官网反馈</li>
            <li>本机 / 云端 API 切换</li>
            <li>构建发布与 RPC 监控</li>
          </ul>
        </div>

        <div className="login-card">
          <div className="login-brand">
            <h1>登录</h1>
            <p>使用管理员账号（admin_accounts）</p>
          </div>

          <p className="login-hint muted">
            开发模式：仅需 RPC + API 即可登录；运维功能需另开{' '}
            <code>make deploy-agent</code>（:19010）。
          </p>

          <form className="login-form" onSubmit={(e) => void onSubmit(e)}>
            <label>
              <span>数据环境</span>
              <select
                value={apiTarget}
                onChange={(e) => setApiTarget(e.target.value as ApiTarget)}
              >
                <option value="local">本机 API（{apiTargetLabel}）</option>
                <option value="cloud">云端 API</option>
              </select>
            </label>

            <label>
              <span>用户名</span>
              <input
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                autoComplete="username"
                required
              />
            </label>

            <label>
              <span>密码</span>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete="current-password"
                placeholder="默认 admin123（首次迁移后）"
                required
              />
            </label>

            {error ? <div className="login-error">{error}</div> : null}

            <button
              type="submit"
              className="btn btn-primary btn-block"
              disabled={loggingIn}
            >
              {loggingIn ? '登录中…' : '登录'}
            </button>
          </form>
        </div>
      </div>
    </div>
  )
}
