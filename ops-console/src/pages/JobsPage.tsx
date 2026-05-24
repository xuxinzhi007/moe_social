import { useEffect, useState } from 'react'
import { StatusTag } from '../components/StatusTag'
import { useDeploy } from '../context/DeployContext'
import type { DeployJob } from '../types/deploy'

export function JobsPage() {
  const { jobs, refreshJobs, activeJob, client } = useDeploy()
  const [selected, setSelected] = useState<DeployJob | null>(null)
  const [detail, setDetail] = useState<DeployJob | null>(null)

  useEffect(() => {
    void refreshJobs()
  }, [refreshJobs])

  useEffect(() => {
    if (activeJob) setSelected(activeJob)
  }, [activeJob])

  useEffect(() => {
    if (!selected) {
      setDetail(null)
      return
    }
    void client.getJob(selected.id).then((d) => setDetail(d.job))
  }, [selected, client])

  const show = detail || selected

  return (
    <>
      <div className="page-head">
        <h2>任务审计</h2>
        <p>Deploy Agent 内存队列（最近任务）</p>
      </div>

      <div className="split">
        <div className="panel">
          <div className="panel-head">
            <h3>任务队列</h3>
            <button type="button" className="btn btn-ghost" onClick={() => void refreshJobs()}>
              刷新
            </button>
          </div>
          <div className="panel-body" style={{ padding: 0 }}>
            <table className="jobs-table">
              <thead>
                <tr>
                  <th>类型</th>
                  <th>状态</th>
                  <th>目标</th>
                </tr>
              </thead>
              <tbody>
                {jobs.length === 0 ? (
                  <tr>
                    <td colSpan={3} style={{ color: 'var(--muted)' }}>
                      暂无任务
                    </td>
                  </tr>
                ) : (
                  jobs.map((j) => (
                    <tr
                      key={j.id}
                      className={selected?.id === j.id ? 'selected' : ''}
                      onClick={() => setSelected(j)}
                    >
                      <td>{j.type}</td>
                      <td>
                        <StatusTag status={j.status} />
                      </td>
                      <td>{j.target || '—'}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>

        <div className="panel">
          <div className="panel-head">
            <h3>任务详情</h3>
            {show ? (
              <span style={{ fontSize: 11, color: 'var(--muted)' }}>{show.id.slice(0, 8)}</span>
            ) : null}
          </div>
          <div className="panel-body">
            {show ? (
              <>
                <p style={{ fontSize: 12, margin: '0 0 8px' }}>
                  <StatusTag status={show.status} /> {show.type} · {show.target}
                </p>
                <pre className="log-pre" style={{ maxHeight: 400 }}>
                  {show.log || '—'}
                </pre>
              </>
            ) : (
              <p style={{ color: 'var(--muted)', fontSize: 13 }}>选择左侧任务查看日志</p>
            )}
          </div>
        </div>
      </div>
    </>
  )
}
