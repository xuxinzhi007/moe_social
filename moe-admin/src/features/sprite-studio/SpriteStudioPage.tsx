import { useEffect, useMemo, useRef, useState, type ChangeEvent } from 'react'
import './sprite-studio.css'
import {
  SPRITE_TEMPLATES,
  type SpriteTemplateId,
} from '../../../../moe-avatar/core/src/spriteTemplates'

type TemplateId = SpriteTemplateId

const TEMPLATES = Object.values(SPRITE_TEMPLATES).map((template) => ({
  ...template,
  name: template.label,
  detail: template.description,
  width: template.canvas.width,
  height: template.canvas.height,
  frames: template.animations[0]?.frameCount ?? 1,
  fps: 8,
}))

const initialTransform = { fit: 'contain' as 'contain' | 'cover', scale: 100, offsetX: 0, offsetY: 0 }

export function SpriteStudioPage() {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const [templateId, setTemplateId] = useState<TemplateId>('character_64')
  const [transform, setTransform] = useState(initialTransform)
  const [source, setSource] = useState<{ name: string; url: string; width: number; height: number } | null>(null)
  const [image, setImage] = useState<HTMLImageElement | null>(null)
  const [message, setMessage] = useState('等待导入一张 PNG')
  const template = TEMPLATES.find((item) => item.id === templateId) ?? TEMPLATES[0]

  useEffect(() => {
    return () => {
      if (source) URL.revokeObjectURL(source.url)
    }
  }, [source])

  useEffect(() => {
    if (!source) {
      setImage(null)
      return
    }
    const nextImage = new Image()
    nextImage.onload = () => setImage(nextImage)
    nextImage.src = source.url
  }, [source])

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const context = canvas.getContext('2d')
    if (!context) return
    const scale = 2
    canvas.width = template.width * scale
    canvas.height = template.height * scale
    context.setTransform(scale, 0, 0, scale, 0, 0)
    context.clearRect(0, 0, template.width, template.height)

    for (let y = 0; y < template.height; y += 16) {
      for (let x = 0; x < template.width; x += 16) {
        context.fillStyle = (x / 16 + y / 16) % 2 === 0 ? '#f3f1f8' : '#e8e5f1'
        context.fillRect(x, y, 16, 16)
      }
    }

    if (image) {
      const imageRatio = image.width / image.height
      const canvasRatio = template.width / template.height
      const baseScale = transform.fit === 'contain'
        ? imageRatio > canvasRatio ? template.width / image.width : template.height / image.height
        : imageRatio > canvasRatio ? template.height / image.height : template.width / image.width
      const drawWidth = image.width * baseScale * (transform.scale / 100)
      const drawHeight = image.height * baseScale * (transform.scale / 100)
      const drawX = (template.width - drawWidth) / 2 + transform.offsetX
      const drawY = (template.height - drawHeight) / 2 + transform.offsetY
      context.imageSmoothingEnabled = false
      context.drawImage(image, drawX, drawY, drawWidth, drawHeight)
    }

    context.strokeStyle = 'rgba(107, 95, 193, .58)'
    context.lineWidth = 1
    context.setLineDash([5, 4])
    context.strokeRect(1, 1, template.width - 2, template.height - 2)
    context.setLineDash([])
    context.strokeStyle = 'rgba(52, 211, 200, .9)'
    context.beginPath()
    context.moveTo(template.anchor.x - 10, template.anchor.y)
    context.lineTo(template.anchor.x + 10, template.anchor.y)
    context.moveTo(template.anchor.x, template.anchor.y - 10)
    context.lineTo(template.anchor.x, template.anchor.y + 10)
    context.stroke()
    context.fillStyle = 'rgba(52, 211, 200, .9)'
    context.font = '10px ui-monospace'
    context.fillText('ANCHOR', template.anchor.x + 8, template.anchor.y - 7)
  }, [image, template, transform])

  const manifest = useMemo(() => ({
    id: source?.name.replace(/\.[^.]+$/, '') || 'draft-sprite',
    kind: template.kind,
    templateId: template.id,
    sheet: source?.name ? `sprites/${source.name}` : '',
    canvas: { width: template.width, height: template.height },
    anchor: {
      x: template.anchor.x + transform.offsetX,
      y: template.anchor.y + transform.offsetY,
    },
    animations: template.animations.map((animation) => ({
      ...animation,
      frameRate: template.fps,
    })),
    frameLayout: template.frameLayout,
    source: {
      path: source?.name ?? '',
      mimeType: 'image/png',
      width: source?.width,
      height: source?.height,
    },
    editor: {
      fit: transform.fit,
      scale: transform.scale / 100,
      offset: [transform.offsetX, transform.offsetY],
      storage: 'browser-memory-only',
    },
  }), [source, template, transform])

  function handleFile(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0]
    if (!file) return
    if (file.type !== 'image/png') {
      setMessage('只支持 PNG 文件')
      return
    }
    if (source) URL.revokeObjectURL(source.url)
    const url = URL.createObjectURL(file)
    const probe = new Image()
    probe.onload = () => {
      setSource({ name: file.name, url, width: probe.width, height: probe.height })
      setMessage('PNG 已载入浏览器内存')
    }
    probe.src = url
  }

  function updateTransform(key: 'scale' | 'offsetX' | 'offsetY', value: number) {
    setTransform((current) => ({ ...current, [key]: value }))
  }

  async function exportDraft() {
    if (!source || !image) {
      setMessage('请先导入一张 PNG')
      return
    }
    const exportCanvas = document.createElement('canvas')
    exportCanvas.width = template.width
    exportCanvas.height = template.height
    const context = exportCanvas.getContext('2d')
    if (!context) return
    const imageRatio = image.width / image.height
    const canvasRatio = template.width / template.height
    const baseScale = transform.fit === 'contain'
      ? imageRatio > canvasRatio ? template.width / image.width : template.height / image.height
      : imageRatio > canvasRatio ? template.height / image.height : template.width / image.width
    const drawWidth = image.width * baseScale * (transform.scale / 100)
    const drawHeight = image.height * baseScale * (transform.scale / 100)
    const drawX = (template.width - drawWidth) / 2 + transform.offsetX
    const drawY = (template.height - drawHeight) / 2 + transform.offsetY
    context.imageSmoothingEnabled = false
    context.drawImage(image, drawX, drawY, drawWidth, drawHeight)
    const blob = await new Promise<Blob | null>((resolve) => exportCanvas.toBlob(resolve, 'image/png'))
    if (!blob) {
      setMessage('PNG 导出失败')
      return
    }
    const id = source.name.replace(/\.[^.]+$/, '') || 'sprite-draft'
    const exportManifest = { ...manifest, id, sheet: `${id}.png` }
    for (const [content, filename] of [
      [blob, `${id}.png`] as const,
      [new Blob([JSON.stringify(exportManifest, null, 2)], { type: 'application/json' }), `${id}.json`] as const,
    ]) {
      const url = URL.createObjectURL(content)
      const link = document.createElement('a')
      link.href = url
      link.download = filename
      link.click()
      URL.revokeObjectURL(url)
    }
    setMessage('已导出模板 PNG + manifest 草稿')
  }

  return (
    <main className="sprite-studio">
      <header className="sprite-studio-head">
        <div>
          <p className="sprite-kicker">ASSET LAB / GENERIC WORKFLOW</p>
          <h2>Sprite Studio</h2>
          <p className="sprite-intro">把一张角色图，校准成可以交给运行时的通用 sprite 草稿。</p>
        </div>
        <span className="sprite-draft-badge"><span />Local draft · 不会上传</span>
      </header>

      <section className="sprite-studio-grid">
        <aside className="sprite-sidebar">
          <div className="sprite-section-label">SOURCE IMAGE</div>
          <label className="sprite-dropzone" htmlFor="sprite-upload">
            <span className="sprite-upload-mark">+</span>
            <strong>{source ? '替换 PNG' : '导入 PNG'}</strong>
            <small>{source ? source.name : '透明背景 · 浏览器内存'}</small>
            <input id="sprite-upload" type="file" accept="image/png" onChange={handleFile} />
          </label>
          {source ? <div className="sprite-source-meta"><span>{source.width} × {source.height}px</span><span>PNG</span></div> : null}

          <div className="sprite-section-label sprite-section-spaced">TEMPLATE</div>
          <div className="sprite-template-list">
            {TEMPLATES.map((item) => (
              <button key={item.id} type="button" className={`sprite-template${templateId === item.id ? ' selected' : ''}`} onClick={() => setTemplateId(item.id as TemplateId)}>
                <span className={`sprite-template-glyph ${item.id}`} />
                <span><strong>{item.name}</strong><small>{item.detail}</small></span>
                {templateId === item.id ? <b>✓</b> : null}
              </button>
            ))}
          </div>

          <div className="sprite-section-label sprite-section-spaced">PLACEMENT</div>
          <label className="sprite-control"><span>Fit mode</span><select value={transform.fit} onChange={(event) => setTransform((current) => ({ ...current, fit: event.target.value as 'contain' | 'cover' }))}><option value="contain">Contain</option><option value="cover">Cover</option></select></label>
          <label className="sprite-control"><span>Scale <output>{transform.scale}%</output></span><input type="range" min="50" max="180" value={transform.scale} onChange={(event) => updateTransform('scale', Number(event.target.value))} /></label>
          <label className="sprite-control"><span>Offset X <output>{transform.offsetX}px</output></span><input type="range" min="-80" max="80" value={transform.offsetX} onChange={(event) => updateTransform('offsetX', Number(event.target.value))} /></label>
          <label className="sprite-control"><span>Offset Y <output>{transform.offsetY}px</output></span><input type="range" min="-80" max="80" value={transform.offsetY} onChange={(event) => updateTransform('offsetY', Number(event.target.value))} /></label>
           <button type="button" className="sprite-reset" onClick={() => setTransform(initialTransform)}>Reset placement</button>
           <button type="button" className="sprite-export" disabled={!source} onClick={() => void exportDraft()}>导出模板草稿</button>
           <p className="sprite-message" role="status">{message}</p>
        </aside>

        <div className="sprite-workbench">
          <div className="sprite-canvas-panel">
            <div className="sprite-panel-top"><div><span className="sprite-eyebrow">LIVE CANVAS</span><strong>{template.width} × {template.height}</strong></div><span className="sprite-guide-key"><i /> anchor <i /> frame edge</span></div>
            <div className="sprite-canvas-wrap"><canvas ref={canvasRef} aria-label="Sprite template preview" /></div>
            <div className="sprite-canvas-caption"><span><i className="cyan-dot" /> Anchor {template.anchor.x}, {template.anchor.y}</span><span><i className="violet-dot" /> Guides are preview-only</span></div>
          </div>

          <div className="sprite-bottom-grid">
            <div className="sprite-frame-panel">
              <div className="sprite-panel-top"><div><span className="sprite-eyebrow">FRAME LAYOUT</span><strong>Idle / {template.frames} frames</strong></div><span className="sprite-fps">{template.fps} FPS · LOOP</span></div>
              <div className="sprite-frames">{Array.from({ length: template.frames }, (_, index) => <div className={`sprite-frame ${index === 0 ? 'active' : ''}`} key={index}><span>{String(index + 1).padStart(2, '0')}</span>{source ? <img src={source.url} alt="" style={{ transform: `translate(${transform.offsetX / 6 + index * 2}px, ${transform.offsetY / 6}px) scale(${transform.scale / 100})` }} /> : <i />}</div>)}</div>
            </div>
            <div className="sprite-manifest-panel"><div className="sprite-panel-top"><div><span className="sprite-eyebrow">MANIFEST PREVIEW</span><strong>generic-sprite.json</strong></div><span className="sprite-json-dot" /></div><pre>{JSON.stringify(manifest, null, 2)}</pre></div>
          </div>
        </div>
      </section>
    </main>
  )
}
