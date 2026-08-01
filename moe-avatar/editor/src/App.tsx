import { useEffect, useMemo, useRef, useState } from 'react'
import {
  AVATAR_TEMPLATE_PRESETS,
  AVATAR_TEMPLATE_EXAMPLES,
  AvatarAssetStore,
  collectManifestAssets,
  composeTemplateSheet,
  createManifestFromTemplate,
  downloadBlob,
  drawSheetFrame,
  exportMoePackZip,
  itemIdsForTemplateSlot,
  itemLabel,
  layerThumbCanvas,
  resolveTemplateLayerPaths,
  validateManifestAgainstTemplate,
  templatePresetDescription,
  templatePresetLabel,
  type AvatarTemplateId,
  type MoeAvatarManifest,
  type PreviewAnimation,
  type TemplateSelection,
} from '../../core/src'
import { exampleManifest } from './exampleManifest'

type Tab = 'preview' | 'assets' | 'manifest' | 'import'

const TEMPLATE_IDS = Object.keys(AVATAR_TEMPLATE_PRESETS) as AvatarTemplateId[]

function buildSelection(manifest: MoeAvatarManifest, seed: TemplateSelection = {}): TemplateSelection {
  const selection: TemplateSelection = {}
  for (const slot of Object.keys(manifest.slots)) {
    selection[slot] = seed[slot] ?? ''
  }
  return selection
}

function createTemplateSeed(templateId: AvatarTemplateId): MoeAvatarManifest {
  if (templateId === 'base_character') return exampleManifest
  return createManifestFromTemplate(templateId)
}

function slotLabel(slot: string): string {
  return slot
    .split(/[_-]/g)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ')
}

