import { useMemo } from 'react'
import type { MoeAvatarManifest } from '../types'
import { findDuplicateAssetPaths } from '../editor/manifestIntegrity'

/** 说明：格线 sheet 过渡 vs 官方锚点模型（用户预期） */
export function AvatarArchitectureNotice({ manifest }: { manifest: MoeAvatarManifest }) {
  const dupes = useMemo(() => findDuplicateAssetPaths(manifest), [manifest])
  const dupeCount = dupes.size

  return (
    <div
      style={{
        border: '1px solid #d4c4b8',
        borderRadius: 12,
        padding: 12,
        marginBottom: 16,
        background: 'linear-gradient(180deg,#fffaf6,#fff5ee)',
        fontSize: 12,
        lineHeight: 1.55,
      }}
    >
      <div style={{ fontWeight: 700, marginBottom: 6, color: '#5a4638' }}>
        两种形象模式（请勿混淆）
      </div>
      <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 11 }}>
        <thead>
          <tr style={{ textAlign: 'left', color: '#8a7364' }}>
            <th style={{ padding: '4px 8px 4px 0' }}>模式</th>
            <th style={{ padding: '4px 8px 4px 0' }}>身体</th>
            <th style={{ padding: '4px 0' }}>换装</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td style={{ padding: '6px 8px 6px 0', verticalAlign: 'top' }}>
              <strong style={{ color: '#c45' }}>本页 · 格线 sheet（过渡）</strong>
            </td>
            <td style={{ padding: '6px 8px 6px 0', verticalAlign: 'top' }}>
              64px 四方向格 · LPC 原型素体
            </td>
            <td style={{ padding: '6px 0', verticalAlign: 'top' }}>
              每槽 walk/idle <strong>整张 sheet 叠层</strong>；单品 PNG 只能画<strong>该部位区域</strong>，其余必须透明
            </td>
          </tr>
          <tr>
            <td style={{ padding: '6px 8px 6px 0', verticalAlign: 'top' }}>
              <strong style={{ color: '#3a8a5a' }}>App 官方 · 锚点模型（目标）</strong>
            </td>
            <td style={{ padding: '6px 8px 6px 0', verticalAlign: 'top' }}>
              头 / 躯干 / 腿 / 臂 分片 · <code>avatar_stack.json</code>
            </td>
            <td style={{ padding: '6px 0', verticalAlign: 'top' }}>
              帽/衣/裤/鞋各有 <strong>ox/oy/scale 锚点</strong>，贴在对应身体部位，不会整图替换
            </td>
          </tr>
        </tbody>
      </table>
      <p style={{ margin: '10px 0 0', fontSize: 11, color: '#8a7364' }}>
        App 换衣间：<code>petMoeAvatar=true</code> 走格线 sheet；<code>false</code> 走官方锚点模型（
        <code>assets/pet/character/</code>）。正式美术应产出锚点分片或 Spine，本页 sheet 仅为 walk/idle 动画过渡。
      </p>
      {dupeCount > 0 ? (
        <p style={{ margin: '8px 0 0', color: 'crimson', fontSize: 11 }}>
          ⚠ manifest 有 {dupeCount} 个路径被多个单品共用 → 上传会同时改掉所有引用。请为每个 id 使用独立文件（如{' '}
          <code>top_hoodie_walk.png</code>）。
        </p>
      ) : null}
    </div>
  )
}
