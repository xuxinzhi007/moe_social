# Pet 装扮 A 方案：身体拆层 + 模型锚点穿搭

> **日期**：2026-08-01  
> **状态**：主路径已实现（正式方案）  
> **关系**：优先于 Spine（C）

## 1. 产品约定

换衣间是 **按角色模型穿搭**，不是随意贴纸：

1. 身体按深度表拆层绘制（QQ 秀式遮挡）。
2. 服装槽选中单品后，落到 `wearAnchors` **模型锚点**（相对躯干中心的 ox/oy/scale/rot）。
3. 每槽支持 **「无」**：空 ID，不画该槽（裸模型）。
4. **微调**（可选）：开启后可拖移 / 四角缩放 / 顶柄旋转；「复位锚点」回到配置默认值。
5. 小家舞台与换衣间共用 `PetAvatarStack.compose` + 同一套 layout。

## 2. 深度表与锚点配置

编辑后 **热重启** 生效：

`assets/pet/config/avatar_stack.json`

| 字段 | 含义 |
|------|------|
| `order` | 后 → 前绘制顺序 |
| `body.*` | 身体各片路径 |
| `wearAnchors` | 帽/衣/裤/鞋相对模型的默认摆放 |

默认绘制链：

```text
shoes → bottom → legs → torso → top_back → arms → top_front → head → hat
```

（`ear` 仅在资源与模型匹配时再写入 `order`。）

## 3. 「无」与资源回落

- 空 ID：`compose` **跳过**该服装槽；`PetArt.resolveClothesPath` 返回 `null`，**不**回落 `*_basic`。
- 非空但缺专用图：仍可回落同槽基础款，避免坏图。

## 4. 分层 vs 合体

| 模式 | 条件 | 效果 |
|------|------|------|
| **分层（模型穿搭）** | 存在 `head` 和/或无脸 `torso` | 衣夹在躯干与头之间 |
| **合体** | 只有整身 `model` | 衣画在整身之上（会盖脸） |

换衣间预览底栏可点开查看 ✓/✗ 层清单。

## 5. 资源放置

| 文件 | 作用 |
|------|------|
| `character/torso.png` | **无脸**躯干 |
| `character/head.png` | 头+脸（夹在衣服之上） |
| `character/legs.png` / `arms.png` | 可选更细拆分 |
| `clothes/{top_id}_back.png` / `_front.png` | 可选外套前后片 |

## 6. 代码入口

| 模块 | 路径 |
|------|------|
| 配置 + 组装 | `lib/game/pet/pet_avatar_stack.dart` |
| 布局模型 | `lib/models/pet_wear.dart` |
| 换衣间 UI | `lib/pages/pet/pet_dressing_page.dart` |
| 小家绘制 | `lib/game/pet/pet_room_game.dart`（`_PetActor`） |

## 7. 美术注意

- 全身统一画布、透明底  
- `torso` 不要画脸；脸只在 `head`  
- 单片上衣只有 `top_xxx.png` 时画在 `top_front`（夹在 torso 与 head 之间）  
- 锚点以 torso/head 对齐为准，在换衣间点「复位锚点」校对后写回 JSON