export function App() {
  const assetStoreRef = useRef<AvatarAssetStore | null>(null)
  if (!assetStoreRef.current) assetStoreRef.current = new AvatarAssetStore()
  const assetStore = assetStoreRef.current

  const [templateId, setTemplateId] = useState<AvatarTemplateId>('base_character')
  const [manifest, setManifest] = useState<MoeAvatarManifest>(exampleManifest)
  const [manifestText, setManifestText] = useState(JSON.stringify(exampleManifest, null, 2))
  const [tab, setTab] = useState<Tab>('preview')
  const [selection, setSelection] = useState<TemplateSelection>(() => buildSelection(exampleManifest, {
    hat: '',
    top: 'top_basic',
    bottom: 'bottom_basic',
    shoes: 'shoes_basic',
  }))
  const [activeSlot, setActiveSlot] = useState('top')
  const [anim, setAnim] = useState<PreviewAnimation>('idle')
  const [direction, setDirection] = useState(2)
  const [assetRevision, setAssetRevision] = useState(0)
  const [sheet, setSheet] = useState<HTMLCanvasElement | null>(null)
  const [frame, setFrame] = useState(0)
  const [message, setMessage] = useState('')
  const [error, setError] = useState('')
  const [exporting, setExporting] = useState(false)
  const [importing, setImporting] = useState(false)
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)

  const slotKeys = useMemo(() => Object.keys(manifest.slots), [manifest])
  const activeTemplate = AVATAR_TEMPLATE_PRESETS[templateId]

  useEffect(() => {
    if (!slotKeys.includes(activeSlot)) {
      setActiveSlot(slotKeys[0] ?? '')
    }
  }, [slotKeys, activeSlot])

  useEffect(() => {
    setSelection((current) => buildSelection(manifest, current))
  }, [manifest])

  useEffect(() => {
    void composeTemplateSheet(manifest, selection, anim, '/pet/moe_avatar', assetStore).then((next) => {
      setSheet(next)
    })
  }, [manifest, selection, anim, assetStore, assetRevision])

  useEffect(() => {
    setFrame(0)
  }, [anim, selection, assetRevision])

  useEffect(() => {
    const cols = manifest.animations[anim].cols
    const delay = anim === 'walk' ? 120 : 450
    const timer = window.setInterval(() => {
      setFrame((value) => (value + 1) % cols)
    }, delay)
    return () => window.clearInterval(timer)
  }, [manifest, anim])

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas || !sheet) return
    const ctx = canvas.getContext('2d')
    if (!ctx) return
    ctx.clearRect(0, 0, canvas.width, canvas.height)
    drawSheetFrame(ctx, sheet, manifest, anim, direction, frame, 0, 0, 240)
  }, [sheet, manifest, anim, direction, frame])

  useEffect(() => {
    setDirection((current) => Math.min(current, Math.max(0, manifest.directionRows.length - 1)))
  }, [manifest.directionRows.length])

  const activeItems = useMemo(() => ['', ...itemIdsForTemplateSlot(manifest, activeSlot)], [manifest, activeSlot])
  const activeId = selection[activeSlot] ?? ''
  const assetEntries = useMemo(() => collectManifestAssets(manifest), [manifest])
  const previewPaths = useMemo(() => resolveTemplateLayerPaths(manifest, selection, anim), [manifest, selection, anim])
  const validation = useMemo(() => validateManifestAgainstTemplate(manifest, templateId), [manifest, templateId])

  const updateAsset = async (relPath: string, file: File | null) => {
    if (!file) return
    assetStore.set(relPath, file)
    setAssetRevision((n) => n + 1)
    setMessage(`replaced ${relPath}`)
    setError('')
  }

  const revertAsset = (relPath: string) => {
    assetStore.revoke(relPath)
    setAssetRevision((n) => n + 1)
  }

  const applyManifestText = () => {
    try {
      const parsed = JSON.parse(manifestText) as MoeAvatarManifest
      setManifest(parsed)
      setSelection(buildSelection(parsed, selection))
      setError('')
      setMessage('manifest updated')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'invalid json')
      setMessage('')
    }
  }

  const scaffoldTemplate = (nextTemplateId: AvatarTemplateId) => {
    setTemplateId(nextTemplateId)
    const nextManifest = createTemplateSeed(nextTemplateId)
    setManifest(nextManifest)
    setSelection(buildSelection(nextManifest))
    setManifestText(JSON.stringify(nextManifest, null, 2))
    setActiveSlot(Object.keys(nextManifest.slots)[0] ?? '')
    setMessage(`scaffolded ${templatePresetLabel(nextTemplateId)}`)
    setError('')
  }

  const loadExample = (exampleId: string) => {
    const example = AVATAR_TEMPLATE_EXAMPLES.find((entry) => entry.id === exampleId)
    if (!example) return
    setTemplateId(example.templateId)
    setManifest(example.manifest)
    setSelection(buildSelection(example.manifest, example.selection))
    setManifestText(JSON.stringify(example.manifest, null, 2))
    setActiveSlot(Object.keys(example.manifest.slots)[0] ?? '')
    setMessage(`loaded example ${example.label}`)
    setError('')
  }

  const importManifestFile = async (file: File | null) => {
    if (!file) return
    setImporting(true)
    try {
      const text = await file.text()
      const parsed = JSON.parse(text) as MoeAvatarManifest
      setManifest(parsed)
      setSelection(buildSelection(parsed))
      setManifestText(JSON.stringify(parsed, null, 2))
      setActiveSlot(Object.keys(parsed.slots)[0] ?? '')
      setMessage(`imported ${file.name}`)
      setError('')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'import failed')
      setMessage('')
    } finally {
      setImporting(false)
      if (fileInputRef.current) fileInputRef.current.value = ''
    }
  }

  const onExport = async () => {
    try {
      setExporting(true)
      const blob = await exportMoePackZip({
        manifest,
        packBaseUrl: '/pet/moe_avatar',
        assetStore,
        templateSelection: selection,
        includeBaked: true,
      })
      downloadBlob(blob, `${manifest.packId}.zip`)
      setMessage('exported pack zip')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'export failed')
    } finally {
      setExporting(false)
    }
  }

  return (
    <div className="app-shell">
      <header className="topbar">
        <div>
          <h1>Moe Avatar Editor</h1>
          <p>{manifest.displayName}</p>
        </div>
        <div className="topbar-actions">
          <button className={tab === 'preview' ? 'active' : ''} onClick={() => setTab('preview')}>Preview</button>
          <button className={tab === 'import' ? 'active' : ''} onClick={() => setTab('import')}>Import</button>
          <button className={tab === 'assets' ? 'active' : ''} onClick={() => setTab('assets')}>Assets</button>
          <button className={tab === 'manifest' ? 'active' : ''} onClick={() => setTab('manifest')}>Manifest</button>
          <button className="primary" onClick={() => void onExport()} disabled={exporting}>
            {exporting ? 'Exporting' : 'Export ZIP'}
          </button>
        </div>
      </header>

      <section className="panel template-strip">
        <div className="template-strip-head">
          <strong>Template Registry</strong>
          <span className="muted">{templatePresetLabel(templateId)} · {templatePresetDescription(templateId)}</span>
        </div>
        <div className="template-grid">
          {TEMPLATE_IDS.map((id) => (
            <button key={id} className={templateId === id ? 'active template-card' : 'template-card'} onClick={() => setTemplateId(id)}>
              <span>{templatePresetLabel(id)}</span>
              <small>{templatePresetDescription(id)}</small>
            </button>
          ))}
        </div>
        <div className="actions-row">
          <button className="primary" onClick={() => scaffoldTemplate(templateId)}>Scaffold Current Template</button>
          <button onClick={() => fileInputRef.current?.click()} disabled={importing}>Import Manifest JSON</button>
          <input ref={fileInputRef} type="file" accept="application/json" hidden onChange={(e) => void importManifestFile(e.target.files?.[0] ?? null)} />
          <span className="muted">Current slots: {slotKeys.length || 0}</span>
        </div>
        <div className="example-grid">
          {AVATAR_TEMPLATE_EXAMPLES.map((example) => (
            <button key={example.id} className="example-card" onClick={() => loadExample(example.id)}>
              <strong>{example.label}</strong>
              <small>{example.description}</small>
            </button>
          ))}
        </div>
      </section>

      {(error || message) && <div className={error ? 'alert error' : 'alert'}>{error || message}</div>}

      {tab === 'import' && (
        <section className="panel import-workbench">
          <div className="import-head">
            <div>
              <strong>Import Flow</strong>
              <p className="muted">{activeTemplate.description}</p>
            </div>
            <button className="primary" onClick={() => setTab('assets')}>Go to Assets</button>
          </div>

          <div className="import-grid">
            <div className="import-column">
              <h3>Template Family</h3>
              <div className="template-grid">
                {TEMPLATE_IDS.map((id) => (
                  <button
                    key={id}
                    className={templateId === id ? 'active template-card' : 'template-card'}
                    onClick={() => setTemplateId(id)}
                  >
                    <span>{templatePresetLabel(id)}</span>
                    <small>{templatePresetDescription(id)}</small>
                  </button>
                ))}
              </div>

              <div className="actions-row">
                <button className="primary" onClick={() => scaffoldTemplate(templateId)}>Scaffold Template</button>
                <button onClick={() => fileInputRef.current?.click()} disabled={importing}>Import Manifest</button>
              </div>
              <input ref={fileInputRef} type="file" accept="application/json" hidden onChange={(e) => void importManifestFile(e.target.files?.[0] ?? null)} />
            </div>

            <div className="import-column">
              <h3>Import Steps</h3>
              <ol className="step-list">
                {activeTemplate.importSteps.map((step) => <li key={step}>{step}</li>)}
              </ol>

              <h3>Required Slots</h3>
              <div className="pill-row">
                {activeTemplate.requiredSlots.length ? activeTemplate.requiredSlots.map((slot) => (
                  <span key={slot} className="pill required">{slotLabel(slot)}</span>
                )) : <span className="muted">None</span>}
              </div>

              <h3>Optional Slots</h3>
              <div className="pill-row">
                {activeTemplate.optionalSlots.length ? activeTemplate.optionalSlots.map((slot) => (
                  <span key={slot} className="pill optional">{slotLabel(slot)}</span>
                )) : <span className="muted">None</span>}
              </div>

              <h3>Examples</h3>
              <div className="example-grid">
                {AVATAR_TEMPLATE_EXAMPLES.filter((example) => example.templateId === templateId).map((example) => (
                  <button key={example.id} className="example-card" onClick={() => loadExample(example.id)}>
                    <strong>{example.label}</strong>
                    <small>{example.description}</small>
                  </button>
                ))}
              </div>
            </div>
          </div>

          <div className="validation-box compact">
            <div className="validation-head">
              <strong>Template Check</strong>
              <span className={validation.ok ? 'ok' : 'bad'}>{validation.ok ? 'ok' : 'needs work'}</span>
            </div>
            <div className="validation-list">
              {validation.issues.length ? validation.issues.map((issue, index) => (
                <div key={`${issue.code}-${index}`} className={`issue ${issue.level}`}>
                  <strong>{issue.code}</strong>
                  <span>{issue.message}</span>
                </div>
              )) : <div className="muted">No validation issues.</div>}
            </div>
          </div>
        </section>
      )}

      {tab === 'preview' && (
        <section className="panel grid">
          <div className="preview-card">
            <div className="toolbar">
              <button className={anim === 'idle' ? 'active' : ''} onClick={() => setAnim('idle')}>idle</button>
              <button className={anim === 'walk' ? 'active' : ''} onClick={() => setAnim('walk')}>walk</button>
              {manifest.directionRows.map((label, row) => (
                <button key={label} className={direction === row ? 'active' : ''} onClick={() => setDirection(row)}>
                  {label}
                </button>
              ))}
            </div>
            <canvas ref={canvasRef} width={240} height={240} className="preview-canvas" />
            <div className="hint">{previewPaths.length} layers</div>
          </div>

          <div className="panel-column">
            <div className="slot-switcher">
              {slotKeys.map((slot) => (
                <button key={slot} className={activeSlot === slot ? 'active' : ''} onClick={() => setActiveSlot(slot)}>
                  {slotLabel(slot)}
                </button>
              ))}
            </div>
            <div className="selector-grid">
              {activeItems.map((id) => (
                <button key={id || '__none'} className={id === activeId ? 'asset active' : 'asset'} onClick={() => setSelection((current) => ({ ...current, [activeSlot]: id }))}>
                  {id ? itemLabel(id, manifest, activeSlot) : 'none'}
                </button>
              ))}
            </div>
          </div>
        </section>
      )}

      {tab === 'assets' && (
        <section className="panel assets">
          {assetEntries.map((entry) => (
            <AssetRow
              key={entry.path}
              entry={entry}
              manifest={manifest}
              assetStore={assetStore}
              assetRevision={assetRevision}
              onUpload={updateAsset}
              onRevert={revertAsset}
            />
          ))}
        </section>
      )}

      {tab === 'manifest' && (
        <section className="panel">
          <textarea value={manifestText} onChange={(e) => setManifestText(e.target.value)} spellCheck={false} />
          <div className="actions-row">
            <button className="primary" onClick={applyManifestText}>Apply</button>
          </div>
          <div className="validation-box">
            <div className="validation-head">
              <strong>Validation</strong>
              <span className={validation.ok ? 'ok' : 'bad'}>{validation.ok ? 'ok' : 'needs work'}</span>
            </div>
            <div className="validation-list">
              {validation.issues.length ? validation.issues.map((issue, index) => (
                <div key={`${issue.code}-${index}`} className={`issue ${issue.level}`}>
                  <strong>{issue.code}</strong>
                  <span>{issue.message}</span>
                </div>
              )) : <div className="muted">No validation issues.</div>}
            </div>
          </div>
        </section>
      )}
    </div>
  )
}

