import { useCallback, useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { AdminFormDrawer } from '../components/AdminFormDrawer'
import { DataEnvBar } from '../components/DataEnvBar'
import { FormField } from '../components/FormField'
import { useAdminAuth } from '../context/AdminAuthContext'
import { DeployApiError } from '../api/deployClient'

type ConfigData = {
  public_api_base_url: string
  api_public_base_url: string
  image_public_base_url: string
  image_local_dir: string
  image_max_bytes: number
  config_file: string
  requires_restart: boolean
}

const emptyForm = {
  public_api_base_url: '',
  api_public_base_url: '',
  image_public_base_url: '',
  image_local_dir: '',
  image_max_bytes: '1073741824',
}

function formatBytes(n: number) {
  if (!n) return '0（不限制）'
  const gb = n / (1024 * 1024 * 1024)
  if (gb >= 1) return `${gb.toFixed(2)} GB (${n.toLocaleString()} B)`
  const mb = n / (1024 * 1024)
  return `${mb.toFixed(0)} MB (${n.toLocaleString()} B)`
}

export function AppConfigPage() {
  const { client } = useAdminAuth()
  const [data, setData] = useState<ConfigData | null>(null)
  const [form, setForm] = useState(emptyForm)
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [message, setMessage] = useState('')
  const [drawerOpen, setDrawerOpen] = useState(false)
  const [formError, setFormError] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const res = await client.getRuntimeConfig()
      if (!res.success || !res.data) {
        setError(res.message || '加载失败')
        setData(null)
        return
      }
      setData(res.data)
      setForm({
        public_api_base_url: res.data.public_api_base_url || '',
        api_public_base_url: res.data.api_public_base_url || '',
        image_public_base_url: res.data.image_public_base_url || '',
        image_local_dir: res.data.image_local_dir || '',
        image_max_bytes: String(res.data.image_max_bytes || 0),
      })
    } catch (e) {
      setError(e instanceof DeployApiError ? e.message : '加载失败')
    } finally {
      setLoading(false)
    }
  }, [client])

  useEffect(() => {
    void load()
  }, [load])

  async function save() {
    const maxBytes = Number(form.image_max_bytes)
    if (form.image_max_bytes.trim() && (Number.isNaN(maxBytes) || maxBytes < 0)) {
      setFormError('云空间上限须为非负整数（字节）')
      return
    }
    setSaving(true)
    setFormError('')
    try {
      const res = await client.updateRuntimeConfig({
        public_api_base_url: form.public_api_base_url.trim(),
        update_public_api_base_url: true,
        api_public_base_url: form.api_public_base_url.trim(),
        update_api_public_base_url: true,
        image_public_base_url: form.image_public_base_url.trim(),
        update_image_public_base_url: true,
        image_local_dir: form.image_local_dir.trim(),
        update_image_local_dir: true,
        image_max_bytes: maxBytes,
        update_image_max_bytes: true,
      })
      if (!res.success || !res.data) {
        setFormError(res.message || '保存失败')
        return
      }
      setData(res.data)
      setMessage('配置已写入 config.yaml，图片与 client-config 已热更新')
      setDrawerOpen(false)
    } catch (e) {
      setFormError(e instanceof DeployApiError ? e.message : '保存失败')
    } finally {
      setSaving(false)
    }
  }

  return (
    <>
      <div className="page-head page-head-row">
        <div>
          <h2>应用配置</h2>
          <p>管理 App API 地址、云端图库 URL 与存储配额 · 写入 backend/config/config.yaml</p>
        </div>
        <button
          type="button"
          className="btn btn-primary"
          disabled={loading}
          onClick={() => {
            setFormError('')
            setDrawerOpen(true)
          }}
        >
          编辑配置
        </button>
      </div>

      <DataEnvBar note="修改后立即影响 GET /api/public/client-config 与图片 URL 拼接" />

      {message ? (
        <div className="admin-hint admin-hint-ok" style={{ marginBottom: 12 }}>
          {message}
          <button type="button" className="btn btn-ghost" style={{ marginLeft: 8 }} onClick={() => setMessage('')}>
            关闭
          </button>
        </div>
      ) : null}

      {error ? <p className="text-danger">{error}</p> : null}

      {loading && !data ? (
        <p className="muted">加载中…</p>
      ) : data ? (
        <div className="config-cards">
          <section className="panel config-card">
            <h3>App 与 API</h3>
            <dl className="config-dl">
              <div>
                <dt>client-config 公网 API</dt>
                <dd>
                  <code>{data.public_api_base_url || '—'}</code>
                </dd>
              </div>
              <div>
                <dt>OAuth / 对外 API 根</dt>
                <dd>
                  <code>{data.api_public_base_url || '—'}</code>
                </dd>
              </div>
            </dl>
            <p className="muted config-hint">
              App 冷启动通过 <code>/api/public/client-config</code> 拉取权威 API 地址。
            </p>
          </section>

          <section className="panel config-card">
            <h3>云端图库</h3>
            <dl className="config-dl">
              <div>
                <dt>图片 PublicBaseUrl</dt>
                <dd>
                  <code>{data.image_public_base_url || '（空 = 按请求 Host 自动拼接）'}</code>
                </dd>
              </div>
              <div>
                <dt>服务端存储目录</dt>
                <dd>
                  <code>{data.image_local_dir || '—'}</code>
                </dd>
              </div>
              <div>
                <dt>用户云空间上限</dt>
                <dd>{formatBytes(data.image_max_bytes)}</dd>
              </div>
            </dl>
            <p className="muted config-hint">
              用户头像、发帖配图、云图库上传均走 <code>/api/images/</code> 路径。
            </p>
          </section>

          <section className="panel config-card config-card-meta">
            <h3>配置文件</h3>
            <p>
              <code className="id-cell id-cell-mono">{data.config_file || '—'}</code>
            </p>
            <div className="btn-row" style={{ marginTop: 12 }}>
              <Link className="btn btn-ghost btn-sm" to="/users">
                管理用户头像
              </Link>
              <Link className="btn btn-ghost btn-sm" to="/system/data">
                数据目录
              </Link>
            </div>
          </section>
        </div>
      ) : null}

      <AdminFormDrawer
        open={drawerOpen}
        title="编辑应用配置"
        subtitle="留空 PublicBaseUrl 表示按请求 Host 自动拼图片 URL"
        error={formError}
        saving={saving}
        onClose={() => setDrawerOpen(false)}
        onSave={() => void save()}
        saveLabel="保存到 config.yaml"
      >
        <FormField label="client-config 公网 API（app_client.public_api_base_url）">
          <input
            value={form.public_api_base_url}
            onChange={(e) => setForm((f) => ({ ...f, public_api_base_url: e.target.value }))}
            placeholder="http://47.106.175.49:8888"
            spellCheck={false}
          />
        </FormField>
        <FormField label="OAuth / 对外 API 根（api.public_base_url）">
          <input
            value={form.api_public_base_url}
            onChange={(e) => setForm((f) => ({ ...f, api_public_base_url: e.target.value }))}
            placeholder="http://47.106.175.49:8888"
            spellCheck={false}
          />
        </FormField>
        <FormField label="图片 PublicBaseUrl（Image.PublicBaseUrl）">
          <input
            value={form.image_public_base_url}
            onChange={(e) => setForm((f) => ({ ...f, image_public_base_url: e.target.value }))}
            placeholder="留空则自动按 Host 拼接"
            spellCheck={false}
          />
        </FormField>
        <FormField label="图片存储目录（Image.LocalDir）">
          <input
            value={form.image_local_dir}
            onChange={(e) => setForm((f) => ({ ...f, image_local_dir: e.target.value }))}
            placeholder="/app/data/images"
            spellCheck={false}
          />
        </FormField>
        <FormField label="云空间上限（字节，0 = 不限制）">
          <input
            value={form.image_max_bytes}
            onChange={(e) => setForm((f) => ({ ...f, image_max_bytes: e.target.value }))}
            placeholder="1073741824"
            inputMode="numeric"
          />
          <p className="muted" style={{ fontSize: 11, marginTop: 4 }}>
            1 GB = 1073741824
          </p>
        </FormField>
      </AdminFormDrawer>
    </>
  )
}
