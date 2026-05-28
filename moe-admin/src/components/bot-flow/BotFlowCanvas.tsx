import { useCallback, useEffect, useMemo, useRef } from 'react'
import {
  ReactFlow,
  Background,
  Controls,
  MiniMap,
  ReactFlowProvider,
  addEdge,
  useNodesState,
  useEdgesState,
  type Connection,
  type Edge,
  type Node,
  type NodeChange,
  type ReactFlowInstance,
} from '@xyflow/react'
import '@xyflow/react/dist/style.css'
import type { MoeBotFlowData, MoeFlowEdgeItem, MoeFlowNodeItem } from '../../api/adminClient'
import {
  HUB_CORE_ID,
  toHubView,
  toolSlotPosition,
} from '../../lib/botFlowHub'
import {
  type FlowNodeStatus,
  type StepLike,
  type ToolInvokeLike,
  type ToolNodeStatus,
  globalRunMode,
  mapToolsToNodeStatus,
} from '../../lib/botFlowTemplate'
import { CoreFlowNode, ToolFlowNode, type BotFlowNodeData } from './botFlowNodes'

const nodeTypes = {
  core: CoreFlowNode,
  tool: ToolFlowNode,
}

const CORE_ID = HUB_CORE_ID

function buildCoreData(agentLabel: string, mode: ReturnType<typeof globalRunMode>, linkedCount: number): BotFlowNodeData {
  let st: FlowNodeStatus = 'standby'
  if (mode === 'running') st = 'running'
  else if (mode === 'success') st = 'ok'
  else if (mode === 'failed') st = 'fail'
  return {
    label: agentLabel,
    subtitle: `能力中枢 · 已接入 ${linkedCount} 个工具`,
    status: st,
    statusLabel:
      mode === 'idle' ? '待机' : mode === 'running' ? '运行中' : mode === 'success' ? '正常' : '需关注',
    nodeType: 'core',
  }
}

function buildToolData(
  item: MoeFlowNodeItem,
  linked: boolean,
  toolStatus: Record<string, ToolNodeStatus>,
): BotFlowNodeData {
  let st: FlowNodeStatus = linked ? 'standby' : 'disabled'
  const ts = toolStatus[item.id]
  if (ts === 'called_ok') st = 'ok'
  else if (ts === 'called_fail') st = 'fail'
  return {
    label: item.tool_name ?? item.label,
    subtitle: item.subtitle ?? (linked ? '已接入 Bot' : '未连线'),
    status: st,
    statusLabel: linked ? (st === 'ok' ? '已调用' : st === 'fail' ? '失败' : '已接入') : '未接入',
    nodeType: 'tool',
  }
}

function toFlowNodes(
  hub: MoeBotFlowData,
  agentLabel: string,
  mode: ReturnType<typeof globalRunMode>,
  toolStatus: Record<string, ToolNodeStatus>,
): Node[] {
  const core = hub.nodes.find((n) => n.id === CORE_ID) ?? hub.nodes.find((n) => n.type === 'core')
  if (!core) return []
  const linkedIds = new Set(
    hub.edges.filter((e) => e.target === CORE_ID).map((e) => e.source),
  )
  const out: Node[] = [
    {
      id: CORE_ID,
      type: 'core',
      position: { x: core.position_x, y: core.position_y },
      draggable: true,
      selectable: true,
      deletable: false,
      data: buildCoreData(agentLabel, mode, linkedIds.size),
    },
  ]
  for (const t of hub.nodes.filter((n) => n.type === 'tool')) {
    out.push({
      id: t.id,
      type: 'tool',
      position: { x: t.position_x, y: t.position_y },
      draggable: true,
      selectable: true,
      deletable: true,
      data: buildToolData(t, linkedIds.has(t.id), toolStatus),
    })
  }
  return out
}

function toFlowEdges(hub: MoeBotFlowData): Edge[] {
  return hub.edges
    .filter((e) => e.target === CORE_ID || e.source === CORE_ID)
    .map((e) => ({
      id: e.id,
      source: e.source === CORE_ID ? e.target : e.source,
      target: CORE_ID,
      style: { stroke: 'rgba(145, 234, 228, 0.85)', strokeWidth: 2, strokeDasharray: '6 4' },
    }))
}

