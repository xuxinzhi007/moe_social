import {
  AVATAR_TEMPLATE_EXAMPLES,
  AVATAR_TEMPLATE_PRESETS,
  type AvatarTemplateId,
  type AvatarTemplatePreset,
} from '../editor/templateLibrary'

type Props = {
  onLoadTemplate: (templateId: AvatarTemplateId, mode: 'example' | 'blank') => void
}

const CATEGORY_ORDER = ['基础角色', '叠穿模板', '道具模板', '脸饰模板', '整角色替换', '姿态变体']

function categoryIndex(category: string): number {
  const idx = CATEGORY_ORDER.indexOf(category)
  return idx >= 0 ? idx : CATEGORY_ORDER.length
}

function groupPresets() {
  const groups = new Map<string, AvatarTemplatePreset[]>()
  for (const preset of Object.values(AVATAR_TEMPLATE_PRESETS)) {
    const list = groups.get(preset.category)
    if (list) list.push(preset)
    else groups.set(preset.category, [preset])
  }
  return [...groups.entries()].sort(
    ([a], [b]) => categoryIndex(a) - categoryIndex(b),
  )
}

export function TemplateLibraryPanel({ onLoadTemplate }: Props) {
  const groups = groupPresets()

  return (
    <div style={{ display: 'grid', gap: 12 }}>
      {groups.map(([category, presets]) => (
        <section key={category} style={{ border: '1px solid #eee', borderRadius: 8, padding: 10 }}>
          <div style={{ fontWeight: 600, marginBottom: 8 }}>
            {category} · {presets.length}
          </div>
          <div style={{ display: 'grid', gap: 10, gridTemplateColumns: 'repeat(auto-fill, minmax(260px, 1fr))' }}>
            {presets.map((preset) => {
              const example = AVATAR_TEMPLATE_EXAMPLES.find((entry) => entry.templateId === preset.id)
              return (
                <div key={preset.id} style={{ border: '1px solid #eee', borderRadius: 8, padding: 10, background: '#fff' }}>
                  <div style={{ fontWeight: 600, marginBottom: 4 }}>{preset.label}</div>
                  <div className="muted" style={{ fontSize: 11, marginBottom: 8 }}>{preset.description}</div>
                  <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap', marginBottom: 8 }}>
                    {Object.keys(preset.animations).map((anim) => (
                      <span key={anim} className="btn" style={{ fontSize: 10, cursor: 'default' }}>
                        {anim}
                      </span>
                    ))}
                    <span className="btn" style={{ fontSize: 10, cursor: 'default' }}>
                      base {preset.baseKeys.length}
                    </span>
                    <span className="btn" style={{ fontSize: 10, cursor: 'default' }}>
                      slot {preset.slotKeys.length}
                    </span>
                  </div>
                  <div className="muted" style={{ fontSize: 10, marginBottom: 8, wordBreak: 'break-word' }}>
                    {preset.composeOrder.join(' · ')}
                  </div>
                  <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                    <button type="button" className="btn primary" style={{ fontSize: 11 }} onClick={() => onLoadTemplate(preset.id, 'example')}>
                      载入示例
                    </button>
                    <button type="button" className="btn" style={{ fontSize: 11 }} onClick={() => onLoadTemplate(preset.id, 'blank')}>
                      新建骨架
                    </button>
                  </div>
                  {example ? (
                    <div className="muted" style={{ fontSize: 10, marginTop: 8 }}>
                      示例：{example.label}
                    </div>
                  ) : null}
                </div>
              )
            })}
          </div>
        </section>
      ))}
    </div>
  )
}
