/** Bot 能力 hub：中心 Bot + 工具卡片接入（画布展示用） */

import type { MoeBotFlowData, MoeFlowEdgeItem } from '../api/adminClient'

export const HUB_CORE_ID = 'core'
export const HUB_CENTER = { x: 420, y: 220 }

export function hubDefaultFlow(agentKey: string): MoeBotFlowData {
  return {
    agent_key: agentKey,
    version: 2,
    entry_node_id: HUB_CORE_ID,
    is_default: true,
    nodes: [
      {
        id: HUB_CORE_ID,
        type: 'core',
        label: 'Moe Bot',
        subtitle: '主体 · 接入的工具可在能力范围内调用',
        position_x: HUB_CENTER.x,
        position_y: HUB_CENTER.y,
      },
    ],
    edges: [],
  }
}

/** 旧版线性步骤图转为 hub 视图（步骤节点隐藏，只保留 Bot + 工具） */
export function toHubView(flow: MoeBotFlowData, agentLabel: string): MoeBotFlowData {
  let core = flow.nodes.find((n) => n.type === 'core')
  if (!core) {
    core = {
      id: HUB_CORE_ID,
      type: 'core',
      label: 'Moe Bot',
      subtitle: `${agentLabel} · 能力中枢`,
      position_x: HUB_CENTER.x,
      position_y: HUB_CENTER.y,
    }
  }
  const tools = flow.nodes.filter((n) => n.type === 'tool')
  const toolIds = new Set(tools.map((t) => t.id))
  const edges: MoeFlowEdgeItem[] = []
  const seen = new Set<string>()
  for (const e of flow.edges) {
    const linksCore = e.source === core.id || e.target === core.id
    const linksTool = toolIds.has(e.source) || toolIds.has(e.target)
    if (linksCore && linksTool) {
      const norm = normalizeToolToCoreEdge(e, core.id)
      if (!seen.has(norm.source)) {
        edges.push(norm)
        seen.add(norm.source)
      }
    }
  }
  for (const t of tools) {
    if (seen.has(t.id)) continue
    edges.push({
      id: `cap-${t.id}-${core.id}`,
      source: t.id,
      target: core.id,
      kind: 'capability',
    })
    seen.add(t.id)
  }
  return {
    ...flow,
    nodes: [core, ...tools],
    edges,
  }
}

/** 工具 → Bot 方向（能力接入） */
export function normalizeToolToCoreEdge(e: MoeFlowEdgeItem, coreId: string): MoeFlowEdgeItem {
  if (e.target === coreId) {
    return { ...e, source: e.source, target: coreId, kind: 'capability' }
  }
  return { id: e.id, source: e.source, target: coreId, kind: 'capability' }
}

export function toolSlotPosition(coreX: number, coreY: number, index: number): { x: number; y: number } {
  const radius = 200
  const angle = (-90 + index * 42) * (Math.PI / 180)
  return {
    x: coreX + radius * Math.cos(angle),
    y: coreY + radius * Math.sin(angle),
  }
}

export function connectedToolNames(edges: MoeFlowEdgeItem[], coreId: string = HUB_CORE_ID): Set<string> {
  const names = new Set<string>()
  for (const e of edges) {
    if (e.target === coreId) {
      names.add(e.source)
    }
    if (e.source === coreId && e.target.startsWith('tool-')) {
      names.add(e.target)
    }
  }
  return names
}
