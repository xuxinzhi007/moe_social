import { useEffect, useMemo, useRef, useState, type ChangeEvent, type PointerEvent } from 'react'
import './sprite-studio.css'
import {
  SPRITE_TEMPLATES,
  type SpriteTemplateId,
} from '../../../../moe-avatar/core/src/spriteTemplates'
import {
  validateSpriteResource,
} from '../../../../moe-avatar/core/src/spriteValidation'
import type { SpriteResource } from '../../../../moe-avatar/core/src/spriteTypes'
import { removeImageBackground } from './backgroundCleanup'
import {
  extractVideoFrames,
  MAX_VIDEO_DURATION_SECONDS,
  MAX_VIDEO_FRAMES,
  readVideoMetadata,
} from './videoFrameExtraction'

type TemplateId = SpriteTemplateId
type FitMode = 'contain' | 'cover'

const TEMPLATES = Object.values(SPRITE_TEMPLATES).map((template) => ({
  ...template,
  name: template.label,
  detail: template.description,
  width: template.canvas.width,
  height: template.canvas.height,
  frames: template.animations[0]?.frameCount ?? 1,
  fps: 8,
}))

const initialTransform = { fit: 'contain' as FitMode, scale: 100, offsetX: 0, offsetY: 0 }
type FrameAsset = { name: string; url: string; width: number; height: number; image: HTMLImageElement; sourceName?: string; mimeType?: string }
type FrameTransform = { scale: number; offsetX: number; offsetY: number }
type Interaction = { kind: 'image' | 'anchor'; startX: number; startY: number; offsetX: number; offsetY: number; anchorX: number; anchorY: number }