function AssetRow({
  entry,
  manifest,
  assetStore,
  assetRevision,
  onUpload,
  onRevert,
}: {
  entry: { path: string; group: 'base' | 'slot'; label: string }
  manifest: MoeAvatarManifest
  assetStore: AvatarAssetStore
  assetRevision: number
  onUpload: (path: string, file: File | null) => Promise<void>
  onRevert: (path: string) => void
}) {
  const ref = useRef<HTMLCanvasElement>(null)
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    void layerThumbCanvas(manifest, entry.path, '/pet/moe_avatar', 64, assetStore).then((thumb) => {
      if (cancelled) return
      const canvas = ref.current
      if (thumb && canvas) {
        const ctx = canvas.getContext('2d')
        if (ctx) {
          ctx.clearRect(0, 0, 64, 64)
          ctx.drawImage(thumb, 0, 0)
        }
      }
      setLoading(false)
    })
    return () => {
      cancelled = true
    }
  }, [entry.path, manifest, assetStore, assetRevision])

  return (
    <div className="asset-row">
      <canvas ref={ref} width={64} height={64} className="thumb" />
      <div className="asset-meta">
        <div className="asset-title">{entry.label}</div>
        <code>{entry.path}</code>
      </div>
      <label className="upload">
        Replace
        <input type="file" accept="image/*" onChange={(e) => void onUpload(entry.path, e.target.files?.[0] ?? null)} />
      </label>
      <button onClick={() => onRevert(entry.path)} disabled={!assetStore.has(entry.path)}>Revert</button>
      {loading && <span className="muted">...</span>}
    </div>
  )
}
