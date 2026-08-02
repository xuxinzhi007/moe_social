import { useEffect, useMemo, useRef, useState, type ChangeEvent, type PointerEvent } from 'react'
import { useGSAP } from '@gsap/react'
import { gsap } from 'gsap'
import JSZip from 'jszip'
import './sprite-studio.css'
import { removeImageBackground } from './backgroundCleanup'
import {
  generateSyntheticMotionFrames,
  type SyntheticMotionDirection,
  type SyntheticMotionPreset,
} from './syntheticMotionFrames'
import { SPRITE_TEMPLATES } from '../../../../moe-avatar/core/src/spriteTemplates'
import { validateSpriteResource, type SpriteValidationResult } from '../../../../moe-avatar/core/src/spriteValidation'
import type { SpriteResource } from '../../../../moe-avatar/core/src/spriteTypes'

gsap.registerPlugin(useGSAP)
import {
  extractVideoFrames,
  MAX_VIDEO_DURATION_SECONDS,
  MAX_VIDEO_FRAMES,
  readVideoMetadata,
} from './videoFrameExtraction'

type FrameTransform = { scale: number; offsetX: number; offsetY: number }
type FrameAsset = {
  id: string
  name: string
  url: string
  width: number
  height: number
  image: HTMLImageElement
  mimeType?: string
  durationMs: number
  disabled: boolean
  sourceFrameIndex: number
  crop?: { x: number; y: number; width: number; height: number }
}
type AnimationClip = { id: string; label: string; frameIndices: number[]; fps: number; loop: boolean }
type RepairStage = 'source' | 'tune' | 'export'
type PreviewBackground = 'checker' | 'light' | 'dark' | 'green' | 'magenta'
type Bounds = { left: number; top: number; right: number; bottom: number }
type Interaction = { kind: 'image' | 'anchor' | 'grid'; startX: number; startY: number; offsetX: number; offsetY: number; anchorX: number; anchorY: number; gridX: number; gridY: number }

const DEFAULT_TRANSFORM: FrameTransform = { scale: 100, offsetX: 0, offsetY: 0 }
const DEFAULT_FPS = 12
const DEFAULT_PADDING = 24
const PREVIEW_TEMPLATES = Object.values(SPRITE_TEMPLATES)

function slug(value: string, fallback: string) {
  const result = value.trim().toLowerCase().replace(/[^a-z0-9_-]+/g, '_').replace(/^_+|_+$/g, '')
  return result || fallback
}

function isImageFile(file: File) {
  return file.type.startsWith('image/') || /\.(png|jpe?g|webp)$/i.test(file.name)
}

function loadImage(url: string) {
  return new Promise<HTMLImageElement>((resolve, reject) => {
    const image = new Image()
    image.onload = () => resolve(image)
    image.onerror = () => reject(new Error('image-load-failed'))
    image.src = url
  })
}

function frameFromCanvas(canvas: HTMLCanvasElement, name: string, sourceFrameIndex: number, durationMs = 1000 / DEFAULT_FPS): Promise<FrameAsset> {
  return new Promise((resolve, reject) => {
    canvas.toBlob(async (blob) => {
      if (!blob) { reject(new Error('frame-export-failed')); return }
      const url = URL.createObjectURL(blob)
      try {
        const image = await loadImage(url)
        resolve({ id: `${Date.now()}_${sourceFrameIndex}_${Math.random()}`, name, url, width: canvas.width, height: canvas.height, image, mimeType: 'image/png', durationMs, disabled: false, sourceFrameIndex })
      } catch (error) {
        URL.revokeObjectURL(url)
        reject(error)
      }
    }, 'image/png')
  })
}

type JsonRecord = Record<string, unknown>

function parseSheetEntries(raw: unknown) {
  const data = (raw ?? {}) as JsonRecord
  if (Array.isArray(data.frames)) return data.frames.map((value, index: number) => { const entry = value as JsonRecord; return [String(entry.filename || entry.name || `frame_${index + 1}`), entry] as const })
  if (data.frames && typeof data.frames === 'object') return Object.entries(data.frames as JsonRecord).sort(([left], [right]) => left.localeCompare(right, undefined, { numeric: true }))
  throw new Error('JSON 中没有 frames')
}

function cropEntry(value: unknown) {
  const entry = (value ?? {}) as JsonRecord
  const frame = (entry.frame as JsonRecord | undefined) || (entry.crop as JsonRecord | undefined) || entry
  const x = Number(frame?.x ?? frame?.left ?? 0)
  const y = Number(frame?.y ?? frame?.top ?? 0)
  const width = Number(frame?.w ?? frame?.width ?? 0)
  const height = Number(frame?.h ?? frame?.height ?? 0)
  if (![x, y, width, height].every(Number.isFinite) || width <= 0 || height <= 0) throw new Error('JSON 中存在无效帧矩形')
  return { x, y, width, height }
}

function createClip(frameCount: number): AnimationClip {
  return { id: 'sequence_1', label: '未命名序列', frameIndices: Array.from({ length: frameCount }, (_, index) => index), fps: DEFAULT_FPS, loop: true }
}

function mergeBounds(left: Bounds | null, right: Bounds | null): Bounds | null {
  if (!right) return left
  if (!left) return right
  return { left: Math.min(left.left, right.left), top: Math.min(left.top, right.top), right: Math.max(left.right, right.right), bottom: Math.max(left.bottom, right.bottom) }
}

function readAlphaBounds(frame: FrameAsset) {
  const canvas = document.createElement('canvas')
  canvas.width = frame.width
  canvas.height = frame.height
  const context = canvas.getContext('2d', { willReadFrequently: true })
  if (!context) return null
  context.drawImage(frame.image, 0, 0)
  const pixels = context.getImageData(0, 0, frame.width, frame.height).data
  let bounds: Bounds | null = null
  for (let y = 0; y < frame.height; y += 1) for (let x = 0; x < frame.width; x += 1) {
    if (pixels[(y * frame.width + x) * 4 + 3] < 8) continue
    bounds = mergeBounds(bounds, { left: x, top: y, right: x + 1, bottom: y + 1 })
  }
  return bounds
}

function drawFrame(context: CanvasRenderingContext2D, frame: FrameAsset, transform: FrameTransform, originX: number, originY: number, fit: 'contain' | 'cover' = 'contain', canvasWidth = frame.width, canvasHeight = frame.height) {
  const imageRatio = frame.width / frame.height
  const canvasRatio = canvasWidth / canvasHeight
  const baseScale = fit === 'contain'
    ? (imageRatio > canvasRatio ? canvasWidth / frame.width : canvasHeight / frame.height)
    : (imageRatio > canvasRatio ? canvasHeight / frame.height : canvasWidth / frame.width)
  const scale = baseScale * transform.scale / 100
  const x = originX - frame.width * scale / 2 + transform.offsetX
  const y = originY - frame.height * scale / 2 + transform.offsetY
  context.imageSmoothingEnabled = false
  context.drawImage(frame.image, x, y, frame.width * scale, frame.height * scale)
}

function drawPreviewBackground(context: CanvasRenderingContext2D, width: number, height: number, background: PreviewBackground) {
  if (background === 'checker') {
    const size = 16
    context.fillStyle = '#f5f4f8'
    context.fillRect(0, 0, width, height)
    context.fillStyle = '#e5e4ea'
    for (let y = 0; y < height; y += size) for (let x = 0; x < width; x += size) if ((x / size + y / size) % 2 === 0) context.fillRect(x, y, size, size)
    return
  }
  const colors: Record<Exclude<PreviewBackground, 'checker'>, string> = { light: '#f4f3f8', dark: '#18202b', green: '#28463b', magenta: '#4b263e' }
  context.fillStyle = colors[background]
  context.fillRect(0, 0, width, height)
}

