import { useEffect, useState } from 'react'
import { useDeploy } from '../context/DeployContext'
import { useDrawerDismiss } from '../hooks/useDrawerDismiss'
import { AGENT_URL } from '../lib/storage'

type Props = {
  open: boolean
  onClose: () => void
}

export function SettingsDrawer({ open, onClose }: Props) {
  const {
    baseUrl,
    token,
    deployTarget,
    saveConnection,
    verifyToken,
    probeAgent,
    agentOnline,
    authOk,
    client,
  } = useDeploy()
  const [url, setUrl] = useState(baseUrl)
  const [tok, setTok] = useState(token)
  const [target, setTarget] = useState(deployTarget)
  const [authLog, setAuthLog] = useState('—')

  useEffect(() => {
    if (open) {
      setUrl(baseUrl)
      setTok(token)
      setTarget(deployTarget)
    }
  }, [open, baseUrl, token, deployTarget])

  useDrawerDismiss(open, onClose)

  if (!open) return null

  async function handleSave() {
    await saveConnection(url, tok, target)
    onClose()
  }

  async function handleVerify() {
    await saveConnection(url, tok, target)
    const ok = await verifyToken()
    setAuthLog(ok ? 'Deploy Token 有效' : 'Token 无效或 Agent 未启动')
  }

  async function handleSsh() {
    try {
      const data = await client.sshCheck('cloud')
      const p = data.probe
      setAuthLog((p?.message || '') + '\n' + (p?.output || ''))
    } catch (e) {
      setAuthLog(e instanceof Error ? e.message : 'SSH 检查失败')
    }
  }

  return (
    <div
      className="drawer-backdrop"
      role="presentation"
      onClick={onClose}
      aria-hidden={false}
    >
      <p className="drawer-backdrop-hint">点击空白处或按 Esc 关闭</p>
      <aside
        className="drawer"
        role="dialog"
        aria-modal="true"
        aria-label="连接设置"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="drawer-head">
          <h3>连接与鉴权</h3>
          <button type="button" className="btn btn-ghost drawer-close" onClick={onClose}>
            ✕
          </button>
        </div>
        <div className="drawer-body">
          <label>Agent URL</label>
          <input
            value={url}
            onChange={(e) => setUrl(e.target.value)}
            placeholder={AGENT_URL}
            spellCheck={false}
          />
          <p style={{ fontSize: 11, color: 'var(--muted)', margin: '-6px 0 10px' }}>
            填 Deploy Agent 地址（<code>{AGENT_URL}</code>），不要填 Vite 前端端口
            :5173。
            <button
              type="button"
              className="btn btn-ghost"
              style={{ marginLeft: 6, padding: '2px 8px', fontSize: 11 }}
              onClick={() => setUrl(AGENT_URL)}
            >
              恢复默认
            </button>
          </p>
          <label>Deploy Token</label>
          <input
            type="password"
            value={tok}
            onChange={(e) => setTok(e.target.value)}
          />
          <label>默认目标</label>
          <select value={target} onChange={(e) => setTarget(e.target.value)}>
            <option value="local">本机</option>
            <option value="cloud">云 VPS</option>
          </select>
          <div className="btn-row">
            <button type="button" className="btn btn-primary" onClick={handleSave}>
              保存并验证
            </button>
            <button type="button" className="btn btn-ghost" onClick={handleVerify}>
              仅验证
            </button>
          </div>

          <p style={{ fontSize: 12, color: 'var(--muted)', marginTop: 16 }}>
            Agent：{' '}
            {agentOnline === null
              ? '检测中…'
              : agentOnline
                ? '在线'
                : '离线'}
            {' · '}
            Token：{authOk ? '有效' : authOk === false ? '无效' : '—'}
          </p>
          <div className="btn-row" style={{ marginTop: 8 }}>
            <button type="button" className="btn btn-ghost" onClick={() => void probeAgent()}>
              检测 Agent
            </button>
            <button type="button" className="btn btn-mint" onClick={() => void handleSsh()}>
              测试 SSH
            </button>
          </div>
          <pre className="log-pre" style={{ marginTop: 10, maxHeight: 100 }}>
            {authLog}
          </pre>
          <p style={{ fontSize: 11, color: 'var(--muted)', lineHeight: 1.5 }}>
            Token 与 <code>backend/deploy/config.yaml</code> 一致，非 App 登录。
            详见 <code>docs/dev/deploy-platform.md</code>
          </p>
        </div>
      </aside>
    </div>
  )
}
