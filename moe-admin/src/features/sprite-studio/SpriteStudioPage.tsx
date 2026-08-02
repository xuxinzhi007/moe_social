import { SpriteRepairPage } from './SpriteRepairPage'
import './sprite-studio.css'

export function SpriteStudioPage() {
  return (
    <div className="sprite-studio-shell">
      <nav className="sprite-studio-mode-switch" aria-label="序列帧整理工作台">
        <div>
          <span>MOE ANIMATION SHEET WORKBENCH</span>
          <strong>序列帧整理工作台</strong>
        </div>
        <span className="sprite-studio-workbench-note">导入 → 整理 → 对齐 → 导出</span>
      </nav>
      <SpriteRepairPage />
    </div>
  )
}