function flowNodesToApi(nodes: Node[]): MoeFlowNodeItem[] {
  return nodes.map((n) => {
    const d = n.data as BotFlowNodeData
    return {
      id: n.id,
      type: d.nodeType,
      label: d.nodeType === 'core' ? 'Moe Bot' : d.label,
      subtitle: d.subtitle,
      tool_name: d.nodeType === 'tool' ? d.label : undefined,
      position_x: n.position.x,
      position_y: n.position.y,
      enabled: d.nodeType === 'tool' ? d.statusLabel !== '未接入' : true,
    }
  })
}

function flowEdgesToApi(edges: Edge[]): MoeFlowEdgeItem[] {
  return edges.map((e) => ({
    id: e.id,
    source: e.source,
    target: e.target,
    kind: 'capability',
  }))
}

type Props = {
  agentLabel: string
  flow: MoeBotFlowData
  tools: Array<{ name: string; description: string }>
  steps: StepLike[]
  toolsInvoked: ToolInvokeLike[]
  hasRun: boolean
  ok: boolean
  runFeedback?: string
  saving: boolean
  onSave: (payload: {
    nodes: MoeFlowNodeItem[]
    edges: MoeFlowEdgeItem[]
    viewport_zoom?: number
    viewport_x?: number
    viewport_y?: number
  }) => Promise<void>
}

