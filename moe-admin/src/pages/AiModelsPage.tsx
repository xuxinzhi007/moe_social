import { useCallback, useEffect, useState } from 'react'
import { AdminTag } from '../components/AdminTag'
import { InferenceStatusBar } from '../components/InferenceStatusBar'
import { useAdminAuth } from '../context/AdminAuthContext'
import { useDeploy } from '../context/DeployContext'
import { DeployApiError } from '../api/deployClient'
import type { MoeInferenceStatusData } from '../api/aiClient'
import { AdminPanel, MonitorPageLayout } from '../ui'

const MODELFILE_KEY = 'Modelfile'

export function AiModelsPage() {
  const { client: adminClient } = useAdminAuth()
  const { client: deployClient, showToast } = useDeploy()
  const [status, setStatus] = useState<MoeInferenceStatusData | null>(null)
  const [statusLoading, setStatusLoading] = useState(false)
  const [refreshKey, setRefreshKey] = useState(0)
  const [editor, setEditor] = useState('')
  const [modelfileLoading, setModelfileLoading] = useState(false)

  const loadInference = useCallback(async () => {
    setStatusLoading(true)
    try {
      const res = await adminClient.getMoeInferenceStatus()
      setStatus(res.success && res.data ? res.data : null)
    } catch (e) {
      setStatus({
        online: false,
        base_url: '',
        models: [],
        default_post_model: '',
        model_loaded: false,
        message: e instanceof DeployApiError ? e.message : '读取失败',
      })
    } finally {
      setStatusLoading(false)
    }
  }, [adminClient])

  useEffect(() => {
    void loadInference()
  }, [loadInference])

  async function loadModelfile() {
    setModelfileLoading(true)
    try {
      const data = await deployClient.remoteConfigGet('cloud', MODELFILE_KEY)
      setEditor(data.content || '')
      showToast('已读取 Modelfile')
    } catch (e) {
      showToast(e instanceof Error ? e.message : '读取失败')
    } finally {
      setModelfileLoading(false)
    }
  }

  async function saveModelfile() {
    if (!editor.trim()) {
      showToast('内容为空')
      return
    }
    if (!window.confirm('确认写入小主机上的 Modelfile？\n将自动 .bak 备份，不会自动重建模型。')) {
      return
    }
    setModelfileLoading(true)
    try {
      await deployClient.remoteConfigPut('cloud', MODELFILE_KEY, editor)
      showToast('Modelfile 已保存')
    } catch (e) {
      showToast(e instanceof Error ? e.message : '保存失败')
    } finally {
      setModelfileLoading(false)
    }
  }

  const models = status?.models ?? []
  const effectiveModel = status?.effective_model || status?.default_post_model || ''

  return (
    <MonitorPageLayout
      title="模型与 Modelfile"
      description="小主机推理模型总览 · 远程 Ollama Modelfile 读写"
      envNote="llm_inference · Modelfile 通过 SSH 白名单读写；LoRA 微调在本机 ollama_web/finetune"
      headActions={
        <button
          type="button"
          className="btn btn-ghost"
          disabled={statusLoading}
          onClick={() => {
            setRefreshKey((v) => v + 1)
            void loadInference()
          }}
        >
          刷新模型
        </button>
      }
    >
      <InferenceStatusBar agentKey="" refreshKey={refreshKey} />

      <AdminPanel title={`小主机模型列表（${models.length}）`}>
        {models.length === 0 ? (
          <p className="muted">
            {statusLoading
              ? '正在读取推理端点…'
              : status?.message || '暂无可读模型，请确认小主机 Ollama 在线。'}
          </p>
        ) : (
          <div className="btn-row" style={{ flexWrap: 'wrap', gap: 8 }}>
            {models.map((name) => {
              const isEffective = name === effectiveModel
              return (
                <AdminTag
                  key={name}
                  label={isEffective ? `${name} · 当前生效` : name}
                  tone={isEffective ? 'ok' : 'neutral'}
                />
              )
            })}
          </div>
        )}
      </AdminPanel>

      <div className="panel remote-config-panel remote-modelfile-panel">
        <div className="panel-head">
          <h3>远程 Ollama Modelfile</h3>
          <div className="remote-config-toolbar">
            <div className="btn-row">
              <button
                type="button"
                className="btn btn-ghost"
                disabled={modelfileLoading}
                onClick={() => void loadModelfile()}
              >
                读取
              </button>
              <button
                type="button"
                className="btn btn-primary"
                disabled={modelfileLoading}
                onClick={() => void saveModelfile()}
              >
                保存到小主机
              </button>
            </div>
          </div>
        </div>
        <div className="panel-body remote-config-body">
          <textarea
            className="config-editor"
            value={editor}
            onChange={(e) => setEditor(e.target.value)}
            spellCheck={false}
            rows={22}
            wrap="off"
            placeholder="点击「读取」查看小主机当前 Modelfile；编辑后保存会自动备份。"
          />
          <p className="config-editor-meta">
            当前文件：{MODELFILE_KEY}
            {editor.length > 0
              ? ` · ${editor.split(/\r?\n/).length} 行 · ${editor.length} 字符`
              : ''}
          </p>
          <p className="config-editor-help">
            这里编辑的是小主机上用于 <code>ollama create</code> 的文件；保存前会自动生成时间戳备份，保存不会自动重建模型。角色数据集与 LoRA 微调在{' '}
            <code>ollama_web/finetune</code>。
          </p>
        </div>
      </div>
    </MonitorPageLayout>
  )
}
