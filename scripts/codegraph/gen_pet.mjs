import fs from 'node:fs'
import path from 'node:path'
import { GraphBuilder, REPO_ROOT, exists, writeJson } from './lib.mjs'

const PACK_ROOTS = [
  {
    id: 'admin-public',
    label: 'Admin 预览包',
    root: 'moe-admin/public/pet/moe_content',
    role: 'admin_preview',
  },
  {
    id: 'flutter-assets',
    label: 'Flutter 运行时包',
    root: 'assets/pet/moe_content',
    role: 'flutter_runtime',
  },
]

function collectAssetPaths(obj, acc = []) {
  if (typeof obj === 'string') {
    if (/\.(png|webp|jpg|json)$/i.test(obj) || obj.includes('/')) acc.push(obj)
    return acc
  }
  if (Array.isArray(obj)) {
    for (const v of obj) collectAssetPaths(v, acc)
    return acc
  }
  if (obj && typeof obj === 'object') {
    for (const v of Object.values(obj)) collectAssetPaths(v, acc)
  }
  return acc
}

function addManifestGraph(g, pack) {
  const packNodeId = `pack:${pack.id}`
  const absRoot = path.join(REPO_ROOT, pack.root)
  const rootManifest = path.join(absRoot, 'manifest.json')
  const avatarManifest = path.join(absRoot, 'avatar', 'manifest.json')
  const furnitureManifest = path.join(absRoot, 'furniture', 'manifest.json')

  g.addNode({
    id: packNodeId,
    kind: 'pack',
    label: pack.label,
    summary: pack.root,
    ref_id: pack.root,
    meta: { role: pack.role },
    weight: 3,
  })

  const consumers = [
    {
      id: 'consumer:pet-hub',
      label: 'PetContentHubPage',
      ref: 'moe-admin/src/pages/PetContentHubPage.tsx',
    },
    {
      id: 'consumer:avatar-editor',
      label: 'PetAvatarEditorPage',
      ref: 'moe-admin/src/pages/PetAvatarEditorPage.tsx',
    },
    {
      id: 'consumer:furniture-editor',
      label: 'PetFurnitureEditorPage',
      ref: 'moe-admin/src/pages/PetFurnitureEditorPage.tsx',
    },
    {
      id: 'consumer:flutter-composer',
      label: 'PetMoeAvatarComposer',
      ref: 'lib/game/pet/pet_moe_avatar_composer.dart',
    },
  ]
  for (const c of consumers) {
    g.addNode({
      id: c.id,
      kind: 'consumer',
      label: c.label,
      summary: c.ref,
      ref_id: c.ref,
      weight: 2,
    })
  }
  if (pack.role === 'admin_preview') {
    g.addEdge('consumer:pet-hub', packNodeId, 'edits')
    g.addEdge('consumer:avatar-editor', packNodeId, 'edits')
    g.addEdge('consumer:furniture-editor', packNodeId, 'edits')
  } else {
    g.addEdge('consumer:flutter-composer', packNodeId, 'loads')
  }

  /** @type {any} */
  let unified = null
  if (fs.existsSync(rootManifest)) {
    unified = JSON.parse(fs.readFileSync(rootManifest, 'utf8'))
    g.addNode({
      id: `${packNodeId}:manifest`,
      kind: 'manifest',
      label: 'manifest.json',
      summary: unified.displayName || unified.packId || 'unified',
      ref_id: `${pack.root}/manifest.json`,
      weight: 2,
    })
    g.addEdge(packNodeId, `${packNodeId}:manifest`, 'contains')
  }

  const avatarSrc = fs.existsSync(avatarManifest)
    ? JSON.parse(fs.readFileSync(avatarManifest, 'utf8'))
    : unified?.avatar
  if (avatarSrc) {
    const avatarId = `${packNodeId}:avatar`
    g.addNode({
      id: avatarId,
      kind: 'section',
      label: 'avatar',
      summary: avatarSrc.displayName || avatarSrc.packId || 'avatar section',
      ref_id: fs.existsSync(avatarManifest)
        ? `${pack.root}/avatar/manifest.json`
        : `${pack.root}/manifest.json#avatar`,
      weight: 2,
    })
    g.addEdge(packNodeId, avatarId, 'contains')

    const order = avatarSrc.composeOrder || []
    for (const slot of order) {
      const slotId = `${avatarId}:slot:${slot}`
      g.addNode({
        id: slotId,
        kind: 'slot',
        label: slot,
        summary: 'composeOrder',
        ref_id: `${pack.root}/avatar#${slot}`,
      })
      g.addEdge(avatarId, slotId, 'layer')
    }

    const base = avatarSrc.base || {}
    for (const [layer, anims] of Object.entries(base)) {
      const layerId = `${avatarId}:base:${layer}`
      g.addNode({
        id: layerId,
        kind: 'layer',
        label: `base/${layer}`,
        summary: 'base layer',
        ref_id: `${pack.root}/avatar/layers/base`,
      })
      g.addEdge(avatarId, layerId, 'contains')
      const slotId = `${avatarId}:slot:${layer}`
      if (g.nodes.has(slotId)) g.addEdge(slotId, layerId, 'binds')
      for (const rel of collectAssetPaths(anims)) {
        const assetId = `${packNodeId}:asset:${rel}`
        const abs = path.join(absRoot, 'avatar', rel)
        const ok = fs.existsSync(abs)
        g.addNode({
          id: assetId,
          kind: ok ? 'asset' : 'missing_asset',
          label: path.posix.basename(rel),
          summary: ok ? rel : `MISSING ${rel}`,
          ref_id: `${pack.root}/avatar/${rel}`,
          weight: ok ? 1 : 2,
          meta: { exists: ok },
        })
        g.addEdge(layerId, assetId, 'asset')
      }
    }

    const slots = avatarSrc.slots || {}
    for (const [slotName, items] of Object.entries(slots)) {
      const slotId = `${avatarId}:slot:${slotName}`
      if (!g.nodes.has(slotId)) {
        g.addNode({
          id: slotId,
          kind: 'slot',
          label: slotName,
          summary: 'slots',
          ref_id: `${pack.root}/avatar#slots.${slotName}`,
        })
        g.addEdge(avatarId, slotId, 'layer')
      }
      for (const [itemId, anims] of Object.entries(items || {})) {
        const itemNode = `${avatarId}:item:${itemId}`
        g.addNode({
          id: itemNode,
          kind: 'item',
          label: itemId,
          summary: `slot=${slotName}`,
          ref_id: `${pack.root}/avatar#slots.${slotName}.${itemId}`,
        })
        g.addEdge(slotId, itemNode, 'contains')
        for (const rel of collectAssetPaths(anims)) {
          const assetId = `${packNodeId}:asset:${rel}`
          const abs = path.join(absRoot, 'avatar', rel)
          const ok = fs.existsSync(abs)
          g.addNode({
            id: assetId,
            kind: ok ? 'asset' : 'missing_asset',
            label: path.posix.basename(rel),
            summary: ok ? rel : `MISSING ${rel}`,
            ref_id: `${pack.root}/avatar/${rel}`,
            meta: { exists: ok },
          })
          g.addEdge(itemNode, assetId, 'asset')
        }
      }
    }
  }

  /** @type {any} */
  let furniture = null
  if (fs.existsSync(furnitureManifest)) {
    furniture = JSON.parse(fs.readFileSync(furnitureManifest, 'utf8'))
  } else if (unified?.objects) {
    furniture = { objects: unified.objects }
  }

  const objects = furniture?.objects || furniture?.items || unified?.objects
  if (objects && typeof objects === 'object') {
    const objectsId = `${packNodeId}:objects`
    g.addNode({
      id: objectsId,
      kind: 'section',
      label: 'objects',
      summary: `${Object.keys(objects).length} items`,
      ref_id: fs.existsSync(furnitureManifest)
        ? `${pack.root}/furniture/manifest.json`
        : `${pack.root}/manifest.json#objects`,
      weight: 2,
    })
    g.addEdge(packNodeId, objectsId, 'contains')

    for (const [oid, spec] of Object.entries(objects)) {
      const objId = `${objectsId}:${oid}`
      g.addNode({
        id: objId,
        kind: 'object',
        label: oid,
        summary: spec?.displayName || spec?.category || 'furniture',
        ref_id: `${pack.root}/objects/${oid}`,
      })
      g.addEdge(objectsId, objId, 'contains')
      for (const rel of collectAssetPaths(spec)) {
        const candidates = [
          path.join(absRoot, rel),
          path.join(absRoot, 'furniture', rel),
          path.join(absRoot, 'objects', rel),
        ]
        const hit = candidates.find((c) => fs.existsSync(c))
        const assetId = `${packNodeId}:objasset:${rel}`
        g.addNode({
          id: assetId,
          kind: hit ? 'asset' : 'missing_asset',
          label: path.posix.basename(rel),
          summary: hit ? path.relative(REPO_ROOT, hit).replace(/\\/g, '/') : `MISSING ${rel}`,
          ref_id: hit
            ? path.relative(REPO_ROOT, hit).replace(/\\/g, '/')
            : `${pack.root}/${rel}`,
          meta: { exists: Boolean(hit) },
        })
        g.addEdge(objId, assetId, 'asset')
      }
    }
  }

  if (!exists(pack.root)) {
    g.addNode({
      id: `${packNodeId}:missing-root`,
      kind: 'missing_asset',
      label: 'pack root missing',
      summary: pack.root,
      ref_id: pack.root,
      weight: 3,
    })
    g.addEdge(packNodeId, `${packNodeId}:missing-root`, 'missing')
  }
}

export function generatePet() {
  const g = new GraphBuilder('pet')
  g.addNode({
    id: 'root:pet',
    kind: 'root',
    label: 'Pet Content Pack',
    summary: 'admin → manifest → assets → Flutter runtime',
    ref_id: 'docs/dev/moe-pet-content-pack.md',
    weight: 4,
  })
  for (const pack of PACK_ROOTS) {
    addManifestGraph(g, pack)
    g.addEdge('root:pet', `pack:${pack.id}`, 'contains')
  }
  const missing = [...g.nodes.values()].filter((n) => n.kind === 'missing_asset').length
  const doc = g.build({
    packCount: PACK_ROOTS.length,
    missingAssets: missing,
  })
  return writeJson('pet.json', doc)
}