function BotFlowCanvasInner({
  agentLabel,
  flow,
  tools,
  steps,
  toolsInvoked,
  hasRun,
  ok,
  runFeedback,
  saving,
  onSave,
}: Props) {
  const rfRef = useRef<ReactFlowInstance | null>(null)
  const hubFlow = useMemo(() => toHubView(flow, agentLabel), [flow, agentLabel])
  const mode = globalRunMode(hasRun, ok, steps)
  const nodeMeta = useMemo(
    () => hubFlow.nodes.map((n) => ({ id: n.id, type: n.type, tool_name: n.tool_name })),
    [hubFlow.nodes],
  )
  const toolStatus = useMemo(() => mapToolsToNodeStatus(nodeMeta, toolsInvoked), [nodeMeta, toolsInvoked])

  const layoutKey = `${flow.agent_key}:${flow.updated_at ?? 'init'}:${hubFlow.nodes.length}`

  const [nodes, setNodes, onNodesChange] = useNodesState<Node>([])
  const [edges, setEdges, onEdgesChange] = useEdgesState<Edge>([])

  useEffect(() => {
    setNodes(toFlowNodes(hubFlow, agentLabel, mode, toolStatus))
    setEdges(toFlowEdges(hubFlow))
    const t = window.setTimeout(() => rfRef.current?.fitView({ padding: 0.25, duration: 200 }), 80)
    return () => window.clearTimeout(t)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [layoutKey])

  useEffect(() => {
    const linkedIds = new Set(edges.filter((e) => e.target === CORE_ID).map((e) => e.source))
    setNodes((nds) =>
      nds.map((n) => {
        const d = n.data as BotFlowNodeData
        if (d.nodeType === 'core') {
          return { ...n, data: buildCoreData(agentLabel, mode, linkedIds.size) }
        }
        const item = hubFlow.nodes.find((x) => x.id === n.id)
        if (!item || item.type !== 'tool') return n
        return { ...n, data: buildToolData(item, linkedIds.has(n.id), toolStatus) }
      }),
    )
  }, [edges, toolStatus, mode, agentLabel, hubFlow.nodes, setNodes])

  const handleNodesChange = useCallback(
    (changes: NodeChange[]) => {
      const safe = changes.filter((ch) => {
        if (ch.type === 'remove' && 'id' in ch && ch.id === CORE_ID) return false
        return true
      })
      onNodesChange(safe)
    },
    [onNodesChange],
  )

  const onConnect = useCallback(
    (conn: Connection) => {
      if (!conn.source || !conn.target) return
      const other = conn.source === CORE_ID ? conn.target : conn.source
      if (other === CORE_ID) return
      setEdges((eds) => {
        const filtered = eds.filter((e) => e.source !== other)
        return addEdge(
          {
            id: `cap-${other}-${CORE_ID}`,
            source: other,
            target: CORE_ID,
            style: { stroke: 'rgba(145, 234, 228, 0.85)', strokeWidth: 2, strokeDasharray: '6 4' },
          },
          filtered,
        )
      })
    },
    [setEdges],
  )

  const deleteSelected = useCallback(() => {
    setNodes((nds) => nds.filter((n) => !n.selected || n.id === CORE_ID))
    setEdges((eds) => eds.filter((e) => !e.selected))
  }, [setNodes, setEdges])

  const persist = useCallback(async () => {
    const inst = rfRef.current
    const vp = inst?.getViewport()
    await onSave({
      nodes: flowNodesToApi(nodes),
      edges: flowEdgesToApi(edges),
      viewport_zoom: vp?.zoom,
      viewport_x: vp?.x,
      viewport_y: vp?.y,
    })
  }, [nodes, edges, onSave])

  const onNodesDelete = useCallback(
    (deleted: Node[]) => {
      if (deleted.some((n) => n.id === CORE_ID)) return
      const removed = new Set(deleted.map((n) => n.id))
      setEdges((eds) => eds.filter((e) => !removed.has(e.source) && !removed.has(e.target)))
    },
    [setEdges],
  )

  const addToolNode = useCallback(
    (tool: { name: string; description: string }) => {
      const toolId = `tool-${tool.name}`
      setNodes((nds) => {
        if (nds.some((n) => n.id === toolId)) return nds
        const core = nds.find((n) => n.id === CORE_ID)
        const cx = core?.position.x ?? 420
        const cy = core?.position.y ?? 220
        const toolCount = nds.filter((n) => (n.data as BotFlowNodeData).nodeType === 'tool').length
        const pos = toolSlotPosition(cx, cy, toolCount)
        return [
          ...nds,
          {
            id: toolId,
            type: 'tool',
            position: pos,
            draggable: true,
            deletable: true,
            data: {
              label: tool.name,
              subtitle: tool.description || '工具',
              status: 'standby',
              statusLabel: '已接入',
              nodeType: 'tool',
            } satisfies BotFlowNodeData,
          },
        ]
      })
      setEdges((eds) => {
        if (eds.some((e) => e.source === toolId && e.target === CORE_ID)) return eds
        return [
          ...eds.filter((e) => e.source !== toolId),
          {
            id: `cap-${toolId}-${CORE_ID}`,
            source: toolId,
            target: CORE_ID,
            style: { stroke: 'rgba(145, 234, 228, 0.85)', strokeWidth: 2, strokeDasharray: '6 4' },
          },
        ]
      })
    },
    [setNodes, setEdges],
  )

  const linkedCount = edges.filter((e) => e.target === CORE_ID).length

  return (
    <div className={`bot-flow-canvas-wrap bot-flow-mode--${mode}`}>
      {runFeedback ? <p className="muted bot-flow-feedback">{runFeedback}</p> : null}
      <div className="bot-flow-toolbar">
        <span className="muted">
          中心是 Bot；点「+ 工具」接入；选中后按 Delete 删除；连线拖到 Bot 圆点。发帖步骤在「AI 大脑」查看。
        </span>
        <div className="btn-row">
          {tools.map((t) => (
            <button key={t.name} type="button" className="btn btn-ghost btn-sm" onClick={() => addToolNode(t)}>
              + {t.name}
            </button>
          ))}
          <button type="button" className="btn btn-ghost btn-sm" onClick={deleteSelected}>
            删除选中
          </button>
          <button type="button" className="btn btn-primary btn-sm" disabled={saving} onClick={() => void persist()}>
            {saving ? '保存中…' : '保存'}
          </button>
        </div>
      </div>
      <div className="bot-flow-rf">
        <ReactFlow
          nodes={nodes}
          edges={edges}
          onNodesChange={handleNodesChange}
          onEdgesChange={onEdgesChange}
          onConnect={onConnect}
          onNodesDelete={onNodesDelete}
          nodeTypes={nodeTypes}
          deleteKeyCode={['Backspace', 'Delete']}
          fitView
          minZoom={0.35}
          maxZoom={1.4}
          onInit={(inst) => {
            rfRef.current = inst
            window.setTimeout(() => inst.fitView({ padding: 0.25 }), 50)
          }}
          proOptions={{ hideAttribution: true }}
        >
          <Background gap={20} color="rgba(127,127,213,0.1)" />
          <Controls />
          <MiniMap pannable zoomable />
        </ReactFlow>
      </div>
      <p className="muted bot-flow-hint">
        Bot 主体 1 个 · 已接入工具 {linkedCount} 个 · 拖动布局后点保存
      </p>
    </div>
  )
}

export function BotFlowCanvas(props: Props) {
  return (
    <ReactFlowProvider>
      <BotFlowCanvasInner {...props} />
    </ReactFlowProvider>
  )
}
