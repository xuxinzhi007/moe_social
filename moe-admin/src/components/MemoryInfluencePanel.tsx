import { Link } from 'react-router-dom'
import type { MoeBrainGenerationMeta } from '../api/adminClient'

type Props = {
  meta?: MoeBrainGenerationMeta | null
}

/** 说明记忆如何进入 Bot 发帖（与工具调用审计区分） */
export function MemoryInfluencePanel({ meta }: Props) {
  if (!meta) return null

  const hasPrompt = meta.prompt_memory_lines > 0
  const contextPct =
    meta.context_used_pct && meta.context_used_pct > 0
      ? `${Math.round(meta.context_used_pct * 100)}%`
      : null

  return (
    <section className="panel memory-influence-panel">
      <header className="platform-section-head memory-influence-head">
        <div>
          <h3>记忆如何参与生成</h3>
          <p className="muted">{meta.note}</p>
        </div>
        <Link className="btn btn-ghost btn-sm" to="/app/moe-tools?tab=tools">
          查看全部 8 个 Moe 工具 →
        </Link>
      </header>
      <div className="admin-metrics page-insight-strip">
        <div className="metric">
          <div className="label">同步记忆条</div>
          <div className="value">{meta.memories_synced}</div>
        </div>
        <div className="metric">
          <div className="label">自传注入条</div>
          <div className="value">{meta.episodes_in_prompt}</div>
        </div>
        <div className="metric">
          <div className="label">提示词行数</div>
          <div className="value">{meta.prompt_memory_lines}</div>
        </div>
        <div className="metric">
          <div className="label">发帖走 memory 工具</div>
          <div className="value">{meta.post_uses_tool_memory ? '是' : '否'}</div>
        </div>
        {meta.prompt_est_tokens && meta.prompt_est_tokens > 0 ? (
          <div className="metric">
            <div className="label">提示词约 tokens</div>
            <div className="value">{meta.prompt_est_tokens.toLocaleString()}</div>
          </div>
        ) : null}
        {meta.context_limit && meta.context_limit > 0 ? (
          <div className="metric">
            <div className="label">上下文窗口</div>
            <div className="value">
              {meta.context_limit.toLocaleString()}
              {contextPct ? (
                <span className="summary-note" style={{ display: 'block', fontSize: 11 }}>
                  已用约 {contextPct}
                </span>
              ) : null}
            </div>
          </div>
        ) : null}
      </div>
      {hasPrompt && meta.prompt_preview ? (
        <details className="memory-prompt-preview">
          <summary>查看将注入【Bot 记忆】的预览</summary>
          <pre>{meta.prompt_preview}</pre>
        </details>
      ) : (
        <p className="muted" style={{ margin: 0, fontSize: 12 }}>
          暂无记忆注入预览：发帖仍会使用标签策略与近期动态，可在试跑成功后查看自传与记忆库。
        </p>
      )}
    </section>
  )
}
