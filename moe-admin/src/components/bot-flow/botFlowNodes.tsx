import { memo } from 'react'
import { Handle, Position, type NodeProps } from '@xyflow/react'
import { AdminTag } from '../AdminTag'
import type { TagTone } from '../../lib/adminLabels'
import type { FlowNodeStatus } from '../../lib/botFlowTemplate'

export type BotFlowNodeData = {
  label: string
  subtitle: string
  status: FlowNodeStatus
  statusLabel: string
  nodeType: 'core' | 'step' | 'tool'
}

function statusTone(st: FlowNodeStatus): TagTone {
  switch (st) {
    case 'ok':
      return 'ok'
    case 'fail':
      return 'fail'
    case 'running':
      return 'warn'
    default:
      return 'neutral'
  }
}

function FlowNodeBody({ data }: NodeProps) {
  const d = data as BotFlowNodeData
  const isCore = d.nodeType === 'core'
  const isTool = d.nodeType === 'tool'
  const label = d.label?.trim() ? d.label : isCore ? 'Moe Bot' : '节点'
  return (
    <div
      className={`bot-flow-node bot-flow-node--${d.status} ${isCore ? 'bot-flow-node--core' : ''} ${isTool ? 'bot-flow-node--tool' : ''}`}
    >
      <Handle type="target" position={Position.Left} className="bot-flow-handle" />
      <div className="bot-flow-node-head">
        <strong>{label}</strong>
        <AdminTag label={d.statusLabel} tone={statusTone(d.status)} />
      </div>
      <span className="muted bot-flow-node-sub">{d.subtitle}</span>
      <Handle type="source" position={Position.Right} className="bot-flow-handle" />
    </div>
  )
}

export const CoreFlowNode = memo(FlowNodeBody)
export const StepFlowNode = memo(FlowNodeBody)
export const ToolFlowNode = memo(FlowNodeBody)
