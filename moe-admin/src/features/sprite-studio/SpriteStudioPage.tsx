import { useState } from 'react'
import { AvatarComposerPage } from './AvatarComposerPage'
import { SpriteRepairPage } from './SpriteRepairPage'
import './sprite-studio.css'

type StudioMode = 'composer' | 'repair'

export function SpriteStudioPage() {
  const [mode, setMode] = useState<StudioMode>('composer')

  return (
    <div className="sprite-studio-shell">
      <nav className="sprite-studio-mode-switch" aria-label="Sprite Studio 工作模式">
        <div>
          <span>MOE SPRITE STUDIO</span>
          <strong>角色资源工作台</strong>
        </div>
        <div className="sprite-studio-mode-tabs">
          <button type="button" className={mode === 'composer' ? 'active' : ''} onClick={() => setMode('composer')}>角色生成器</button>
          <button type="button" className={mode === 'repair' ? 'active' : ''} onClick={() => setMode('repair')}>Sprite 修整器</button>
        </div>
      </nav>
      {mode === 'composer' ? <AvatarComposerPage /> : <SpriteRepairPage />}
    </div>
  )
}
