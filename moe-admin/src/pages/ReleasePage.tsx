import { useCallback, useEffect, useState } from 'react'
import { PageHead } from '../ui'
import { useDeploy } from '../context/DeployContext'

export function ReleasePage() {
  const { client, token, runJob } = useDeploy()
  const [ghRef, setGhRef] = useState('main')
  const [out, setOut] = useState('—')

  const refresh = useCallback(async () => {
    try {
      const data = await client.releases()
      setOut(JSON.stringify(data, null, 2))
    } catch (e) {
      setOut(e instanceof Error ? e.message : '加载失败')
    }
  }, [client])

  useEffect(() => {
    if (token) void refresh()
  }, [token, refresh])

  return (
    <>
      <PageHead title="应用发布" description="GitHub Actions · flutter-release.yml" />

      <div className="panel">
        <div className="panel-head">
          <h3>GitHub APK</h3>
          <input
            value={ghRef}
            onChange={(e) => setGhRef(e.target.value)}
            style={{
              background: 'var(--panel2)',
              border: '1px solid var(--border)',
              color: 'var(--text)',
              padding: '8px 12px',
              borderRadius: 8,
              fontSize: 12,
              width: 160,
            }}
          />
        </div>
        <div className="panel-body btn-row">
          <button type="button" className="btn btn-ghost" onClick={() => void refresh()}>
            刷新版本
          </button>
          <button
            type="button"
            className="btn btn-primary"
            onClick={() => void runJob('github_trigger_apk', { ref: ghRef })}
          >
            workflow_dispatch
          </button>
          <button
            type="button"
            className="btn btn-ghost"
            onClick={() => void runJob('github_list_workflows')}
          >
            最近构建
          </button>
        </div>
      </div>

      <div className="panel">
        <div className="panel-body">
          <pre className="log-pre" style={{ maxHeight: 480 }}>
            {out}
          </pre>
        </div>
      </div>
    </>
  )
}
