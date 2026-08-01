import { useEffect, useMemo, useRef, useState, type ChangeEvent, type PointerEvent } from 'react'
import JSZip from 'jszip'
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
  generateSyntheticMotionFrames,
  type SyntheticMotionDirection,
  type SyntheticMotionMetadata,
  type SyntheticMotionPreset,
} from './syntheticMotionFrames'
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
type FrameAsset = { name: string; url: string; width: number; height: number; image: HTMLImageElement; sourceName?: string; mimeType?: string; metadata?: SyntheticMotionMetadata }
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
  const [previewFrame, setPreviewFrame] = useState(0)
  const [isPlaying, setIsPlaying] = useState(false)
  const [dragFrameIndex, setDragFrameIndex] = useState<number | null>(null)
  const [cleaning, setCleaning] = useState(false)
  const [videoFile, setVideoFile] = useState<File | null>(null)
  const [videoMetadataDuration, setVideoMetadataDuration] = useState<number | null>(null)
  const [videoStartTime, setVideoStartTime] = useState(0)
  const [videoEndTime, setVideoEndTime] = useState(3)
  const [videoFps, setVideoFps] = useState(8)
  const [sheetColumns, setSheetColumns] = useState(4)
  const [extracting, setExtracting] = useState(false)
  const [extractionProgress, setExtractionProgress] = useState(0)
  const [message, setMessage] = useState('等待导入一张 PNG')
  const [showHelp, setShowHelp] = useState(false)
  const [motionPreset, setMotionPreset] = useState<SyntheticMotionPreset>('idle')
  const [motionDirection, setMotionDirection] = useState<SyntheticMotionDirection | ''>('')
  const [generatingMotion, setGeneratingMotion] = useState(false)
  const frameUrlsRef = useRef(new Set<string>())
  const template = TEMPLATES.find((item) => item.id === templateId) ?? TEMPLATES[0]
  const source = frames[0] ?? null
  const displayFrame = isPlaying ? previewFrame : activeFrame
  const image = frames[displayFrame]?.image ?? null
  const transform = frameTransforms[displayFrame] ?? initialTransform
  const sourceFrameCapacity = MAX_VIDEO_FRAMES
  const templateFrameTarget = Math.min(sourceFrameCapacity, sheetColumns * template.frameLayout.rows)
  const sheetRows = Math.max(template.frameLayout.rows, Math.ceil(Math.max(1, frames.length) / sheetColumns))
  const playbackFps = videoFile ? videoFps : template.fps
  const frameDuration = Math.round(1000 / playbackFps)
  const previewWidth = template.frameLayout.frameWidth
  const previewHeight = template.frameLayout.frameHeight
  const videoSourceLimit = videoMetadataDuration === null
    ? MAX_VIDEO_DURATION_SECONDS
    : Math.min(MAX_VIDEO_DURATION_SECONDS, videoMetadataDuration)
  const videoCapacityEnd = videoStartTime + (Math.max(1, sourceFrameCapacity) - 1) / videoFps
  const videoEndLimit = Math.max(videoStartTime, Math.min(videoSourceLimit, videoCapacityEnd))
  const effectiveVideoEndTime = Math.min(Math.max(videoEndTime, videoStartTime), videoEndLimit)
  const videoInterval = 1 / videoFps
  const requestedVideoFrameCount = Math.min(
    sourceFrameCapacity,
    Math.max(1, Math.floor((effectiveVideoEndTime - videoStartTime) * videoFps) + 1),
  )
  const videoRangeNotice = videoFile && videoMetadataDuration !== null && videoEndLimit < videoMetadataDuration
    ? `结束时间已限制为 ${videoEndLimit.toFixed(2)}s：${videoMetadataDuration > MAX_VIDEO_DURATION_SECONDS ? `工具最多支持 ${MAX_VIDEO_DURATION_SECONDS}s，` : ''}当前最多提取 ${sourceFrameCapacity} 帧`
    : null

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
    setPreviewFrame(0)
    setIsPlaying(false)
    setSheetColumns(template.frameLayout.columns)
  }, [template])

  useEffect(() => {
    if (!isPlaying || frames.length < 2) return
    const timer = window.setInterval(() => {
      setPreviewFrame((current) => (current + 1) % frames.length)
    }, Math.max(30, Math.round(1000 / playbackFps)))
    return () => window.clearInterval(timer)
  }, [frames.length, isPlaying, playbackFps])

  useEffect(() => {
    if (!videoFile) return
    setVideoEndTime((current) => Math.min(Math.max(current, videoStartTime), videoEndLimit))
  }, [sourceFrameCapacity, videoEndLimit, videoFile, videoStartTime, videoFps])

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
    const frameLayout = {
      ...template.frameLayout,
      columns: sheetColumns,
      rows: sheetRows,
    }
    const resource: SpriteResource = {
      id: (source?.sourceName ?? source?.name ?? 'draft-sprite').replace(/\.[^.]+$/, '') || 'draft-sprite',
      kind: template.kind,
      templateId: template.id,
      status: 'draft',
       sheet: source?.name ? `sprites/${source.name}` : '',
      directions: template.frameLayout.mode === 'directional_grid'
        ? ['up', 'left', 'down', 'right'].slice(0, template.frameLayout.rows)
        : [],
      canvas: {
        width: frameLayout.frameWidth * frameLayout.columns,
        height: frameLayout.frameHeight * frameLayout.rows,
      },
      anchor: { x: anchor.x, y: anchor.y },
      animations: template.animations.map((animation) => ({
        ...animation,
        frameCount: frames.length > 0 ? frames.length : animation.frameCount,
        frameRate: playbackFps,
      })),
      frameLayout,
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
      ...(source?.metadata ? {
        generation: {
          mode: 'synthetic_transform' as const,
          action: source.metadata.preset,
          quality: 'approximation',
          approximation: 'canvas transform only; no pose generation',
          sourceFrame: 0,
        },
      } : { generation: { mode: videoFile ? 'video_extracted' as const : 'source_frames' as const } }),
    }
    return {
      ...resource,
      editor: {
        fit,
        storage: 'browser-memory-only',
      },
    }
  }, [anchor, fit, frameTransforms, frames.length, playbackFps, sheetColumns, sheetRows, source, template])
  const validation = useMemo(() => validateSpriteResource(manifest), [manifest])

  function handleFiles(event: ChangeEvent<HTMLInputElement>) {
    const selectedFiles = Array.from(event.target.files ?? [])
    if (!selectedFiles.length) return
    if (selectedFiles.some((file) => file.type !== 'image/png')) {
      setMessage('只支持 PNG 文件')
      return
    }
    const files = selectedFiles.slice(0, sourceFrameCapacity)
    if (selectedFiles.length > sourceFrameCapacity) setMessage(`最多载入 ${sourceFrameCapacity} 帧，超出部分已忽略`)
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
       setPreviewFrame(0)
       setIsPlaying(false)
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
      const sourceLimit = Math.min(MAX_VIDEO_DURATION_SECONDS, metadata.duration)
      const capacityEnd = (Math.max(1, sourceFrameCapacity) - 1) / videoFps
      setVideoFile(file)
      setVideoMetadataDuration(metadata.duration)
      setVideoStartTime(0)
      setVideoEndTime(Math.min(3, sourceLimit, capacityEnd))
      setMessage(`已选择视频 ${metadata.width} × ${metadata.height}px，原始时长 ${metadata.duration.toFixed(2)}s；时间范围和帧数会按限制自动调整`)
    } catch {
      setMessage('视频读取失败，请选择浏览器支持的本地视频')
    }
  }

  function updateVideoStartTime(value: number) {
    if (!Number.isFinite(value)) return
    const nextStartTime = Math.max(0, Math.min(videoSourceLimit, value))
    setVideoStartTime(nextStartTime)
    setVideoEndTime((current) => Math.min(Math.max(current, nextStartTime), nextStartTime + (Math.max(1, sourceFrameCapacity) - 1) / videoFps, videoSourceLimit))
  }

  function updateVideoEndTime(value: number) {
    if (!Number.isFinite(value)) return
    setVideoEndTime(Math.max(videoStartTime, Math.min(videoEndLimit, value)))
  }

  function updateVideoFps(value: number) {
    if (!Number.isFinite(value)) return
    const nextFps = Math.max(1, Math.min(60, value))
    setVideoFps(nextFps)
    setVideoEndTime((current) => Math.min(current, videoStartTime + (Math.max(1, sourceFrameCapacity) - 1) / nextFps, videoSourceLimit))
  }

  async function extractSelectedVideo() {
    if (!videoFile || extracting) return
    setExtracting(true)
    setExtractionProgress(0)
    try {
       const extractedFrames = await extractVideoFrames(videoFile, {
        startTime: videoStartTime,
        endTime: effectiveVideoEndTime,
        frameCount: requestedVideoFrameCount,
        onProgress: (completed, total) => setExtractionProgress(Math.round((completed / total) * 100)),
        })
      extractedFrames.forEach((frame) => trackFrameUrl(frame.url))
      releaseFrameUrls(frames)
      if (preCleanupFrames) releaseFrameUrls(preCleanupFrames)
      setFrames(extractedFrames)
      setPreCleanupFrames(null)
       setFrameTransforms(extractedFrames.map(() => ({ scale: initialTransform.scale, offsetX: initialTransform.offsetX, offsetY: initialTransform.offsetY })))
       setActiveFrame(0)
       setPreviewFrame(0)
       setIsPlaying(false)
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

  function reorderFrames(fromIndex: number, toIndex: number) {
    if (fromIndex === toIndex || fromIndex < 0 || toIndex < 0 || fromIndex >= frames.length || toIndex >= frames.length) return
    if (preCleanupFrames) {
      releaseFrameUrls(preCleanupFrames)
      setPreCleanupFrames(null)
    }
    setFrames((current) => {
      const next = [...current]
      const [frame] = next.splice(fromIndex, 1)
      next.splice(toIndex, 0, frame)
      return next
    })
    setFrameTransforms((current) => {
      const next = [...current]
      const [frameTransform] = next.splice(fromIndex, 1)
      next.splice(toIndex, 0, frameTransform ?? initialTransform)
      return next
    })
    const remap = (index: number) => {
      if (index === fromIndex) return toIndex
      if (fromIndex < toIndex && index > fromIndex && index <= toIndex) return index - 1
      if (fromIndex > toIndex && index >= toIndex && index < fromIndex) return index + 1
      return index
    }
    setActiveFrame(remap(activeFrame))
    setPreviewFrame(remap(previewFrame))
    setMessage(`已将第 ${fromIndex + 1} 帧移至第 ${toIndex + 1} 位`)
  }

  function fillFramesToTemplate() {
    if (frames.length === 0 || frames.length >= templateFrameTarget) return
    if (preCleanupFrames) {
      releaseFrameUrls(preCleanupFrames)
      setPreCleanupFrames(null)
    }
    const forward = frames.map((_, index) => index)
    const cycle = frames.length > 1
      ? [...forward, ...forward.slice(1, -1).reverse()]
      : forward
    const nextFrames = [...frames]
    const nextTransforms = [...frameTransforms]
    let cursor = 0
    while (nextFrames.length < templateFrameTarget) {
      const sourceIndex = cycle[cursor % cycle.length]
      nextFrames.push(frames[sourceIndex])
      nextTransforms.push({ ...(frameTransforms[sourceIndex] ?? initialTransform) })
      cursor += 1
    }
    setFrames(nextFrames)
    setFrameTransforms(nextTransforms)
    setPreviewFrame(activeFrame)
    setMessage(`已用往返方式补齐到 ${templateFrameTarget} 帧；新增帧会复用已有画面`)
  }

  function moveActiveFrame(direction: -1 | 1) {
    const nextIndex = activeFrame + direction
    if (nextIndex < 0 || nextIndex >= frames.length) return
    reorderFrames(activeFrame, nextIndex)
  }

  function reverseFrames() {
    if (frames.length < 2) return
    if (preCleanupFrames) {
      releaseFrameUrls(preCleanupFrames)
      setPreCleanupFrames(null)
    }
    setFrames((current) => [...current].reverse())
    setFrameTransforms((current) => [...current].reverse())
    setActiveFrame((current) => frames.length - 1 - current)
    setPreviewFrame((current) => frames.length - 1 - current)
    setMessage('已反转帧序，请播放预览确认动作是否连贯')
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
    setPreviewFrame((current) => Math.min(current, Math.max(0, frames.length - 2)))
    if (frames.length <= 1) setIsPlaying(false)
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

  async function generateMotion() {
    if (!image || frames.length !== 1 || videoFile || generatingMotion) return
    setGeneratingMotion(true)
    try {
      const generatedFrames = await generateSyntheticMotionFrames(image, {
        preset: motionPreset,
        direction: motionDirection || undefined,
        horizontalFlip: motionDirection === 'left',
        sourceName: source?.sourceName ?? source?.name,
      })
      generatedFrames.forEach((frame) => trackFrameUrl(frame.url))
      releaseFrameUrls(frames)
      if (preCleanupFrames) releaseFrameUrls(preCleanupFrames)
      setFrames(generatedFrames)
      setPreCleanupFrames(null)
      setFrameTransforms(generatedFrames.map(() => ({ scale: initialTransform.scale, offsetX: initialTransform.offsetX, offsetY: initialTransform.offsetY })))
      setActiveFrame(0)
      setPreviewFrame(0)
      setIsPlaying(false)
      setMessage(`${motionPreset} 动作草稿已生成，共 ${generatedFrames.length} 帧；这是位移动效近似，不是姿态生成`)
    } catch {
      setMessage('动作草稿生成失败，请先导入一张图片')
    } finally {
      setGeneratingMotion(false)
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
    if (isPlaying) return
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
    exportCanvas.width = template.frameLayout.frameWidth * sheetColumns
    exportCanvas.height = template.frameLayout.frameHeight * sheetRows
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
      const column = index % sheetColumns
      const row = Math.floor(index / sheetColumns)
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

  async function exportFramesZip() {
    if (!frames.length) return
    try {
      const zip = new JSZip()
      for (const [index, frame] of frames.entries()) {
        const response = await fetch(frame.url)
        if (!response.ok) throw new Error('frame-download-failed')
        zip.file(`frame_${String(index + 1).padStart(3, '0')}.png`, await response.blob())
      }
      const blob = await zip.generateAsync({ type: 'blob' })
      const url = URL.createObjectURL(blob)
      const link = document.createElement('a')
      link.href = url
      link.download = `${(source?.sourceName ?? source?.name ?? 'sprite').replace(/\.[^.]+$/, '')}_frames.zip`
      link.click()
      URL.revokeObjectURL(url)
      setMessage('已导出原始帧 ZIP')
    } catch {
      setMessage('原始帧 ZIP 导出失败')
    }
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
             <small>{source ? `${frames.length} / ${sourceFrameCapacity} 帧 · ${source.name}` : `最多 ${sourceFrameCapacity} 个 · 透明背景`}</small>
             <input id="sprite-upload" type="file" accept="image/png" multiple onChange={handleFiles} />
           </label>
           <div className="sprite-video-import">
              <div className="sprite-section-label">输入视频</div>
              <label className="sprite-video-input" htmlFor="sprite-video-upload"><span>{videoFile ? videoFile.name : '选择本地视频'}</span><b>选择</b><input id="sprite-video-upload" type="file" accept="video/*" onChange={handleVideoFile} /></label>
              <div className="sprite-video-controls">
                <label className="sprite-control"><span>Start time <output>{videoStartTime.toFixed(2)}s</output></span><input type="number" min="0" max={videoSourceLimit} step="0.01" value={videoStartTime} onChange={(event) => updateVideoStartTime(Number(event.target.value))} disabled={!videoFile || extracting} /></label>
                <label className="sprite-control"><span>End time <output>{effectiveVideoEndTime.toFixed(2)}s</output></span><input type="number" min={videoStartTime} max={videoEndLimit} step="0.01" value={effectiveVideoEndTime} onChange={(event) => updateVideoEndTime(Number(event.target.value))} disabled={!videoFile || extracting} /></label>
                <label className="sprite-control"><span>FPS <output>{videoFps}</output></span><input type="number" min="1" max="60" step="1" value={videoFps} onChange={(event) => updateVideoFps(Number(event.target.value))} disabled={!videoFile || extracting} /></label>
              </div>
              <div className="sprite-video-summary"><span>Interval <b>{videoInterval.toFixed(3)}s</b></span><span>Requested frames <b>{requestedVideoFrameCount}</b></span></div>
              {videoMetadataDuration !== null ? <div className="sprite-video-meta">源视频时长 {videoMetadataDuration.toFixed(2)}s · 结束时间上限 {videoEndLimit.toFixed(2)}s</div> : null}
              {videoRangeNotice ? <p className="sprite-video-notice" role="status">{videoRangeNotice}</p> : null}
             <button type="button" className="sprite-video-extract" disabled={!videoFile || extracting} onClick={() => void extractSelectedVideo()}>{extracting ? `提取中 ${extractionProgress}%` : '提取视频帧'}</button>
             {extracting ? <progress className="sprite-video-progress" value={extractionProgress} max="100" aria-label="视频帧提取进度" /> : null}
           </div>
            {source ? <div className="sprite-source-meta"><span>{source.width} × {source.height}px</span><span>PNG</span></div> : null}
            {source && frames.length === 1 && !videoFile ? <div className="sprite-motion-box"><div className="sprite-section-label">单图动作草稿</div><p>用轻微位移、缩放和旋转生成基础动效，不会改变角色姿态。</p><div className="sprite-motion-controls"><select value={motionPreset} onChange={(event) => setMotionPreset(event.target.value as SyntheticMotionPreset)}><option value="idle">待机</option><option value="walk">行走近似</option><option value="attack">攻击近似</option><option value="hit">受击近似</option></select><select value={motionDirection} onChange={(event) => setMotionDirection(event.target.value as SyntheticMotionDirection | '')}><option value="">原方向</option><option value="right">向右</option><option value="left">向左（水平翻转）</option></select></div><button type="button" className="sprite-motion-generate" disabled={generatingMotion} onClick={() => void generateMotion()}>{generatingMotion ? '生成中…' : '生成 4 帧动作草稿'}</button></div> : null}
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
                    <span><b>{frames.length ? `${frames.length} 帧` : '还没有帧'}</b><small>{frameDuration} ms / 帧 · {playbackFps} FPS · {isPlaying ? `播放第 ${previewFrame + 1} 帧` : '已暂停'}</small></span>
                    <label className="sprite-layout-control"><span>排列列数</span><input type="number" min="1" max="64" disabled={template.frameLayout.mode === 'directional_grid'} value={sheetColumns} onChange={(event) => setSheetColumns(Math.max(1, Math.min(64, Number(event.target.value) || 1)))} /><small>共 {sheetRows} 行</small></label>
                    <div className="sprite-frame-actions">
                        <button type="button" className="play" disabled={frames.length < 2} onClick={() => { setIsPlaying((current) => !current); setPreviewFrame(activeFrame) }}>{isPlaying ? '暂停预览' : '播放预览'}</button>
                        <button type="button" disabled={!image} onClick={() => void exportFramesZip()}>导出帧 ZIP</button>
                        <button type="button" disabled={frames.length < 2} onClick={reverseFrames}>反转帧序</button>
                        <button type="button" className="fill" disabled={!image || frames.length >= templateFrameTarget} onClick={fillFramesToTemplate}>{frames.length < templateFrameTarget ? `自动补齐到 ${templateFrameTarget} 帧` : '已达到模板帧数'}</button>
                        <button type="button" disabled={!image || activeFrame === 0} onClick={() => moveActiveFrame(-1)} aria-label="上一帧">上一帧</button>
                       <button type="button" disabled={!image || activeFrame === frames.length - 1} onClick={() => moveActiveFrame(1)} aria-label="下一帧">下一帧</button>
                       <button type="button" className="danger" disabled={!image} onClick={deleteActiveFrame}>删除当前帧</button>
                   </div>
                 </div>
                  <div className="sprite-frames">{Array.from({ length: Math.max(template.frames, frames.length) }, (_, index) => <button type="button" disabled={!frames[index]} draggable={Boolean(frames[index])} onDragStart={() => setDragFrameIndex(index)} onDragOver={(event) => event.preventDefault()} onDrop={() => { if (dragFrameIndex !== null) reorderFrames(dragFrameIndex, index); setDragFrameIndex(null) }} onDragEnd={() => setDragFrameIndex(null)} className={`sprite-frame ${index === activeFrame ? 'active' : ''} ${isPlaying && index === previewFrame ? 'previewing' : ''} ${dragFrameIndex === index ? 'dragging' : ''}`} key={index} onClick={() => { setActiveFrame(index); setPreviewFrame(index); setIsPlaying(false) }}><span>{String(index + 1).padStart(2, '0')}</span>{frames[index] ? <><img src={frames[index].url} alt="" style={{ transform: `translate(${(frameTransforms[index]?.offsetX ?? 0) / 6}px, ${(frameTransforms[index]?.offsetY ?? 0) / 6}px) scale(${(frameTransforms[index]?.scale ?? 100) / 100})` }} /><small>{frameDuration} ms</small></> : <i />}</button>)}</div>
                 {image ? <div className="sprite-frame-adjustments"><div className="sprite-adjustment-head"><span>第 {String(activeFrame + 1).padStart(2, '0')} 帧调整</span><button type="button" onClick={resetCurrentFrame}>恢复当前帧</button></div><div className="sprite-adjustment-controls"><label className="sprite-control"><span>缩放 <output>{transform.scale}%</output></span><input type="range" min="50" max="180" value={transform.scale} onChange={(event) => updateTransform('scale', Number(event.target.value))} /></label><label className="sprite-control"><span>横向偏移 <output>{transform.offsetX}px</output></span><input type="range" min="-80" max="80" value={transform.offsetX} onChange={(event) => updateTransform('offsetX', Number(event.target.value))} /></label><label className="sprite-control"><span>纵向偏移 <output>{transform.offsetY}px</output></span><input type="range" min="-80" max="80" value={transform.offsetY} onChange={(event) => updateTransform('offsetY', Number(event.target.value))} /></label></div></div> : null}
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
              <li>选择合适模板。角色模板定义画布大小和锚点，不要求使用 LPC 的部位结构；长动作可选 16/32 帧模板。</li>
              <li>在实时预览中拖动图片调整位置，拖动青色锚点调整脚底或中心点。</li>
              <li>在帧序列中切换帧，分别调整每一帧；需要时可以删除或重新排序。</li>
              <li>背景不是透明时，点击“清理边缘背景”。如果效果不理想，可以恢复清理前帧。</li>
              <li>只有一张图片时，可以生成待机、行走、攻击、受击等“动作草稿”。它只做位移/缩放/旋转近似，不会生成真实姿态。</li>
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
