import { useCallback, useEffect, useState } from 'react'
import { AdminFormDrawer } from '../components/AdminFormDrawer'
import { FormField } from '../components/FormField'
import { MonitorPageLayout } from '../ui'
import { useAdminAuth } from '../context/AdminAuthContext'
import { DeployApiError } from '../api/deployClient'

type Release = {
  platform: string
  version_name: string
  version_code: number
  apk_url: string
  changelog: string
  force_update: boolean
  enabled: boolean
  updated_at: string
  updated_by: string
}

const emptyForm = {
  version_name: '',
  version_code: '',
  apk_url: '',
  changelog: '',
  force_update: false,
  enabled: true,
}

export function AppReleasePage() {
  const { client } = useAdminAuth()
  const [configured, setConfigured] = useState(false)
  const [release, setRelease] = useState<Release | null>(null)
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
      const res = await client.getAppRelease('android')
      if (!res.success) {
        setError(res.message || '加载失败')
        setRelease(null)
        setConfigured(false)
        return
      }
      const data = res.data
      setConfigured(Boolean(data?.configured))
      const r = data?.release ?? null
      setRelease(r)
      if (r) {
        setForm({
          version_name: r.version_name || '',
          version_code: r.version_code ? String(r.version_code) : '',
          apk_url: r.apk_url || '',
          changelog: r.changelog || '',
          force_update: Boolean(r.force_update),
          enabled: r.enabled !== false,
        })
      } else {
        setForm(emptyForm)
      }
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
    const code = Number(form.version_code)
    if (!form.version_name.trim()) {
      setFormError('请填写版本名（versionName，如 1.2.3）')
      return
    }
    if (!Number.isInteger(code) || code <= 0) {
      setFormError('versionCode 须为正整数（对应 pubspec.yaml 的 + 后数字）')
      return
    }
    if (!form.apk_url.trim().startsWith('http')) {
      setFormError('请填写完整的 APK 下载 URL（http/https）')
      return
    }
    setSaving(true)
    setFormError('')
    try {
      const res = await client.upsertAppRelease({
        platform: 'android',
        version_name: form.version_name.trim(),
        version_code: code,
        apk_url: form.apk_url.trim(),
        changelog: form.changelog.trim(),
        force_update: form.force_update,
        enabled: form.enabled,
      })
      if (!res.success || !res.data?.release) {
        setFormError(res.message || '保存失败')
        return
      }
      setRelease(res.data.release)
      setConfigured(true)
      setMessage('已保存。客户端将在进入主界面后按 versionCode 检查更新。')
      setDrawerOpen(false)
    } catch (e) {
      setFormError(e instanceof DeployApiError ? e.message : '保存失败')
    } finally {
      setSaving(false)
    }
  }

  return (
    <>
      <MonitorPageLayout
        title="App 版本更新"
        description="配置 Android 侧载更新：版本号、APK 下载地址、强制更新 · 不上传安装包"
        envNote="公开接口 GET /api/public/app-release/latest · 以 versionCode 判断是否有新版本"
        headActions={
          <button
            type="button"
            className="btn btn-primary"
            disabled={loading}
            onClick={() => {
              setFormError('')
              setDrawerOpen(true)
            }}
          >
            {configured ? '编辑版本' : '配置首个版本'}
          </button>
        }
        error={error || undefined}
      >
        {message ? (
          <div className="admin-hint admin-hint-ok" style={{ marginBottom: 12 }}>
            {message}
            <button type="button" className="btn btn-ghost" style={{ marginLeft: 8 }} onClick={() => setMessage('')}>
              关闭
            </button>
          </div>
        ) : null}

        {loading && !release && !configured ? (
          <p className="muted">加载中…</p>
        ) : configured && release ? (
          <div className="config-cards">
            <section className="panel config-card">
              <h3>当前生效配置</h3>
              <dl className="config-dl">
                <div>
                  <dt>平台</dt>
                  <dd>
                    <code>{release.platform}</code>
                  </dd>
                </div>
                <div>
                  <dt>版本名</dt>
                  <dd>
                    <code>{release.version_name || '—'}</code>
                  </dd>
                </div>
                <div>
                  <dt>versionCode</dt>
                  <dd>
                    <code>{release.version_code || '—'}</code>
                  </dd>
                </div>
                <div>
                  <dt>状态</dt>
                  <dd>
                    {release.enabled ? '已启用' : '已停用'}
                    {release.force_update ? ' · 强制更新' : ' · 可稍后'}
                  </dd>
                </div>
                <div>
                  <dt>APK URL</dt>
                  <dd>
                    <code style={{ wordBreak: 'break-all' }}>{release.apk_url || '—'}</code>
                  </dd>
                </div>
                <div>
                  <dt>更新说明</dt>
                  <dd style={{ whiteSpace: 'pre-wrap' }}>{release.changelog || '—'}</dd>
                </div>
                <div>
                  <dt>最近更新</dt>
                  <dd>{release.updated_at || '—'}</dd>
                </div>
              </dl>
              <p className="muted config-hint">
                发版时请提高 pubspec 的 <code>+versionCode</code>，并把 GitHub Release（或其它）APK 直链填到此处。
                GitHub 链接客户端会自动测速镜像；OSS 等直链则直连下载。
              </p>
            </section>
          </div>
        ) : (
          <p className="muted">尚未配置 App 版本。点击「配置首个版本」填写 versionCode 与 APK 下载地址。</p>
        )}
      </MonitorPageLayout>

      <AdminFormDrawer
        open={drawerOpen}
        title="编辑 App 版本"
        subtitle="只填下载 URL，不上传文件 · 保存后立即对客户端生效"
        error={formError}
        saving={saving}
        onClose={() => setDrawerOpen(false)}
        onSave={() => void save()}
        saveLabel="保存并生效"
      >
        <FormField label="版本名 versionName（展示用）">
          <input
            value={form.version_name}
            onChange={(e) => setForm((f) => ({ ...f, version_name: e.target.value }))}
            placeholder="1.2.3"
            spellCheck={false}
          />
        </FormField>
        <FormField label="versionCode（覆盖安装依据，必填正整数）">
          <input
            value={form.version_code}
            onChange={(e) => setForm((f) => ({ ...f, version_code: e.target.value }))}
            placeholder="例如 pubspec 1.2.3+42 则填 42"
            inputMode="numeric"
            spellCheck={false}
          />
        </FormField>
        <FormField label="APK 下载 URL">
          <input
            value={form.apk_url}
            onChange={(e) => setForm((f) => ({ ...f, apk_url: e.target.value }))}
            placeholder="https://github.com/.../releases/download/.../app-release.apk"
            spellCheck={false}
          />
        </FormField>
        <FormField label="更新说明">
          <textarea
            value={form.changelog}
            onChange={(e) => setForm((f) => ({ ...f, changelog: e.target.value }))}
            rows={5}
            placeholder="本次更新内容…"
          />
        </FormField>
        <FormField label="选项">
          <label style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 8 }}>
            <input
              type="checkbox"
              checked={form.enabled}
              onChange={(e) => setForm((f) => ({ ...f, enabled: e.target.checked }))}
            />
            启用（关闭后客户端视为无更新）
          </label>
          <label style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            <input
              type="checkbox"
              checked={form.force_update}
              onChange={(e) => setForm((f) => ({ ...f, force_update: e.target.checked }))}
            />
            强制更新（用户必须更新才能继续使用主功能）
          </label>
        </FormField>
      </AdminFormDrawer>
    </>
  )
}
