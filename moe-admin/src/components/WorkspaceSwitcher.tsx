import { useNavigate } from 'react-router-dom'
import { WORKSPACES, type WorkspaceId } from '../config/workspaceNav'

type WorkspaceSwitcherProps = {
  active: WorkspaceId
}

/** 顶栏三段工作区切换：运营 | AI | 运维 */
export function WorkspaceSwitcher({ active }: WorkspaceSwitcherProps) {
  const navigate = useNavigate()

  return (
    <div className="ws-switch" role="tablist" aria-label="工作区">
      {WORKSPACES.map((ws) => {
        const isActive = ws.id === active
        return (
          <button
            key={ws.id}
            type="button"
            role="tab"
            aria-selected={isActive}
            className={`ws-switch-btn${isActive ? ' is-active' : ''}`}
            title={ws.caption}
            onClick={() => {
              if (!isActive) navigate(ws.home)
            }}
          >
            {ws.label}
          </button>
        )
      })}
    </div>
  )
}
