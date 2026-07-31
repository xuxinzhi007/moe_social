import { Link } from 'react-router-dom'
import { useAdminAuth } from '../context/AdminAuthContext'
import { usePlatform } from '../context/PlatformContext'
import { useEffect, useState } from 'react'
import { MonitorPageLayout } from '../ui'
import { DeployApiError } from '../api/deployClient'

export function DashboardPage() {
  const { client } = useAdminAuth()
  const { apiTarget, apiTargetLabel, health, healthLoading, refreshHealth } =
    usePlatform()
  const [stats, setStats] = useState<{
    user_total: number
    feishu_enabled: boolean
    server_time: string
  } | null>(null)
  const [statsErr, setStatsErr] = useState('')

  useEffect(() => {
    let cancelled = false
    async function load() {
      setStatsErr('')
      try {
        const res = await client.dashboard()
        if (cancelled) return
        if (res.success && res.data) {
          setStats(res.data)
        } else {
          setStats(null)
          setStatsErr(res.message || '无法加载统计数据')
        }
      } catch (e) {
        if (!cancelled) {
          setStats(null)
          setStatsErr(e instanceof DeployApiError ? e.message : '无法连接 API')
        }
      }
    }
    void load()
    return () => {
      cancelled = true
    }
  }, [client])

  const currentApi =
    apiTarget === 'cloud' ? health?.cloud_api : health?.local_api

  return (
    <MonitorPageLayout
      title="管理员工作台"
      description={
        <>
          统一入口 · 当前数据环境 <code>{apiTargetLabel}</code>
          {currentApi?.base_url ? (
            <>
              {' '}
              · <code>{currentApi.base_url}</code>
            </>
          ) : null}
        </>
      }
      headActions={
        <button
          type="button"
          className="btn btn-primary"
          disabled={healthLoading}
          onClick={() => void refreshHealth()}
        >
          {healthLoading ? '检测中…' : '刷新状态'}
        </button>
      }
    >
      <div className="admin-metrics page-insight-strip">
        <div className="metric">
          <span className="label">Deploy Agent</span>
          <span className="value">
            {health?.agent?.online ? (
              <span className="tag tag-ok">在线</span>
            ) : (
              <span className="tag tag-fail">离线</span>
            )}
          </span>
        </div>
        <div className="metric">
          <span className="label">本机 API</span>
          <span className="value">
            {health?.local_api?.online ? (
              <span className="tag tag-ok">可达</span>
            ) : (
              <span className="tag tag-fail">不可达</span>
            )}
          </span>
        </div>
        <div className="metric">
          <span className="label">云端 API</span>
          <span className="value">
            {health?.cloud_api?.online ? (
              <span className="tag tag-ok">可达</span>
            ) : (
              <span className="tag tag-fail">不可达</span>
            )}
          </span>
        </div>
        <div className="metric">
          <span className="label">注册用户</span>
          <span className="value">{stats ? `${stats.user_total}` : '—'}</span>
        </div>
        <div className="metric">
          <span className="label">飞书通知</span>
          <span className="value">
            {stats ? (
              stats.feishu_enabled ? (
                <span className="tag tag-ok">已启用</span>
              ) : (
                <span className="tag tag-pending">未启用</span>
              )
            ) : (
              '—'
            )}
          </span>
        </div>
      </div>

      {statsErr ? (
        <div className="admin-hint admin-hint-warn">
          <strong>当前环境暂不可用：</strong>
          {statsErr}
          <br />
          请运行 <code>scripts/start-admin.ps1</code> 一键启动，或在顶栏切换到可达的环境。
        </div>
      ) : null}

      <div className="admin-quick panel">
        <div className="panel-head">
          <h3>快捷入口</h3>
        </div>
        <div className="panel-body admin-quick-grid">
          <Link to="/biz/users" className="quick-card">
            <strong>App 用户</strong>
            <span>列表 · 角色 · VIP</span>
          </Link>
          <Link to="/biz/announcements" className="quick-card">
            <strong>公告管理</strong>
            <span>运营公告发布</span>
          </Link>
          <Link to="/infra/platform" className="quick-card">
            <strong>平台治理</strong>
            <span>连接 · 图库 · 数据地图</span>
          </Link>
          <Link to="/infra/deploy" className="quick-card">
            <strong>运维部署</strong>
            <span>构建 · 发布 · Docker</span>
          </Link>
          <Link to="/ai/agents" className="quick-card">
            <strong>AI 角色酒馆</strong>
            <span>角色 · 配置 · 审核</span>
          </Link>
          <Link to="/biz/content/posts" className="quick-card">
            <strong>动态审核</strong>
            <span>列表 · 筛选 · 下架</span>
          </Link>
        </div>
      </div>

      {stats?.server_time ? (
        <p className="loading-hint" style={{ marginTop: 12 }}>
          API 时间：{stats.server_time}
        </p>
      ) : null}
    </MonitorPageLayout>
  )
}