function calculateCanvasSize(frames: FrameAsset[], transforms: FrameTransform[], padding: number) {
  let bounds: Bounds | null = null
  for (const [index, frame] of frames.entries()) {
    const raw = readAlphaBounds(frame)
    if (!raw) continue
    const scale = (transforms[index]?.scale ?? 100) / 100
    const transform = transforms[index] ?? DEFAULT_TRANSFORM
    bounds = mergeBounds(bounds, {
      left: -frame.width * scale / 2 + transform.offsetX + raw.left * scale,
      top: -frame.height * scale / 2 + transform.offsetY + raw.top * scale,
      right: -frame.width * scale / 2 + transform.offsetX + raw.right * scale,
      bottom: -frame.height * scale / 2 + transform.offsetY + raw.bottom * scale,
    })
  }
  if (!bounds) return { width: 256, height: 256, originX: 128, originY: 128 }
  return { width: Math.max(1, Math.ceil(bounds.right - bounds.left + padding * 2)), height: Math.max(1, Math.ceil(bounds.bottom - bounds.top + padding * 2)), originX: Math.ceil(-bounds.left + padding), originY: Math.ceil(-bounds.top + padding) }
}

export function SpriteRepairPage() {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const studioRef = useRef<HTMLElement>(null)
  const interactionRef = useRef<Interaction | null>(null)
  const frameUrlsRef = useRef(new Set<string>())
  const [frames, setFrames] = useState<FrameAsset[]>([])
  const [frameTransforms, setFrameTransforms] = useState<FrameTransform[]>([])
  const [clips, setClips] = useState<AnimationClip[]>([])
  const [activeClipId, setActiveClipId] = useState('')
  const [activeFrame, setActiveFrame] = useState(0)
  const [previewFrame, setPreviewFrame] = useState(0)
  const [isPlaying, setIsPlaying] = useState(false)
  const [playbackPosition, setPlaybackPosition] = useState(0)
  const [dragClipPosition, setDragClipPosition] = useState<number | null>(null)
  const [stage, setStage] = useState<RepairStage>('source')
  const [dragFrameIndex, setDragFrameIndex] = useState<number | null>(null)
  const [sheetSourceName, setSheetSourceName] = useState('sprite')
  const [gridColumns, setGridColumns] = useState(4)
  const [gridRows, setGridRows] = useState(4)
  const [gridCellWidth, setGridCellWidth] = useState(64)
  const [gridCellHeight, setGridCellHeight] = useState(64)
  const [gridGapX, setGridGapX] = useState(0)
  const [gridGapY, setGridGapY] = useState(0)
  const [gridOffsetX, setGridOffsetX] = useState(0)
  const [gridOffsetY, setGridOffsetY] = useState(0)
  const [sheetFile, setSheetFile] = useState<File | null>(null)
  const [videoFile, setVideoFile] = useState<File | null>(null)
  const [videoDuration, setVideoDuration] = useState<number | null>(null)
  const [videoStart, setVideoStart] = useState(0)
  const [videoEnd, setVideoEnd] = useState(3)
  const [videoFps, setVideoFps] = useState(DEFAULT_FPS)
  const [extracting, setExtracting] = useState(false)
  const [cleaning, setCleaning] = useState(false)
  const [preCleanupFrames, setPreCleanupFrames] = useState<FrameAsset[] | null>(null)
  const [padding, setPadding] = useState(DEFAULT_PADDING)
  const [canvasSize, setCanvasSize] = useState({ width: 256, height: 256, originX: 128, originY: 128 })
  const [measuring, setMeasuring] = useState(false)
  const [message, setMessage] = useState('等待导入 PNG 序列或图集')
  const [showHelp, setShowHelp] = useState(false)
  const [previewTemplateId, setPreviewTemplateId] = useState('freeform')
  const [motionPreset, setMotionPreset] = useState<SyntheticMotionPreset>('idle')
  const [motionDirection, setMotionDirection] = useState<SyntheticMotionDirection | ''>('')
  const [generatingMotion, setGeneratingMotion] = useState(false)
  const [fitMode, setFitMode] = useState<'contain' | 'cover'>('contain')
  const [previewBackground, setPreviewBackground] = useState<PreviewBackground>('checker')
  const [anchor, setAnchor] = useState({ x: 128, y: 128 })

  const source = frames[0]
  const activeClip = clips.find((clip) => clip.id === activeClipId) ?? clips[0]
  const playableFrames = frames.map((_, index) => index).filter((index) => !frames[index]?.disabled)
  const playableKey = playableFrames.join(',')
  const displayFrame = isPlaying ? playableFrames[playbackPosition] ?? activeFrame : activeFrame
  const currentFrame = frames[displayFrame]
  const transform = frameTransforms[displayFrame] ?? DEFAULT_TRANSFORM
  const sourceCapacity = MAX_VIDEO_FRAMES
  const videoLimit = videoDuration === null ? MAX_VIDEO_DURATION_SECONDS : Math.min(MAX_VIDEO_DURATION_SECONDS, videoDuration)
  const effectiveVideoEnd = Math.min(Math.max(videoEnd, videoStart), videoLimit)
  const requestedVideoFrames = Math.min(sourceCapacity, Math.max(1, Math.floor((effectiveVideoEnd - videoStart) * videoFps) + 1))

  const manifest = useMemo(() => ({
    formatVersion: 'sprite-animation-v1',
    schemaVersion: 1,
    kind: 'sprite_sheet',
    image: 'spritesheet.png',
    format: 'RGBA8888',
    canvas: { width: canvasSize.width * Math.max(1, ...clips.map((clip) => clip.frameIndices.length)), height: canvasSize.height * Math.max(1, clips.filter((clip) => clip.frameIndices.length > 0).length) },
    anchor: { x: canvasSize.originX, y: canvasSize.originY },
    frameLayout: { mode: 'animation_grid', frameWidth: canvasSize.width, frameHeight: canvasSize.height, columns: Math.max(1, ...clips.map((clip) => clip.frameIndices.length)), rows: Math.max(1, clips.filter((clip) => clip.frameIndices.length > 0).length) },
    meta: { app: 'Moe Animation Sheet Workbench', version: 1, size: { w: canvasSize.width, h: canvasSize.height }, canvas: canvasSize },
    animations: clips.filter((clip) => clip.frameIndices.length > 0).map((clip, row) => ({ id: clip.id, label: clip.label, row, fps: clip.fps, loop: clip.loop, frameCount: clip.frameIndices.length })),
    frames: clips.filter((clip) => clip.frameIndices.length > 0).flatMap((clip) => clip.frameIndices.map((index, position) => ({ animation: clip.id, outputFrameIndex: position, sourceFrameIndex: frames[index]?.sourceFrameIndex ?? index, durationMs: Math.round(frames[index]?.durationMs ?? 1000 / clip.fps), disabled: Boolean(frames[index]?.disabled) }))),
  }), [canvasSize, clips, frames])
  const spriteResource = useMemo<SpriteResource>(() => ({
    id: slug(sheetSourceName, 'draft-sprite'),
    kind: 'character',
    templateId: previewTemplateId === 'freeform' ? undefined : previewTemplateId,
    status: 'draft',
    sheet: 'spritesheet.png',
    canvas: { width: canvasSize.width * Math.max(1, ...clips.map((clip) => clip.frameIndices.length)), height: canvasSize.height * Math.max(1, clips.filter((clip) => clip.frameIndices.length > 0).length) },
    anchor,
    animations: clips.filter((clip) => clip.frameIndices.length > 0).map((clip) => ({ id: clip.id, frameCount: clip.frameIndices.length, frameRate: clip.fps, loop: clip.loop })),
    frameLayout: { mode: 'animation_strip', frameWidth: canvasSize.width, frameHeight: canvasSize.height, columns: Math.max(1, ...clips.map((clip) => clip.frameIndices.length)), rows: Math.max(1, clips.filter((clip) => clip.frameIndices.length > 0).length) },
    source: { path: sheetSourceName, mimeType: source?.mimeType, width: source?.width, height: source?.height },
    generation: { mode: videoFile ? 'video_extracted' : 'source_frames' },
    frameAdjustments: frameTransforms.slice(0, Math.max(1, ...clips.map((clip) => clip.frameIndices.length)) * Math.max(1, clips.filter((clip) => clip.frameIndices.length > 0).length)).map((value, frame) => ({ frame, offsetX: value.offsetX, offsetY: value.offsetY, scale: value.scale / 100 })),
  }), [anchor, canvasSize, clips, frameTransforms, previewTemplateId, sheetSourceName, source, videoFile])
  const validation: SpriteValidationResult = useMemo(() => validateSpriteResource(spriteResource), [spriteResource])

  function track(url: string) { frameUrlsRef.current.add(url); return url }
  function release(items: readonly FrameAsset[]) { items.forEach((item) => { if (frameUrlsRef.current.delete(item.url)) URL.revokeObjectURL(item.url) }) }
  useEffect(() => () => { frameUrlsRef.current.forEach((url) => URL.revokeObjectURL(url)) }, [])

  function replaceFrames(next: FrameAsset[], name: string, importedClips?: AnimationClip[]) {
    release(frames)
    if (preCleanupFrames) release(preCleanupFrames)
    setFrames(next)
    setPreCleanupFrames(null)
    setFrameTransforms(next.map(() => ({ ...DEFAULT_TRANSFORM })))
    const nextClip = createClip(next.length)
    const nextClips = importedClips?.length ? importedClips : [nextClip]
    setClips(nextClips)
    setActiveClipId(nextClips[0].id)
    setActiveFrame(0)
    setPreviewFrame(0)
    setPlaybackPosition(0)
    setIsPlaying(false)
    setSheetSourceName(name.replace(/\.[^.]+$/, '') || 'sprite')
    setStage(next.length > 1 ? 'tune' : 'source')
  }

  async function loadFiles(event: ChangeEvent<HTMLInputElement>) {
    const selected = Array.from(event.target.files ?? [])
    event.target.value = ''
    if (!selected.length || selected.some((file) => !isImageFile(file))) { setMessage('只支持 PNG、JPG、JPEG 或 WebP 图片'); return }
    try {
      const next = await Promise.all(selected.slice(0, sourceCapacity).map(async (file, index) => {
        const url = track(URL.createObjectURL(file))
        const image = await loadImage(url)
        return { id: `${Date.now()}_${index}`, name: file.name, url, width: image.width, height: image.height, image, mimeType: file.type, durationMs: 1000 / DEFAULT_FPS, disabled: false, sourceFrameIndex: index }
      }))
      replaceFrames(next, selected[0].name)
      if (next.length === 1) initializeGrid(next[0].width, next[0].height)
      setSheetFile(null)
      setMessage(`已载入 ${next.length} 个原始帧；先校准，再导出统一画布`)
    } catch { setMessage('图片载入失败') }
  }

  async function importSheet(event: ChangeEvent<HTMLInputElement>) {
    const jsonFile = event.target.files?.[0]
    event.target.value = ''
    if (!jsonFile || !sheetFile) { setMessage('请先选择 Sheet PNG，再选择 JSON 描述文件'); return }
    try {
      const sourceUrl = track(URL.createObjectURL(sheetFile))
      const sourceImage = await loadImage(sourceUrl)
      const raw = JSON.parse(await jsonFile.text().then((text) => text.replace(/^\uFEFF/, '')))
      const entries = parseSheetEntries(raw)
      const next: FrameAsset[] = []
      const importedFrameIndices = new Map<string, number>()
      for (const [name, value] of entries.slice(0, sourceCapacity)) {
        const entry = value as JsonRecord
        const crop = cropEntry(value)
        const canvas = document.createElement('canvas')
        canvas.width = crop.width
        canvas.height = crop.height
        const context = canvas.getContext('2d')
        if (!context) throw new Error('canvas-context-failed')
        context.drawImage(sourceImage, crop.x, crop.y, crop.width, crop.height, 0, 0, crop.width, crop.height)
        const metadata = (raw.meta as JsonRecord | undefined) ?? {}
        const frame = await frameFromCanvas(canvas, name, next.length, Number(entry.durationMs ?? entry.duration ?? 1000 / Number(metadata.frameRate || DEFAULT_FPS)))
        track(frame.url)
        frame.crop = crop
        importedFrameIndices.set(name, next.length)
        next.push(frame)
      }
      URL.revokeObjectURL(sourceUrl)
      frameUrlsRef.current.delete(sourceUrl)
      const importedClips: AnimationClip[] | undefined = Array.isArray(raw.animations)
        ? (raw.animations as unknown[]).map((value: unknown, row: number) => {
          const animation = value as JsonRecord
          const animationId = String(animation.id || `sequence_${row + 1}`)
          const frameIndices = entries
            .filter(([, entry]) => String((entry as JsonRecord).animation || '') === animationId)
            .sort(([, left], [, right]) => Number((left as JsonRecord).outputFrameIndex ?? 0) - Number((right as JsonRecord).outputFrameIndex ?? 0))
            .map(([name]) => importedFrameIndices.get(name))
            .filter((index): index is number => index !== undefined)
          return {
            id: animationId,
            label: String(animation.label || animationId),
            frameIndices,
            fps: Number(animation.fps || animation.frameRate || DEFAULT_FPS),
            loop: animation.loop !== false,
          }
        }).filter((clip) => clip.frameIndices.length > 0)
        : undefined
      replaceFrames(next, sheetFile.name, importedClips)
      setMessage(`已导入 ${next.length} 个图集帧，保留 JSON 中的裁剪区域和帧时长`)
    } catch (error) { setMessage(error instanceof Error ? `图集导入失败：${error.message}` : '图集导入失败') }
  }

  async function handleVideo(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0]
    event.target.value = ''
    if (!file) return
    try {
      const metadata = await readVideoMetadata(file)
      setVideoFile(file)
      setVideoDuration(metadata.duration)
      setVideoStart(0)
      setVideoEnd(Math.min(3, metadata.duration, (sourceCapacity - 1) / videoFps))
      setMessage(`已选择视频 ${metadata.width} × ${metadata.height}px`)
    } catch { setMessage('视频读取失败') }
  }

  async function extractVideo() {
    if (!videoFile || extracting) return
    setExtracting(true)
    try {
      const next = await extractVideoFrames(videoFile, { startTime: videoStart, endTime: effectiveVideoEnd, frameCount: requestedVideoFrames, onProgress: () => {} })
      next.forEach((frame) => track(frame.url))
      replaceFrames(next.map((frame, index) => ({ ...frame, id: `${Date.now()}_${index}`, durationMs: 1000 / videoFps, disabled: false, sourceFrameIndex: index })), videoFile.name)
      setMessage(`已提取 ${next.length} 帧；请在帧条上逐帧调校`)
    } catch { setMessage('视频帧提取失败') } finally { setExtracting(false) }
  }

  async function generateMotion() {
    if (!currentFrame || frames.length !== 1 || videoFile || generatingMotion) return
    setGeneratingMotion(true)
    try {
      const generated = await generateSyntheticMotionFrames(currentFrame.image, {
        preset: motionPreset,
        direction: motionDirection || undefined,
        horizontalFlip: motionDirection === 'left',
        sourceName: sheetSourceName,
      })
      generated.forEach((frame) => track(frame.url))
      const next = generated.map((frame, index) => ({ ...frame, id: `${Date.now()}_${index}`, durationMs: 1000 / DEFAULT_FPS, disabled: false, sourceFrameIndex: index }))
      replaceFrames(next, sheetSourceName)
      setMessage(`${motionPreset} 动作草稿已生成，共 ${next.length} 帧；这是位移动效近似，不是姿态生成`)
    } catch { setMessage('动作草稿生成失败，请先导入一张图片') } finally { setGeneratingMotion(false) }
  }

  function initializeGrid(width: number, height: number) {
    setGridCellWidth(Math.max(1, Math.floor(width / gridColumns)))
    setGridCellHeight(Math.max(1, Math.floor(height / gridRows)))
  }

  async function extractGrid() {
    if (!source) return
    const requiredWidth = gridOffsetX + gridColumns * gridCellWidth + (gridColumns - 1) * gridGapX
    const requiredHeight = gridOffsetY + gridRows * gridCellHeight + (gridRows - 1) * gridGapY
    if (requiredWidth > source.width || requiredHeight > source.height) { setMessage('网格超出原图范围'); return }
    const next: FrameAsset[] = []
    for (let row = 0; row < gridRows; row += 1) for (let column = 0; column < gridColumns; column += 1) {
      const canvas = document.createElement('canvas')
      canvas.width = gridCellWidth
      canvas.height = gridCellHeight
      const context = canvas.getContext('2d')
      if (!context) return
      context.imageSmoothingEnabled = false
      context.drawImage(source.image, gridOffsetX + column * (gridCellWidth + gridGapX), gridOffsetY + row * (gridCellHeight + gridGapY), gridCellWidth, gridCellHeight, 0, 0, gridCellWidth, gridCellHeight)
      const frame = await frameFromCanvas(canvas, `${sheetSourceName}_r${row + 1}_c${column + 1}.png`, next.length)
      track(frame.url)
      next.push(frame)
    }
    replaceFrames(next, sheetSourceName)
    setMessage(`已切出 ${next.length} 个帧并进入统一帧池`)
  }

  function updateClip(patch: Partial<AnimationClip>) { if (activeClip) setClips((current) => current.map((clip) => clip.id === activeClip.id ? { ...clip, ...patch } : clip)) }
  function addClip() {
    const label = window.prompt('动画名称', `sequence_${clips.length + 1}`)?.trim()
    if (!label) return
    const id = slug(label, `sequence_${clips.length + 1}`)
    if (clips.some((clip) => clip.id === id)) { setMessage('动画名称已存在'); return }
    const clip = { id, label, frameIndices: frames[activeFrame] ? [activeFrame] : [], fps: DEFAULT_FPS, loop: true }
    setClips((current) => [...current, clip]); setActiveClipId(id); setMessage(`已创建 ${label}，请从帧条添加帧`)
  }
  function selectClip(clip: AnimationClip) { setActiveClipId(clip.id); const first = clip.frameIndices[0]; if (first !== undefined) { setActiveFrame(first); setPreviewFrame(first) }; setPlaybackPosition(0); setIsPlaying(false) }
  function removeFrameFromClip(index: number) { if (activeClip) updateClip({ frameIndices: activeClip.frameIndices.filter((value) => value !== index) }) }
  function reorderClipFrames(from: number, to: number) {
    if (!activeClip || from === to || from < 0 || to < 0 || from >= activeClip.frameIndices.length || to >= activeClip.frameIndices.length) return
    const frameIndices = [...activeClip.frameIndices]
    const [frameIndex] = frameIndices.splice(from, 1)
    frameIndices.splice(to, 0, frameIndex)
    updateClip({ frameIndices })
    setActiveFrame(frameIndex)
    setPreviewFrame(frameIndex)
    setPlaybackPosition(Math.max(0, frameIndices.indexOf(frameIndex)))
  }
  function reorderFrames(from: number, to: number) {
    if (from === to || from < 0 || to < 0 || from >= frames.length || to >= frames.length) return
    const remap = (index: number) => index === from ? to : from < to && index > from && index <= to ? index - 1 : from > to && index >= to && index < from ? index + 1 : index
    setFrames((current) => { const next = [...current]; const [item] = next.splice(from, 1); next.splice(to, 0, item); return next })
    setFrameTransforms((current) => { const next = [...current]; const [item] = next.splice(from, 1); next.splice(to, 0, item ?? DEFAULT_TRANSFORM); return next })
    setClips((current) => current.map((clip) => ({ ...clip, frameIndices: clip.frameIndices.map(remap) })))
    setActiveFrame(remap(activeFrame)); setPreviewFrame(remap(previewFrame))
  }
  function deleteFrame() {
    if (!frames[activeFrame]) return
    const deleted = activeFrame
    const remaining = frames.filter((_, index) => index !== deleted)
    if (!remaining.some((frame) => frame.url === frames[deleted].url)) release([frames[deleted]])
    setFrames(remaining)
    setFrameTransforms((current) => current.filter((_, index) => index !== deleted))
    setClips((current) => current.map((clip) => ({ ...clip, frameIndices: clip.frameIndices.map((index) => index === deleted ? -1 : index > deleted ? index - 1 : index).filter((index) => index >= 0) })))
    setActiveFrame((current) => Math.min(current, Math.max(0, frames.length - 2)))
    setPreviewFrame((current) => Math.min(current, Math.max(0, frames.length - 2)))
  }
  function updateTransform(key: keyof FrameTransform, value: number) { setFrameTransforms((current) => current.map((transform) => ({ ...(transform ?? DEFAULT_TRANSFORM), [key]: value }))) }
  function updateFrame(patch: Partial<FrameAsset>) { setFrames((current) => current.map((frame, index) => index === activeFrame ? { ...frame, ...patch } : frame)) }

  async function cleanupBackground() {
    if (!frames.length || cleaning) return
    setCleaning(true)
    try {
      const next = await Promise.all(frames.map(async (frame) => { const canvas = removeImageBackground(frame.image, { colorDistance: 36, speckleSize: 256 }); const cleaned = await frameFromCanvas(canvas, frame.name, frame.sourceFrameIndex, frame.durationMs); track(cleaned.url); return cleaned }))
      setPreCleanupFrames(frames); next.forEach((frame) => track(frame.url)); setFrames(next); setMessage('已清理背景；请检查发丝和半透明边缘')
    } catch { setMessage('背景清理失败') } finally { setCleaning(false) }
  }
  function restoreCleanup() { if (!preCleanupFrames) return; release(frames); setFrames(preCleanupFrames); setPreCleanupFrames(null) }

  function measureCanvas() {
    if (!frames.length || measuring) return
    setMeasuring(true)
    const next = calculateCanvasSize(frames, frameTransforms, padding)
    setCanvasSize(next); setAnchor({ x: next.originX, y: next.originY }); setMeasuring(false); setMessage(`统一画布：${next.width} × ${next.height}px，所有动画共享同一原点`)
  }

  function selectPreviewTemplate(value: string) {
    setPreviewTemplateId(value)
    if (value === 'freeform') return
    const template = PREVIEW_TEMPLATES.find((item) => item.id === value)
    if (!template) return
    setCanvasSize({ width: template.canvas.width, height: template.canvas.height, originX: template.anchor.x, originY: template.anchor.y })
    setAnchor(template.anchor)
    setMessage(`已切换 ${template.label} 预览模板；导出时仍会按透明像素重新计算统一画布`)
  }

  function resetPlacement() {
    setFrameTransforms((current) => current.map(() => ({ ...DEFAULT_TRANSFORM })))
    setAnchor({ x: canvasSize.originX, y: canvasSize.originY })
    setFitMode('contain')
  }

  function reverseFrames() {
    if (frames.length < 2) return
    setFrames((current) => [...current].reverse())
    setFrameTransforms((current) => [...current].reverse())
    setClips((current) => current.map((clip) => ({ ...clip, frameIndices: clip.frameIndices.map((index) => frames.length - 1 - index) })))
    setActiveFrame((current) => frames.length - 1 - current)
    setPreviewFrame((current) => frames.length - 1 - current)
  }

  function templateFrameTarget() {
    const template = PREVIEW_TEMPLATES.find((item) => item.id === previewTemplateId)
    return template ? template.animations[0]?.frameCount ?? template.frameLayout.columns * template.frameLayout.rows : 0
  }

  function fillFramesToTemplate() {
    const target = templateFrameTarget()
    if (!target || frames.length === 0 || frames.length >= target) return
    const cycle = frames.length > 1 ? [...frames.map((_, index) => index), ...frames.slice(1, -1).map((_, index) => frames.length - 2 - index)] : [0]
    const nextFrames = [...frames]
    const nextTransforms = [...frameTransforms]
    while (nextFrames.length < target) { const index = cycle[(nextFrames.length - frames.length) % cycle.length]; nextFrames.push({ ...frames[index], id: `${frames[index].id}_copy_${nextFrames.length}` }); nextTransforms.push({ ...(frameTransforms[index] ?? DEFAULT_TRANSFORM) }) }
    setFrames(nextFrames); setFrameTransforms(nextTransforms); setClips((current) => current.map((clip) => ({ ...clip, frameIndices: clip.frameIndices.length ? [...clip.frameIndices, ...Array.from({ length: target - frames.length }, (_, index) => frames.length + index)] : clip.frameIndices })))
  }

  async function exportFramesZip() {
    if (!frames.length) return
    const zip = new JSZip()
    for (const [index, frame] of frames.entries()) { const response = await fetch(frame.url); if (!response.ok) continue; zip.file(`frame_${String(index + 1).padStart(4, '0')}.png`, await response.blob()) }
    const blob = await zip.generateAsync({ type: 'blob' }); const url = URL.createObjectURL(blob); const link = document.createElement('a'); link.href = url; link.download = `${slug(sheetSourceName, 'sprite')}_frames.zip`; link.click(); URL.revokeObjectURL(url); setMessage('已导出原始帧 ZIP')
  }

  async function exportSheet() {
    const exportClips = clips.filter((clip) => clip.frameIndices.length > 0).map((clip) => ({ ...clip, frameIndices: frames.map((_, index) => index) }))
    if (!exportClips.length || !frames.length) { setMessage('请先导入帧并创建至少一个非空动画'); return }
    const exportCanvasSize = calculateCanvasSize(frames, frameTransforms, padding)
    setCanvasSize(exportCanvasSize)
    const playableClipFrames = exportClips.map((clip) => clip.frameIndices.filter((index) => !frames[index]?.disabled))
    const columns = Math.max(1, ...playableClipFrames.map((frameIndices) => frameIndices.length))
    const rows = exportClips.length
    const canvas = document.createElement('canvas')
    canvas.width = exportCanvasSize.width * columns
    canvas.height = exportCanvasSize.height * rows
    if (canvas.width > 16384 || canvas.height > 16384) { setMessage('Sheet 尺寸过大，请减少列数或透明边距'); return }
    const context = canvas.getContext('2d')
    if (!context) return
    const outputFrames: Record<string, JsonRecord> = {}
    for (const [row, frameIndices] of playableClipFrames.entries()) for (const [column, index] of frameIndices.entries()) {
      const frame = frames[index]
      if (!frame) continue
      const clip = exportClips[row]
      context.save()
      context.translate(column * exportCanvasSize.width, row * exportCanvasSize.height)
      drawFrame(context, frame, frameTransforms[index] ?? DEFAULT_TRANSFORM, exportCanvasSize.originX, exportCanvasSize.originY, 'contain', exportCanvasSize.width, exportCanvasSize.height)
      context.restore()
      const filename = `${clip.id}_${String(column + 1).padStart(4, '0')}.png`
      outputFrames[filename] = { frame: { x: column * exportCanvasSize.width, y: row * exportCanvasSize.height, w: exportCanvasSize.width, h: exportCanvasSize.height }, duration: Math.round(frame.durationMs || 1000 / clip.fps), sourceFrameIndex: frame.sourceFrameIndex, animation: clip.id, outputFrameIndex: column }
    }
    const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, 'image/png'))
    if (!blob) { setMessage('PNG 导出失败'); return }
    const zip = new JSZip()
    zip.file('spritesheet.png', blob)
    const exportedManifest = {
      ...manifest,
      canvas: { width: canvas.width, height: canvas.height },
      anchor: { x: exportCanvasSize.originX, y: exportCanvasSize.originY },
      frameLayout: { mode: 'animation_grid', frameWidth: exportCanvasSize.width, frameHeight: exportCanvasSize.height, columns, rows },
      meta: { ...manifest.meta, size: { w: canvas.width, h: canvas.height }, canvas: exportCanvasSize },
      animations: exportClips.map((clip, row) => ({ id: clip.id, label: clip.label, row, fps: clip.fps, loop: clip.loop, frameCount: playableClipFrames[row].length })),
      frames: outputFrames,
    }
    zip.file('spritesheet.json', JSON.stringify(exportedManifest, null, 2))
    const result = await zip.generateAsync({ type: 'blob' })
    const url = URL.createObjectURL(result); const link = document.createElement('a'); link.href = url; link.download = `${slug(sheetSourceName, 'sprite')}_sheet_json.zip`; link.click(); URL.revokeObjectURL(url)
    setMessage(`已导出可重新导入的 spritesheet.png + spritesheet.json，共 ${Object.keys(outputFrames).length} 帧`)
  }

  useEffect(() => { const indices = playableKey ? playableKey.split(',').map(Number) : []; if (!isPlaying || indices.length < 2) return; const timer = window.setInterval(() => setPlaybackPosition((current) => { const next = (current + 1) % indices.length; setPreviewFrame(indices[next]); return next }), Math.max(30, Math.round(1000 / (activeClip?.fps || DEFAULT_FPS)))); return () => window.clearInterval(timer) }, [activeClip?.fps, isPlaying, playableKey])
  useEffect(() => { const row = document.querySelector<HTMLElement>('.sprite-workbench-animation .sprite-animation-row'); if (!row) return; const handleDrop = (event: DragEvent) => { event.preventDefault(); const index = Number(event.dataTransfer?.getData('text/plain')); if (!Number.isInteger(index) || !frames[index]) return; setClips((current) => current.map((clip) => clip.id === activeClipId && !clip.frameIndices.includes(index) ? { ...clip, frameIndices: [...clip.frameIndices, index] } : clip)); setActiveFrame(index); setPreviewFrame(index) }; const handleDragOver = (event: DragEvent) => event.preventDefault(); row.addEventListener('drop', handleDrop); row.addEventListener('dragover', handleDragOver); return () => { row.removeEventListener('drop', handleDrop); row.removeEventListener('dragover', handleDragOver) } }, [activeClipId, frames])
  useGSAP(() => {
    const intro = gsap.timeline({ defaults: { duration: 0.42, ease: 'power2.out' } })
    intro.fromTo('.sprite-studio-head', { y: 12, autoAlpha: 0 }, { y: 0, autoAlpha: 1, clearProps: 'transform,opacity,visibility' })
      .fromTo('.sprite-sidebar > .sprite-collapsible', { x: -12, autoAlpha: 0 }, { x: 0, autoAlpha: 1, clearProps: 'transform,opacity,visibility', stagger: 0.05 }, '<0.1')
      .fromTo('.sprite-workbench > *', { y: 12, autoAlpha: 0 }, { y: 0, autoAlpha: 1, clearProps: 'transform,opacity,visibility', stagger: 0.06 }, '<0.08')
  }, { scope: studioRef, dependencies: [] })
  useGSAP(() => {
    gsap.fromTo('.sprite-frame', { y: 10, scale: 0.96, autoAlpha: 0 }, { y: 0, scale: 1, autoAlpha: 1, duration: 0.3, ease: 'power2.out', stagger: 0.025, clearProps: 'transform,opacity,visibility' })
  }, { scope: studioRef, dependencies: [frames.length, activeClipId], revertOnUpdate: true })
  useGSAP(() => {
    const media = gsap.matchMedia()
    media.add('(prefers-reduced-motion: no-preference)', () => {
      const timeline = gsap.timeline({ defaults: { duration: 0.28, ease: 'power2.out' } })
      timeline.fromTo('.sprite-workflow-nav button.active', { scale: 0.96, autoAlpha: 0.6 }, { scale: 1, autoAlpha: 1, clearProps: 'transform,opacity,visibility' })
        .fromTo('.sprite-animation-row button', { y: 6, autoAlpha: 0 }, { y: 0, autoAlpha: 1, clearProps: 'transform,opacity,visibility', stagger: 0.025 }, '<0.04')
        .fromTo('.sprite-message', { y: 4, autoAlpha: 0 }, { y: 0, autoAlpha: 1, clearProps: 'transform,opacity,visibility' }, '<0.06')
    })
    return () => media.revert()
  }, { scope: studioRef, dependencies: [stage, activeClipId, message], revertOnUpdate: true })
  useEffect(() => { const canvas = canvasRef.current; if (!canvas || !currentFrame) return; const isSheetPreview = frames.length === 1; canvas.width = isSheetPreview ? currentFrame.width : canvasSize.width; canvas.height = isSheetPreview ? currentFrame.height : canvasSize.height; const context = canvas.getContext('2d'); if (!context) return; context.clearRect(0, 0, canvas.width, canvas.height); context.fillStyle = '#f4f3f8'; context.fillRect(0, 0, canvas.width, canvas.height); if (isSheetPreview) { context.drawImage(currentFrame.image, 0, 0); context.lineWidth = Math.max(1, Math.round(Math.min(currentFrame.width, currentFrame.height) / 180)); context.font = `${Math.max(9, Math.round(Math.min(currentFrame.width, currentFrame.height) / 45))}px ui-monospace`; for (let row = 0; row < gridRows; row += 1) for (let column = 0; column < gridColumns; column += 1) { const x = gridOffsetX + column * (gridCellWidth + gridGapX); const y = gridOffsetY + row * (gridCellHeight + gridGapY); const inside = x >= 0 && y >= 0 && x + gridCellWidth <= currentFrame.width && y + gridCellHeight <= currentFrame.height; context.strokeStyle = inside ? 'rgba(255, 59, 64, .94)' : 'rgba(150, 145, 160, .75)'; context.setLineDash(inside ? [] : [5, 4]); context.strokeRect(x + .5, y + .5, gridCellWidth - 1, gridCellHeight - 1); context.fillStyle = inside ? 'rgba(180, 30, 38, .92)' : 'rgba(100, 96, 110, .85)'; context.fillText(`${row + 1}:${column + 1}`, x + 4, y + 13) } context.setLineDash([]) } else { drawFrame(context, currentFrame, transform, anchor.x, anchor.y, fitMode, canvasSize.width, canvasSize.height); context.strokeStyle = '#6b5fc1'; context.setLineDash([5, 4]); context.strokeRect(.5, .5, canvas.width - 1, canvas.height - 1); context.setLineDash([]); context.strokeStyle = '#34d3c8'; context.beginPath(); context.arc(anchor.x, anchor.y, 5, 0, Math.PI * 2); context.stroke() } }, [anchor, canvasSize, currentFrame, fitMode, frames.length, gridCellHeight, gridCellWidth, gridColumns, gridGapX, gridGapY, gridOffsetX, gridOffsetY, gridRows, transform])
  useEffect(() => { if (!currentFrame || frames.length === 1) return; const canvas = canvasRef.current; const context = canvas?.getContext('2d'); if (!canvas || !context) return; drawPreviewBackground(context, canvas.width, canvas.height, previewBackground); drawFrame(context, currentFrame, transform, anchor.x, anchor.y, fitMode, canvasSize.width, canvasSize.height); context.strokeStyle = '#6b5fc1'; context.setLineDash([5, 4]); context.strokeRect(.5, .5, canvas.width - 1, canvas.height - 1); context.setLineDash([]); context.strokeStyle = '#34d3c8'; context.beginPath(); context.arc(anchor.x, anchor.y, 7, 0, Math.PI * 2); context.stroke() }, [anchor, canvasSize, currentFrame, fitMode, frames.length, previewBackground, transform])
  useEffect(() => { const panel = studioRef.current?.querySelector('.sprite-canvas-panel .sprite-panel-top'); if (!panel || panel.querySelector('.sprite-preview-background-control')) return; const label = document.createElement('label'); label.className = 'sprite-preview-background-control'; label.innerHTML = '<span>预览背景</span><select><option value="checker">棋盘格</option><option value="light">浅色</option><option value="dark">深色</option><option value="green">绿色</option><option value="magenta">洋红</option></select>'; const select = label.querySelector('select'); if (!select) return; select.value = previewBackground; select.addEventListener('change', () => setPreviewBackground(select.value as PreviewBackground)); panel.appendChild(label); return () => label.remove() }, [previewBackground])
  useEffect(() => { if (currentFrame) return; const canvas = canvasRef.current; const context = canvas?.getContext('2d'); if (!canvas || !context) return; canvas.width = 720; canvas.height = 420; context.fillStyle = '#f7f7fa'; context.fillRect(0, 0, canvas.width, canvas.height); context.strokeStyle = '#d8d4e5'; context.setLineDash([7, 7]); context.strokeRect(20.5, 20.5, canvas.width - 41, canvas.height - 41); context.setLineDash([]); context.fillStyle = '#6b5fc1'; context.textAlign = 'center'; context.font = '700 18px ui-monospace, Consolas, monospace'; context.fillText('DROP A FRAME TO BEGIN', canvas.width / 2, canvas.height / 2 - 8); context.fillStyle = '#858194'; context.font = '12px ui-monospace, Consolas, monospace'; context.fillText('PNG sequence · Sheet + JSON · video', canvas.width / 2, canvas.height / 2 + 20); context.textAlign = 'start' }, [currentFrame])
  useEffect(() => { if (!source || frames.length !== 1) return; const availableWidth = Math.max(1, source.width - gridOffsetX - Math.max(0, gridColumns - 1) * gridGapX); const availableHeight = Math.max(1, source.height - gridOffsetY - Math.max(0, gridRows - 1) * gridGapY); const nextWidth = Math.max(1, Math.floor(availableWidth / Math.max(1, gridColumns))); const nextHeight = Math.max(1, Math.floor(availableHeight / Math.max(1, gridRows))); const frame = window.requestAnimationFrame(() => { setGridCellWidth((current) => current === nextWidth ? current : nextWidth); setGridCellHeight((current) => current === nextHeight ? current : nextHeight) }); return () => window.cancelAnimationFrame(frame) }, [gridColumns, gridGapX, gridGapY, gridOffsetX, gridOffsetY, gridRows, frames.length, source])

  function pointerDown(event: PointerEvent<HTMLCanvasElement>) { const canvas = event.currentTarget; if (!canvas || isPlaying) return; event.preventDefault(); const rect = canvas.getBoundingClientRect(); const x = (event.clientX - rect.left) * canvas.width / rect.width; const y = (event.clientY - rect.top) * canvas.height / rect.height; const kind = frames.length === 1 ? 'grid' : 'anchor'; interactionRef.current = { kind, startX: x, startY: y, offsetX: transform.offsetX, offsetY: transform.offsetY, anchorX: anchor.x, anchorY: anchor.y, gridX: gridOffsetX, gridY: gridOffsetY }; canvas.setPointerCapture(event.pointerId) }
  function pointerMove(event: PointerEvent<HTMLCanvasElement>) { const interaction = interactionRef.current; const canvas = event.currentTarget; if (!interaction || !canvas) return; event.preventDefault(); const rect = canvas.getBoundingClientRect(); const x = (event.clientX - rect.left) * canvas.width / rect.width; const y = (event.clientY - rect.top) * canvas.height / rect.height; if (interaction.kind === 'grid') { setGridOffsetX(Math.round(Math.max(0, interaction.gridX + x - interaction.startX))); setGridOffsetY(Math.round(Math.max(0, interaction.gridY + y - interaction.startY))) } else if (interaction.kind === 'anchor') setAnchor({ x: Math.round(Math.max(0, Math.min(canvas.width, interaction.anchorX + x - interaction.startX))), y: Math.round(Math.max(0, Math.min(canvas.height, interaction.anchorY + y - interaction.startY))) }); else { updateTransform('offsetX', Math.round(interaction.offsetX + x - interaction.startX)); updateTransform('offsetY', Math.round(interaction.offsetY + y - interaction.startY)) } }
  function pointerUp(event: PointerEvent<HTMLCanvasElement>) { interactionRef.current = null; if (event.currentTarget.hasPointerCapture(event.pointerId)) event.currentTarget.releasePointerCapture(event.pointerId) }

  return <main ref={studioRef} className="sprite-studio" data-repair-stage={stage}>
    <header className="sprite-studio-head"><div><p className="sprite-kicker">ANIMATION SHEET WORKBENCH</p><h2>序列帧整理工作台</h2><p className="sprite-intro">把杂乱 AI 帧整理成统一画布、可直接网格裁剪的透明 Sheet。</p></div><div className="sprite-head-actions"><button type="button" className="sprite-help-button" onClick={() => setShowHelp(true)}>使用说明</button><button type="button" className="sprite-head-export" disabled={!frames.length || !clips.some((clip) => clip.frameIndices.length)} onClick={() => void exportSheet()}>导出最终 Sheet</button><span className="sprite-draft-badge"><span />本地编辑 · 不上传</span></div></header>
    <nav className="sprite-workflow-nav"><button type="button" className={stage === 'source' ? 'active' : ''} onClick={() => setStage('source')}><b>1</b><span>导入</span><small>序列或 Sheet + JSON</small></button><button type="button" className={stage === 'tune' ? 'active' : ''} disabled={!frames.length} onClick={() => setStage('tune')}><b>2</b><span>调校</span><small>画布与帧条</small></button><button type="button" className={stage === 'export' ? 'active' : ''} disabled={!frames.length} onClick={() => setStage('export')}><b>3</b><span>导出</span><small>统一透明画布</small></button></nav>
    <section className="sprite-studio-grid"><aside className="sprite-sidebar">
      <details className="sprite-collapsible" open><summary>输入素材</summary><label className="sprite-dropzone" htmlFor="sprite-upload"><span className="sprite-upload-mark">+</span><strong>导入 PNG 序列</strong><small>支持 PNG / JPG / JPEG / WebP</small><input id="sprite-upload" type="file" accept="image/*,.png,.jpg,.jpeg,.webp" multiple onChange={loadFiles} /></label>
        <div className="sprite-grid-extractor"><div className="sprite-section-label">单张图集切格</div><p>导入一张图集后按原始矩形切出帧，不改变帧的原始像素尺寸。</p><div className="sprite-grid-settings"><label className="sprite-control"><span>列数</span><input type="number" min="1" max="64" value={gridColumns} onChange={(event) => { const value = Math.max(1, Number(event.target.value) || 1); setGridColumns(value); if (source) initializeGrid(source.width, source.height) }} /></label><label className="sprite-control"><span>行数</span><input type="number" min="1" max="64" value={gridRows} onChange={(event) => { const value = Math.max(1, Number(event.target.value) || 1); setGridRows(value); if (source) initializeGrid(source.width, source.height) }} /></label><label className="sprite-control"><span>格宽</span><input type="number" min="1" value={gridCellWidth} onChange={(event) => setGridCellWidth(Math.max(1, Number(event.target.value) || 1))} /></label><label className="sprite-control"><span>格高</span><input type="number" min="1" value={gridCellHeight} onChange={(event) => setGridCellHeight(Math.max(1, Number(event.target.value) || 1))} /></label><label className="sprite-control"><span>间距 X</span><input type="number" min="0" value={gridGapX} onChange={(event) => setGridGapX(Math.max(0, Number(event.target.value) || 0))} /></label><label className="sprite-control"><span>间距 Y</span><input type="number" min="0" value={gridGapY} onChange={(event) => setGridGapY(Math.max(0, Number(event.target.value) || 0))} /></label><label className="sprite-control"><span>起点 X</span><input type="number" min="0" value={gridOffsetX} onChange={(event) => setGridOffsetX(Math.max(0, Number(event.target.value) || 0))} /></label><label className="sprite-control"><span>起点 Y</span><input type="number" min="0" value={gridOffsetY} onChange={(event) => setGridOffsetY(Math.max(0, Number(event.target.value) || 0))} /></label></div><button type="button" className="sprite-grid-extract" disabled={!source || frames.length !== 1} onClick={() => void extractGrid()}>切格并进入帧池</button></div>
        <div className="sprite-sheet-import"><div className="sprite-section-label">重新导入 Sheet + JSON</div><label className="sprite-video-input" htmlFor="sheet-upload"><span>{sheetFile?.name ?? '选择 spritesheet.png'}</span><b>选择</b><input id="sheet-upload" type="file" accept="image/png,.png" onChange={(event) => setSheetFile(event.target.files?.[0] ?? null)} /></label><label className="sprite-video-input" htmlFor="sheet-json-upload"><span>选择 spritesheet.json</span><b>导入</b><input id="sheet-json-upload" type="file" accept="application/json,.json" onChange={(event) => void importSheet(event)} /></label></div>
        <div className="sprite-video-import"><div className="sprite-section-label">视频抽帧</div><label className="sprite-video-input" htmlFor="sprite-video-upload"><span>{videoFile?.name ?? '选择本地视频'}</span><b>选择</b><input id="sprite-video-upload" type="file" accept="video/*" onChange={(event) => void handleVideo(event)} /></label>{videoFile ? <><label className="sprite-control"><span>开始时间</span><input type="number" min="0" step=".01" value={videoStart} onChange={(event) => setVideoStart(Number(event.target.value))} /></label><label className="sprite-control"><span>结束时间</span><input type="number" min={videoStart} max={videoLimit} step=".01" value={effectiveVideoEnd} onChange={(event) => setVideoEnd(Number(event.target.value))} /></label><label className="sprite-control"><span>FPS</span><input type="number" min="1" max="60" value={videoFps} onChange={(event) => setVideoFps(Math.max(1, Math.min(60, Number(event.target.value) || 1)))} /></label><button type="button" className="sprite-video-extract" disabled={extracting} onClick={() => void extractVideo()}>{extracting ? '提取中…' : `提取 ${requestedVideoFrames} 帧`}</button></> : null}</div>
        {source && frames.length === 1 && !videoFile ? <div className="sprite-motion-box"><div className="sprite-section-label">单图动作草稿</div><p>用轻微位移、缩放和旋转生成基础动效，不会改变角色姿态。</p><div className="sprite-motion-controls"><select value={motionPreset} onChange={(event) => setMotionPreset(event.target.value as SyntheticMotionPreset)}><option value="idle">待机</option><option value="walk">行走近似</option><option value="attack">攻击近似</option><option value="hit">受击近似</option></select><select value={motionDirection} onChange={(event) => setMotionDirection(event.target.value as SyntheticMotionDirection | '')}><option value="">原方向</option><option value="right">向右</option><option value="left">向左（水平翻转）</option></select></div><button type="button" className="sprite-motion-generate" disabled={generatingMotion} onClick={() => void generateMotion()}>{generatingMotion ? '生成中…' : '生成 4 帧动作草稿'}</button></div> : null}
      </details>
      <details className="sprite-collapsible" open><summary>动画分组</summary><div className="sprite-animation-editor"><div className="sprite-animation-tabs">{clips.map((clip) => <button type="button" className={activeClip?.id === clip.id ? 'active' : ''} key={clip.id} onClick={() => selectClip(clip)}>{clip.label}<small>{clip.frameIndices.length} 帧</small></button>)}<button type="button" className="add" onClick={addClip}>+ 新建动画</button></div>{activeClip ? <><label className="sprite-control"><span>动画名称</span><input value={activeClip.label} onChange={(event) => updateClip({ label: event.target.value })} /></label><div className="sprite-animation-settings"><label className="sprite-control"><span>默认 FPS</span><input type="number" min="1" max="240" value={activeClip.fps} onChange={(event) => updateClip({ fps: Math.max(1, Math.min(240, Number(event.target.value) || 1)) })} /></label><label className="sprite-loop-toggle"><input type="checkbox" checked={activeClip.loop} onChange={(event) => updateClip({ loop: event.target.checked })} /> 循环</label></div></> : <p className="sprite-message">导入帧后创建动画分组。</p>}</div></details>
      <details className="sprite-collapsible" open><summary>导出设置</summary><label className="sprite-control"><span>预览模板（可选）</span><select value={previewTemplateId} onChange={(event) => selectPreviewTemplate(event.target.value)}><option value="freeform">自由画布</option>{PREVIEW_TEMPLATES.map((item) => <option key={item.id} value={item.id}>{item.label} · {item.canvas.width} × {item.canvas.height}</option>)}</select></label><label className="sprite-control"><span>Fit 模式</span><select value={fitMode} onChange={(event) => setFitMode(event.target.value as 'contain' | 'cover')}><option value="contain">Contain</option><option value="cover">Cover</option></select></label><label className="sprite-control"><span>透明边距 px</span><input type="number" min="0" max="1024" value={padding} onChange={(event) => setPadding(Math.max(0, Number(event.target.value) || 0))} /></label><div className="sprite-canvas-result"><span>统一画布</span><strong>{canvasSize.width} × {canvasSize.height} · 原点 {anchor.x},{anchor.y}</strong></div><button type="button" className="sprite-reset" onClick={resetPlacement}>恢复当前放置</button><button type="button" className="sprite-export" disabled={!frames.length || measuring} onClick={measureCanvas}>{measuring ? '计算中…' : '计算全角色统一画布'}</button><button type="button" className="sprite-export" disabled={!frames.length} onClick={() => void exportSheet()}>导出 Sheet + JSON</button>{!validation.ok ? <div className="sprite-validation-error">{validation.issues.map((issue) => <div key={`${issue.code}-${issue.path}`}>{issue.message}</div>)}</div> : <div className="sprite-validation-ok">SpriteResource 校验通过</div>}<p className="sprite-message" role="status">{message}</p></details>
    </aside><div className="sprite-workbench">
      <section className="sprite-canvas-panel"><div className="sprite-panel-top"><div><span className="sprite-eyebrow">实时画布</span><strong>{currentFrame ? `${frames.length === 1 ? `${currentFrame.width} × ${currentFrame.height}` : `${canvasSize.width} × ${canvasSize.height}`} · 第 ${displayFrame + 1} 帧` : '等待导入帧'}</strong></div><span className="sprite-guide-key">{frames.length === 1 ? '红框 = 切格 · 拖动 = 移动整套网格' : '青色 = 原点 · 紫色 = 统一画布'}</span></div><div className="sprite-canvas-wrap"><canvas ref={canvasRef} onPointerDown={pointerDown} onPointerMove={pointerMove} onPointerUp={pointerUp} onPointerCancel={pointerUp} aria-label="Sprite preview" /></div><div className="sprite-canvas-caption"><span><i className="cyan-dot" /> {frames.length === 1 ? '拖动网格调整起点 X/Y；左侧数字可精确校准' : '拖动画布中的帧可以校准当前帧偏移'}</span><span><i className="violet-dot" /> {frames.length === 1 ? `当前偏移 ${gridOffsetX}, ${gridOffsetY}` : '所有动画导出共享同一尺寸和原点'}</span></div></section>
      <section className="sprite-frame-panel"><div className="sprite-panel-top"><div><span className="sprite-eyebrow">FRAME STRIP</span><strong>{frames.length ? `${frames.length} 个原始帧` : '等待导入帧'}</strong></div><div className="sprite-frame-actions"><button type="button" className="play" disabled={playableFrames.length < 2} onClick={() => { const nextPlaying = !isPlaying; if (nextPlaying && playableFrames.length) { setPlaybackPosition(0); setActiveFrame(playableFrames[0]); setPreviewFrame(playableFrames[0]) }; setIsPlaying(nextPlaying) }}>{isPlaying ? '暂停' : '播放'}</button><button type="button" disabled={!frames.length || cleaning || Boolean(preCleanupFrames)} onClick={() => void cleanupBackground()}>{cleaning ? '处理中…' : '清理背景'}</button>{preCleanupFrames ? <button type="button" onClick={restoreCleanup}>恢复原始</button> : null}<button type="button" disabled={!frames[activeFrame]} onClick={deleteFrame}>删除当前帧</button></div></div><div className="sprite-frames">{frames.map((frame, index) => <button type="button" key={frame.id} draggable onDragStart={(event) => { setDragFrameIndex(index); event.dataTransfer.setData('text/plain', String(index)) }} onDragOver={(event) => event.preventDefault()} onDrop={() => { if (dragFrameIndex !== null) reorderFrames(dragFrameIndex, index); setDragFrameIndex(null) }} onDragEnd={() => setDragFrameIndex(null)} className={`sprite-frame ${index === activeFrame ? 'active' : ''} ${index === previewFrame && isPlaying ? 'previewing' : ''} ${frame.disabled ? 'disabled' : ''} ${dragFrameIndex === index ? 'dragging' : ''}`} onClick={() => { setActiveFrame(index); setPreviewFrame(index); setIsPlaying(false) }}><span>{String(index + 1).padStart(2, '0')}</span><img src={frame.url} alt="" /><small>{Math.round(frame.durationMs)}ms{frame.disabled ? ' · OFF' : ''}</small></button>)}</div>{currentFrame ? <div className="sprite-frame-adjustments"><div className="sprite-adjustment-head"><span>第 {activeFrame + 1} 帧 · 源帧 {currentFrame.sourceFrameIndex + 1}</span><button type="button" onClick={() => setFrameTransforms((current) => current.map((value, index) => index === activeFrame ? { ...DEFAULT_TRANSFORM } : value))}>恢复当前帧</button></div><div className="sprite-adjustment-controls"><label className="sprite-control"><span>时长 ms</span><input type="number" min="1" max="60000" value={Math.round(currentFrame.durationMs)} onChange={(event) => updateFrame({ durationMs: Math.max(1, Number(event.target.value) || 1) })} /></label><label className="sprite-control"><span>缩放 <output>{transform.scale}%</output></span><input type="range" min="10" max="300" value={transform.scale} onChange={(event) => updateTransform('scale', Number(event.target.value))} /></label><label className="sprite-control"><span>偏移 X <output>{transform.offsetX}px</output></span><input type="range" min="-1024" max="1024" value={transform.offsetX} onChange={(event) => updateTransform('offsetX', Number(event.target.value))} /></label><label className="sprite-control"><span>偏移 Y <output>{transform.offsetY}px</output></span><input type="range" min="-1024" max="1024" value={transform.offsetY} onChange={(event) => updateTransform('offsetY', Number(event.target.value))} /></label><label className="sprite-loop-toggle"><input type="checkbox" checked={currentFrame.disabled} onChange={(event) => updateFrame({ disabled: event.target.checked })} /> 禁用此帧</label></div></div> : null}</section>
       <div className="sprite-legacy-actions"><button type="button" disabled={frames.length < 2} onClick={reverseFrames}>反转帧序</button><button type="button" disabled={!frames.length || !templateFrameTarget() || frames.length >= templateFrameTarget()} onClick={fillFramesToTemplate}>{templateFrameTarget() && frames.length < templateFrameTarget() ? `自动补齐到 ${templateFrameTarget()} 帧` : '自动补齐'}</button><button type="button" disabled={!frames.length} onClick={() => void exportFramesZip()}>导出原始帧 ZIP</button></div>
       <section className="sprite-animation-editor sprite-workbench-animation"><div className="sprite-panel-top"><div><span className="sprite-eyebrow">ANIMATION GROUP</span><strong>{activeClip ? `${activeClip.label} · ${activeClip.frameIndices.length} 帧` : '没有动画分组'}</strong><small className="sprite-playback-order">播放顺序：{playableFrames.length ? playableFrames.map((index) => index + 1).join(' → ') : '暂无可播放帧'}</small></div></div>{activeClip ? <div className="sprite-animation-row">{activeClip.frameIndices.map((index, position) => <button type="button" draggable key={`${index}-${position}`} className={`${index === activeFrame ? 'active' : ''} ${dragClipPosition === position ? 'dragging' : ''}`} onDragStart={(event) => { setDragClipPosition(position); event.dataTransfer.setData('application/x-animation-position', String(position)) }} onDragOver={(event) => event.preventDefault()} onDrop={(event) => { event.preventDefault(); event.stopPropagation(); if (dragClipPosition !== null) reorderClipFrames(dragClipPosition, position); setDragClipPosition(null) }} onDragEnd={() => setDragClipPosition(null)} onClick={() => { setActiveFrame(index); setPreviewFrame(index); setPlaybackPosition(position); setIsPlaying(false) }}>{index + 1}<small>{Math.round(frames[index]?.durationMs ?? 0)}ms</small><i title="移出动画" onClick={(event) => { event.stopPropagation(); removeFrameFromClip(index) }}>×</i></button>)}{!activeClip.frameIndices.length ? <em>从下方帧条拖入帧，或点击帧后使用动画分组。</em> : null}</div> : null}</section>
      <section className="sprite-manifest-panel"><div className="sprite-panel-top"><div><span className="sprite-eyebrow">RE-IMPORTABLE PACKAGE</span><strong>spritesheet.json</strong></div><span className="sprite-json-dot" /></div><pre>{JSON.stringify(manifest, null, 2)}</pre></section>
    </div></section>
    {showHelp ? <div className="sprite-help-backdrop" role="presentation" onClick={() => setShowHelp(false)}><section className="sprite-help-modal" role="dialog" aria-modal="true" onClick={(event) => event.stopPropagation()}><div className="sprite-help-head"><div><span className="sprite-eyebrow">FRAME TUNER LITE MODEL</span><h3>先调校，再导出</h3></div><button type="button" onClick={() => setShowHelp(false)}>×</button></div><ol className="sprite-help-steps"><li>导入 PNG 序列，或先选择 Sheet PNG 再导入对应 JSON。</li><li>原始帧不会在导入时被统一缩放，帧卡上的时长和禁用状态会保留。</li><li>创建动画分组，把同一帧池中的帧按动作加入并排序。</li><li>在画布中校准当前帧偏移，点击“计算全角色统一画布”。</li><li>导出 ZIP，里面只有可重新导入的 `spritesheet.png` 和 `spritesheet.json`。</li></ol><p className="sprite-help-note">这是通用序列帧工具，不绑定 Godot、Unity 或任何固定角色模板。</p><button type="button" className="sprite-help-close" onClick={() => setShowHelp(false)}>开始使用</button></section></div> : null}
  </main>
}
