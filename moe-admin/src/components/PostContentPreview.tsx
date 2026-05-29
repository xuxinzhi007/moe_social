import { useMemo } from 'react'
import { usePlatform } from '../context/PlatformContext'
import { useDirectAdminApi } from '../lib/adminApi'
import { resolveMediaViewUrl } from '../lib/mediaUrl'

type Props = {
  content?: string
  images?: string[]
  handDrawThumbUrl?: string
  compact?: boolean
}

export function PostContentPreview({ content, images, handDrawThumbUrl, compact = false }: Props) {
  const { apiTarget, health } = usePlatform()
  const devDirect = useDirectAdminApi()
  const apiBase = useMemo(() => {
    const h = apiTarget === 'cloud' ? health?.cloud_api : health?.local_api
    return h?.base_url?.replace(/\/$/, '') || ''
  }, [apiTarget, health])

  const mediaUrls = useMemo(() => {
    const urls: string[] = []
    if (handDrawThumbUrl?.trim()) {
      urls.push(
        resolveMediaViewUrl(handDrawThumbUrl.trim(), apiBase, devDirect, apiTarget),
      )
    }
    for (const img of images || []) {
      const s = img.trim()
      if (!s) continue
      urls.push(resolveMediaViewUrl(s, apiBase, devDirect, apiTarget))
    }
    return urls
  }, [apiBase, apiTarget, devDirect, handDrawThumbUrl, images])

  const text = content?.trim()
  const hasText = Boolean(text)
  const hasMedia = mediaUrls.length > 0

  if (!hasText && !hasMedia) {
    return <span className="muted">—</span>
  }

  return (
    <div className="post-content-preview">
      {hasText ? (
        <p
          className="post-content-preview-text"
          style={
            compact
              ? { margin: 0, display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }
              : { margin: 0, whiteSpace: 'pre-wrap', wordBreak: 'break-word' }
          }
        >
          {text}
        </p>
      ) : null}
      {hasMedia ? (
        <div className="post-content-preview-media" style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginTop: hasText ? 10 : 0 }}>
          {mediaUrls.map((url) => (
            <a key={url} href={url} target="_blank" rel="noreferrer" className="post-content-preview-thumb">
              <img
                src={url}
                alt=""
                loading="lazy"
                style={{
                  display: 'block',
                  maxWidth: compact ? 120 : '100%',
                  maxHeight: compact ? 80 : 320,
                  borderRadius: 8,
                  border: '1px solid var(--hairline)',
                  objectFit: 'contain',
                  background: 'var(--canvas)',
                }}
              />
            </a>
          ))}
        </div>
      ) : null}
    </div>
  )
}