export function SpriteStudioPage() {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const interactionRef = useRef<Interaction | null>(null)
  const [templateId, setTemplateId] = useState<TemplateId>('character_64')
  const [fit, setFit] = useState<FitMode>(initialTransform.fit)
  const [frameTransforms, setFrameTransforms] = useState<FrameTransform[]>([])
  const [anchor, setAnchor] = useState({ x: 32, y: 60 })
  const [frames, setFrames] = useState<FrameAsset[]>([])
  const [preCleanupFrames, setPreCleanupFrames] = useState<FrameAsset[] | null>(null)
  const [activeFrame, setActiveFrame] = useState(0)
  const [cleaning, setCleaning] = useState(false)
  const [videoFile, setVideoFile] = useState<File | null>(null)
  const [videoDuration, setVideoDuration] = useState(3)
  const [videoFrameCount, setVideoFrameCount] = useState(12)
  const [extracting, setExtracting] = useState(false)
  const [extractionProgress, setExtractionProgress] = useState(0)
  const [message, setMessage] = useState('等待导入一张 PNG')
  const [showHelp, setShowHelp] = useState(false)
  const frameUrlsRef = useRef(new Set<string>())
  const template = TEMPLATES.find((item) => item.id === templateId) ?? TEMPLATES[0]
  const source = frames[0] ?? null
  const image = frames[activeFrame]?.image ?? null
  const transform = frameTransforms[activeFrame] ?? initialTransform
  const frameCapacity = template.frameLayout.columns * template.frameLayout.rows
  const frameDuration = Math.round(1000 / template.fps)
  const previewWidth = template.frameLayout.frameWidth
  const previewHeight = template.frameLayout.frameHeight

  function trackFrameUrl(url: string) {
    frameUrlsRef.current.add(url)
    return url
  }

  function releaseFrameUrls(framesToRelease: readonly FrameAsset[]) {
    framesToRelease.forEach((frame) => releaseFrameUrl(frame.url))
  }

  function releaseFrameUrl(url: string) {
    if (!frameUrlsRef.current.delete(url)) return
    URL.revokeObjectURL(url)
  }

  function releaseAllFrameUrls() {
    frameUrlsRef.current.forEach((url) => URL.revokeObjectURL(url))
    frameUrlsRef.current.clear()
  }

  useEffect(() => releaseAllFrameUrls, [])

  useEffect(() => {
    setAnchor(template.anchor)
    setActiveFrame(0)
    if (frames.length <= frameCapacity) return
    releaseFrameUrls(frames.slice(frameCapacity))
    setFrames(frames.slice(0, frameCapacity))
    setFrameTransforms((current) => current.slice(0, frameCapacity))
  }, [template])

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const context = canvas.getContext('2d')
    if (!context) return
    const scale = 2
    canvas.width = previewWidth * scale
    canvas.height = previewHeight * scale
    context.setTransform(scale, 0, 0, scale, 0, 0)
    context.clearRect(0, 0, previewWidth, previewHeight)

    for (let y = 0; y < previewHeight; y += 16) {
      for (let x = 0; x < previewWidth; x += 16) {
        context.fillStyle = (x / 16 + y / 16) % 2 === 0 ? '#f3f1f8' : '#e8e5f1'
        context.fillRect(x, y, 16, 16)
      }
    }

    if (image) {
      const imageRatio = image.width / image.height
      const canvasRatio = previewWidth / previewHeight
      const baseScale = fit === 'contain'
        ? imageRatio > canvasRatio ? previewWidth / image.width : previewHeight / image.height
        : imageRatio > canvasRatio ? previewHeight / image.height : previewWidth / image.width
      const drawWidth = image.width * baseScale * (transform.scale / 100)
      const drawHeight = image.height * baseScale * (transform.scale / 100)
      const drawX = (previewWidth - drawWidth) / 2 + transform.offsetX
      const drawY = (previewHeight - drawHeight) / 2 + transform.offsetY
      context.imageSmoothingEnabled = false
      context.drawImage(image, drawX, drawY, drawWidth, drawHeight)
    }

    context.strokeStyle = 'rgba(107, 95, 193, .58)'
    context.lineWidth = 1
    context.setLineDash([5, 4])
    context.strokeRect(1, 1, previewWidth - 2, previewHeight - 2)
    context.setLineDash([])
    context.strokeStyle = 'rgba(52, 211, 200, .9)'
    context.beginPath()
    context.arc(anchor.x, anchor.y, 7, 0, Math.PI * 2)
    context.moveTo(anchor.x - 11, anchor.y)
    context.lineTo(anchor.x + 11, anchor.y)
    context.moveTo(anchor.x, anchor.y - 11)
    context.lineTo(anchor.x, anchor.y + 11)
    context.stroke()
    context.fillStyle = 'rgba(52, 211, 200, .9)'
    context.font = '10px ui-monospace'
    context.fillText('DRAG ANCHOR', anchor.x + 9, anchor.y - 9)
  }, [anchor, fit, image, previewHeight, previewWidth, transform])

  const manifest = useMemo(() => {
    const resource: SpriteResource = {
      id: (source?.sourceName ?? source?.name ?? 'draft-sprite').replace(/\.[^.]+$/, '') || 'draft-sprite',
      kind: template.kind,
      templateId: template.id,
      status: 'draft',
       sheet: source?.name ? `sprites/${source.name}` : '',
      directions: template.frameLayout.mode === 'directional_grid'
        ? ['up', 'left', 'down', 'right'].slice(0, template.frameLayout.rows)
        : [],
      canvas: { width: template.width, height: template.height },
      anchor: { x: anchor.x, y: anchor.y },
      animations: template.animations.map((animation) => ({
        ...animation,
        frameCount: frames.length > 0 ? frames.length : animation.frameCount,
        frameRate: template.fps,
      })),
      frameLayout: template.frameLayout,
       source: {
         path: source?.sourceName ?? source?.name ?? '',
       mimeType: source?.mimeType ?? 'image/png',
        width: source?.width,
        height: source?.height,
      },
      frameAdjustments: frameTransforms.map((frameTransform, frame) => ({
        frame,
        offsetX: frameTransform.offsetX,
        offsetY: frameTransform.offsetY,
        scale: frameTransform.scale / 100,
      })),
    }
    return {
      ...resource,
      editor: {
        fit,
        storage: 'browser-memory-only',
      },
    }
  }, [anchor, fit, frameTransforms, frames.length, source, template])
  const validation = useMemo(() => validateSpriteResource(manifest), [manifest])

  function handleFiles(event: ChangeEvent<HTMLInputElement>) {
    const selectedFiles = Array.from(event.target.files ?? [])
    if (!selectedFiles.length) return
    if (selectedFiles.some((file) => file.type !== 'image/png')) {
      setMessage('只支持 PNG 文件')
      return
    }
    const files = selectedFiles.slice(0, frameCapacity)
    if (selectedFiles.length > frameCapacity) setMessage(`当前模板最多载入 ${frameCapacity} 帧`)
    const pendingUrls: string[] = []
    Promise.all(files.map((file) => new Promise<FrameAsset>((resolve, reject) => {
       const url = trackFrameUrl(URL.createObjectURL(file))
       pendingUrls.push(url)
      const probe = new Image()
      probe.onload = () => resolve({ name: file.name, url, width: probe.width, height: probe.height, image: probe })
       probe.onerror = () => { releaseFrameUrl(url); reject(new Error('image-load-failed')) }
      probe.src = url
     }))).then((loadedFrames) => {
      releaseFrameUrls(frames)
      if (preCleanupFrames) releaseFrameUrls(preCleanupFrames)
      setFrames(loadedFrames)
      setPreCleanupFrames(null)
      setFrameTransforms(loadedFrames.map(() => ({ scale: initialTransform.scale, offsetX: initialTransform.offsetX, offsetY: initialTransform.offsetY })))
      setActiveFrame(0)
       setVideoFile(null)
       setMessage(`${loadedFrames.length} 个 PNG 已载入浏览器内存，可在画布上拖动校准`)
    }).catch(() => {
      pendingUrls.forEach((url) => releaseFrameUrl(url))
      setMessage('PNG 载入失败')
    })
    event.target.value = ''
  }

  async function handleVideoFile(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0]
    event.target.value = ''
    if (!file) return
    setVideoFile(null)
    setExtractionProgress(0)
    try {
      const metadata = await readVideoMetadata(file)
      setVideoFile(file)
      setVideoDuration(Math.min(MAX_VIDEO_DURATION_SECONDS, Math.max(0.01, metadata.duration)))
      setVideoFrameCount(Math.min(MAX_VIDEO_FRAMES, frameCapacity))
      setMessage(`已选择视频 ${metadata.width} × ${metadata.height}px，可提取最多 ${Math.min(MAX_VIDEO_FRAMES, frameCapacity)} 帧`)
    } catch {
      setMessage('视频读取失败，请选择浏览器支持的本地视频')
    }
  }

  async function extractSelectedVideo() {
    if (!videoFile || extracting) return
    setExtracting(true)
    setExtractionProgress(0)
    try {
      const extractedFrames = await extractVideoFrames(videoFile, {
        duration: videoDuration,
       frameCount: Math.min(videoFrameCount, frameCapacity),
       onProgress: (completed, total) => setExtractionProgress(Math.round((completed / total) * 100)),
       })
      extractedFrames.forEach((frame) => trackFrameUrl(frame.url))
      releaseFrameUrls(frames)
      if (preCleanupFrames) releaseFrameUrls(preCleanupFrames)
      setFrames(extractedFrames)
      setPreCleanupFrames(null)
      setFrameTransforms(extractedFrames.map(() => ({ scale: initialTransform.scale, offsetX: initialTransform.offsetX, offsetY: initialTransform.offsetY })))
      setActiveFrame(0)
      setMessage(`${extractedFrames.length} 帧已提取到浏览器内存，可在画布上拖动校准`)
    } catch {
      setMessage('视频帧提取失败，请尝试较短的视频或较少帧数')
    } finally {
      setExtracting(false)
    }
  }

  function updateTransform(key: keyof FrameTransform, value: number) {
    setFrameTransforms((current) => {
      const next = [...current]
      next[activeFrame] = { ...(next[activeFrame] ?? initialTransform), [key]: value }
      return next
    })
  }

  function moveActiveFrame(direction: -1 | 1) {
    const nextIndex = activeFrame + direction
    if (nextIndex < 0 || nextIndex >= frames.length) return
    if (preCleanupFrames) {
      releaseFrameUrls(preCleanupFrames)
      setPreCleanupFrames(null)
    }
    setFrames((current) => {
      const next = [...current]
      const [frame] = next.splice(activeFrame, 1)
      next.splice(nextIndex, 0, frame)
      return next
    })
    setFrameTransforms((current) => {
      const next = [...current]
      const [frameTransform] = next.splice(activeFrame, 1)
      next.splice(nextIndex, 0, frameTransform ?? initialTransform)
      return next
    })
    setActiveFrame(nextIndex)
    setMessage(`已将第 ${activeFrame + 1} 帧移至第 ${nextIndex + 1} 位`)
  }

  function deleteActiveFrame() {
    const frame = frames[activeFrame]
    if (!frame) return
    if (preCleanupFrames) {
      releaseFrameUrls(preCleanupFrames)
      setPreCleanupFrames(null)
    }
    releaseFrameUrls([frame])
    setFrames((current) => current.filter((_, index) => index !== activeFrame))
    setFrameTransforms((current) => current.filter((_, index) => index !== activeFrame))
    setActiveFrame((current) => Math.min(current, Math.max(0, frames.length - 2)))
    setMessage(`已删除第 ${activeFrame + 1} 帧`)
  }

  async function cleanupBackground() {
    if (!frames.length) return
    const cleanedUrls: string[] = []
    setCleaning(true)
    try {
       const cleaned = await Promise.all(frames.map(async (frame) => {
        const canvas = removeImageBackground(frame.image, { colorDistance: 36 })
        const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, 'image/png'))
        if (!blob) throw new Error('cleanup-export-failed')
         const url = trackFrameUrl(URL.createObjectURL(blob))
         cleanedUrls.push(url)
        const image = await new Promise<HTMLImageElement>((resolve, reject) => {
          const next = new Image()
          next.onload = () => resolve(next)
          next.onerror = () => reject(new Error('cleanup-load-failed'))
          next.src = url
        })
        return { ...frame, url, image }
      }))
       if (preCleanupFrames) releaseFrameUrls(preCleanupFrames)
       setPreCleanupFrames(frames)
       setFrames(cleaned)
       setMessage('已清理边缘连通背景；请检查发丝和半透明边缘')
      } catch {
        cleanedUrls.forEach((url) => releaseFrameUrl(url))
       setMessage('背景清理失败，请保留原图重试')
    } finally {
      setCleaning(false)
    }
  }

  function restorePreCleanupFrames() {
    if (!preCleanupFrames) return
    releaseFrameUrls(frames)
    setFrames(preCleanupFrames)
    setPreCleanupFrames(null)
    setMessage('已恢复清理前的原始帧')
  }

  function resetCurrentFrame() {
    updateTransform('scale', initialTransform.scale)
    updateTransform('offsetX', initialTransform.offsetX)
    updateTransform('offsetY', initialTransform.offsetY)
  }

  function handleCanvasPointerDown(event: PointerEvent<HTMLCanvasElement>) {
    const canvas = canvasRef.current
    if (!canvas) return
    const bounds = canvas.getBoundingClientRect()
    const x = (event.clientX - bounds.left) * previewWidth / bounds.width
    const y = (event.clientY - bounds.top) * previewHeight / bounds.height
    const anchorDistance = Math.hypot(x - anchor.x, y - anchor.y)
    const kind = anchorDistance <= 11 ? 'anchor' : 'image'
    interactionRef.current = { kind, startX: x, startY: y, offsetX: transform.offsetX, offsetY: transform.offsetY, anchorX: anchor.x, anchorY: anchor.y }
    canvas.setPointerCapture(event.pointerId)
  }

  function handleCanvasPointerMove(event: PointerEvent<HTMLCanvasElement>) {
    const interaction = interactionRef.current
    const canvas = canvasRef.current
    if (!interaction || !canvas) return
    const bounds = canvas.getBoundingClientRect()
    const x = (event.clientX - bounds.left) * previewWidth / bounds.width
    const y = (event.clientY - bounds.top) * previewHeight / bounds.height
    const deltaX = x - interaction.startX
    const deltaY = y - interaction.startY
    if (interaction.kind === 'anchor') {
      setAnchor({ x: Math.round(Math.max(0, Math.min(previewWidth, interaction.anchorX + deltaX))), y: Math.round(Math.max(0, Math.min(previewHeight, interaction.anchorY + deltaY))) })
    } else {
      updateTransform('offsetX', Math.round(interaction.offsetX + deltaX))
      updateTransform('offsetY', Math.round(interaction.offsetY + deltaY))
    }
  }

  function handleCanvasPointerUp(event: PointerEvent<HTMLCanvasElement>) {
    interactionRef.current = null
    canvasRef.current?.releasePointerCapture(event.pointerId)
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
    context.imageSmoothingEnabled = false
    const exportFrames = frames.length > 0 ? frames : [frames[activeFrame]]
    exportFrames.forEach((frame, index) => {
      const cellWidth = template.frameLayout.frameWidth
      const cellHeight = template.frameLayout.frameHeight
      const imageRatio = frame.width / frame.height
      const cellRatio = cellWidth / cellHeight
      const frameTransform = frameTransforms[index] ?? initialTransform
      const baseScale = fit === 'contain'
        ? imageRatio > cellRatio ? cellWidth / frame.width : cellHeight / frame.height
        : imageRatio > cellRatio ? cellHeight / frame.height : cellWidth / frame.width
      const drawWidth = frame.width * baseScale * (frameTransform.scale / 100)
      const drawHeight = frame.height * baseScale * (frameTransform.scale / 100)
      const column = index % template.frameLayout.columns
      const row = Math.floor(index / template.frameLayout.columns)
      const cellX = column * cellWidth
      const cellY = row * cellHeight
      const drawX = cellX + (cellWidth - drawWidth) / 2 + frameTransform.offsetX
      const drawY = cellY + (cellHeight - drawHeight) / 2 + frameTransform.offsetY
      context.drawImage(frame.image, drawX, drawY, drawWidth, drawHeight)
    })
    const blob = await new Promise<Blob | null>((resolve) => exportCanvas.toBlob(resolve, 'image/png'))
    if (!blob) {
      setMessage('PNG 导出失败')
      return
    }
     const id = (source.sourceName ?? source.name).replace(/\.[^.]+$/, '') || 'sprite-draft'
    const exportManifest = {
      ...manifest,
      id,
      sheet: `${id}.png`,
      animations: manifest.animations.map((animation) => ({
        ...animation,
        frameCount: exportFrames.length,
      })),
    }
    const exportValidation = validateSpriteResource(exportManifest)
    if (!exportValidation.ok) {
      setMessage(`导出被阻止：${exportValidation.issues[0]?.message ?? 'manifest 无效'}`)
      return
    }
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
          <p className="sprite-kicker">AI 精灵资源工作台</p>
          <h2>Sprite Studio</h2>
          <p className="sprite-intro">把 AI 生成的图片或视频整理成可用于游戏的精灵资源。</p>
        </div>
        <div className="sprite-head-actions">
          <button type="button" className="sprite-help-button" onClick={() => setShowHelp(true)}>使用说明</button>
          <span className="sprite-draft-badge"><span />本地草稿 · 不会上传</span>
        </div>
      </header>

      <section className="sprite-studio-grid">
        <aside className="sprite-sidebar">
          <div className="sprite-section-label">输入图片</div>
           <label className="sprite-dropzone" htmlFor="sprite-upload">
            <span className="sprite-upload-mark">+</span>
             <strong>{source ? '替换 PNG 帧' : '导入 PNG 帧'}</strong>
             <small>{source ? `${frames.length} / ${frameCapacity} 帧 · ${source.name}` : `最多 ${frameCapacity} 个 · 透明背景`}</small>
             <input id="sprite-upload" type="file" accept="image/png" multiple onChange={handleFiles} />
           </label>
           <div className="sprite-video-import">
              <div className="sprite-section-label">输入视频</div>
              <label className="sprite-video-input" htmlFor="sprite-video-upload"><span>{videoFile ? videoFile.name : '选择本地视频'}</span><b>选择</b><input id="sprite-video-upload" type="file" accept="video/*" onChange={handleVideoFile} /></label>
             <div className="sprite-video-controls">
                <label className="sprite-control"><span>Duration <output>{videoDuration.toFixed(2)}s</output></span><input type="range" min="0.01" max={MAX_VIDEO_DURATION_SECONDS} step="0.01" value={videoDuration} onChange={(event) => setVideoDuration(Number(event.target.value))} disabled={!videoFile || extracting} /></label>
               <label className="sprite-control"><span>Frame count <output>{Math.min(videoFrameCount, frameCapacity)}</output></span><input type="range" min="1" max={Math.min(MAX_VIDEO_FRAMES, frameCapacity)} value={Math.min(videoFrameCount, frameCapacity)} onChange={(event) => setVideoFrameCount(Number(event.target.value))} disabled={!videoFile || extracting} /></label>
             </div>
             <button type="button" className="sprite-video-extract" disabled={!videoFile || extracting} onClick={() => void extractSelectedVideo()}>{extracting ? `提取中 ${extractionProgress}%` : '提取视频帧'}</button>
             {extracting ? <progress className="sprite-video-progress" value={extractionProgress} max="100" aria-label="视频帧提取进度" /> : null}
           </div>
           {source ? <div className="sprite-source-meta"><span>{source.width} × {source.height}px</span><span>PNG</span></div> : null}
            {source ? <div className="sprite-cleanup-actions"><button type="button" className="sprite-cleanup" disabled={cleaning || Boolean(preCleanupFrames)} onClick={() => void cleanupBackground()}>{cleaning ? '处理中…' : '清理边缘背景'}</button>{preCleanupFrames ? <button type="button" className="sprite-restore" disabled={cleaning} onClick={restorePreCleanupFrames}>恢复清理前帧</button> : null}</div> : null}

           <div className="sprite-section-label sprite-section-spaced">选择模板</div>
          <div className="sprite-template-list">
            {TEMPLATES.map((item) => (
              <button key={item.id} type="button" className={`sprite-template${templateId === item.id ? ' selected' : ''}`} onClick={() => setTemplateId(item.id as TemplateId)}>
                <span className={`sprite-template-glyph ${item.id}`} />
                <span><strong>{item.name}</strong><small>{item.detail}</small></span>
                {templateId === item.id ? <b>✓</b> : null}
              </button>
            ))}
          </div>

           <div className="sprite-section-label sprite-section-spaced">调整位置</div>
           <label className="sprite-control"><span>Fit mode</span><select value={fit} onChange={(event) => setFit(event.target.value as 'contain' | 'cover')}><option value="contain">Contain</option><option value="cover">Cover</option></select></label>
          <label className="sprite-control"><span>Scale <output>{transform.scale}%</output></span><input type="range" min="50" max="180" value={transform.scale} onChange={(event) => updateTransform('scale', Number(event.target.value))} /></label>
          <label className="sprite-control"><span>Offset X <output>{transform.offsetX}px</output></span><input type="range" min="-80" max="80" value={transform.offsetX} onChange={(event) => updateTransform('offsetX', Number(event.target.value))} /></label>
           <label className="sprite-control"><span>Offset Y <output>{transform.offsetY}px</output></span><input type="range" min="-80" max="80" value={transform.offsetY} onChange={(event) => updateTransform('offsetY', Number(event.target.value))} /></label>
           <div className="sprite-anchor-readout"><span>Anchor</span><output>{anchor.x}, {anchor.y}</output></div>
           <button type="button" className="sprite-reset" onClick={() => { setFrameTransforms(frames.map(() => ({ scale: initialTransform.scale, offsetX: initialTransform.offsetX, offsetY: initialTransform.offsetY }))); setAnchor(template.anchor) }}>Reset placement</button>
            <button type="button" className="sprite-export" disabled={!source || !validation.ok} onClick={() => void exportDraft()}>导出模板草稿</button>
           {source && !validation.ok ? <div className="sprite-validation-error">{validation.issues.map((issue) => <div key={`${issue.code}-${issue.path}`}>{issue.message}</div>)}</div> : null}
           {source && validation.ok ? <div className="sprite-validation-ok">模板校验通过</div> : null}
           <p className="sprite-message" role="status">{message}</p>
        </aside>

        <div className="sprite-workbench">
          <div className="sprite-canvas-panel">
             <div className="sprite-panel-top"><div><span className="sprite-eyebrow">实时预览</span><strong>{previewWidth} × {previewHeight}</strong></div><span className="sprite-guide-key"><i /> 锚点 <i /> 画布边界</span></div>
             <div className="sprite-canvas-wrap"><canvas ref={canvasRef} aria-label="Sprite template preview" onPointerDown={handleCanvasPointerDown} onPointerMove={handleCanvasPointerMove} onPointerUp={handleCanvasPointerUp} onPointerCancel={handleCanvasPointerUp} /></div>
             <div className="sprite-canvas-caption"><span><i className="cyan-dot" /> Anchor {anchor.x}, {anchor.y} · drag handle</span><span><i className="violet-dot" /> Drag image to move offset</span></div>
          </div>

          <div className="sprite-bottom-grid">
            <div className="sprite-frame-panel">
               <div className="sprite-panel-top"><div><span className="sprite-eyebrow">帧序列</span><strong>动画帧 / {template.frames} 格</strong></div><span className="sprite-fps">{template.fps} FPS · 循环</span></div>
                 <div className="sprite-timeline-tools">
                   <span><b>{frames.length ? `${frames.length} frames` : 'No frames yet'}</b><small>{frameDuration} ms each · {template.fps} FPS</small></span>
                   <div className="sprite-frame-actions">
                       <button type="button" disabled={!image || activeFrame === 0} onClick={() => moveActiveFrame(-1)} aria-label="上一帧">上一帧</button>
                       <button type="button" disabled={!image || activeFrame === frames.length - 1} onClick={() => moveActiveFrame(1)} aria-label="下一帧">下一帧</button>
                       <button type="button" className="danger" disabled={!image} onClick={deleteActiveFrame}>删除当前帧</button>
                   </div>
                 </div>
                 <div className="sprite-frames">{Array.from({ length: Math.max(template.frames, frames.length) }, (_, index) => <button type="button" disabled={!frames[index]} className={`sprite-frame ${index === activeFrame ? 'active' : ''}`} key={index} onClick={() => setActiveFrame(index)}><span>{String(index + 1).padStart(2, '0')}</span>{frames[index] ? <><img src={frames[index].url} alt="" style={{ transform: `translate(${(frameTransforms[index]?.offsetX ?? 0) / 6}px, ${(frameTransforms[index]?.offsetY ?? 0) / 6}px) scale(${(frameTransforms[index]?.scale ?? 100) / 100})` }} /><small>{frameDuration} ms</small></> : <i />}</button>)}</div>
                {image ? <div className="sprite-frame-adjustments"><div className="sprite-adjustment-head"><span>FRAME {String(activeFrame + 1).padStart(2, '0')} ADJUSTMENT</span><button type="button" onClick={resetCurrentFrame}>Reset current frame</button></div><div className="sprite-adjustment-controls"><label className="sprite-control"><span>Scale <output>{transform.scale}%</output></span><input type="range" min="50" max="180" value={transform.scale} onChange={(event) => updateTransform('scale', Number(event.target.value))} /></label><label className="sprite-control"><span>Offset X <output>{transform.offsetX}px</output></span><input type="range" min="-80" max="80" value={transform.offsetX} onChange={(event) => updateTransform('offsetX', Number(event.target.value))} /></label><label className="sprite-control"><span>Offset Y <output>{transform.offsetY}px</output></span><input type="range" min="-80" max="80" value={transform.offsetY} onChange={(event) => updateTransform('offsetY', Number(event.target.value))} /></label></div></div> : null}
            </div>
             <div className="sprite-manifest-panel"><div className="sprite-panel-top"><div><span className="sprite-eyebrow">导出清单</span><strong>generic-sprite.json</strong></div><span className="sprite-json-dot" /></div><pre>{JSON.stringify(manifest, null, 2)}</pre></div>
          </div>
        </div>
      </section>
      {showHelp ? (
        <div className="sprite-help-backdrop" role="presentation" onClick={() => setShowHelp(false)}>
          <section className="sprite-help-modal" role="dialog" aria-modal="true" aria-labelledby="sprite-help-title" onClick={(event) => event.stopPropagation()}>
            <div className="sprite-help-head">
              <div><span className="sprite-eyebrow">快速开始</span><h3 id="sprite-help-title">如何整理一张精灵资源</h3></div>
              <button type="button" onClick={() => setShowHelp(false)} aria-label="关闭帮助">×</button>
            </div>
            <ol className="sprite-help-steps">
              <li>导入一张或多张透明 PNG。多张图片会按顺序成为动画帧。</li>
              <li>也可以选择本地视频，设置时长和帧数，再点击“提取视频帧”。</li>
              <li>选择合适模板。角色模板定义画布大小和锚点，不要求使用 LPC 的部位结构。</li>
              <li>在实时预览中拖动图片调整位置，拖动青色锚点调整脚底或中心点。</li>
              <li>在帧序列中切换帧，分别调整每一帧；需要时可以删除或重新排序。</li>
              <li>背景不是透明时，点击“清理边缘背景”。如果效果不理想，可以恢复清理前帧。</li>
              <li>确认校验通过后，点击“导出模板草稿”，会下载 PNG 和 JSON 两个文件。</li>
            </ol>
            <p className="sprite-help-note">当前草稿只保存在浏览器内存中，刷新页面后会清空。导出后请保留 PNG 和 JSON，后续它们会作为游戏运行时资源。</p>
            <button type="button" className="sprite-help-close" onClick={() => setShowHelp(false)}>开始使用</button>
          </section>
        </div>
      ) : null}
    </main>
  )
}
