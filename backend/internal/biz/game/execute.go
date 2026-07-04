package gamebiz

import (
	"context"
	"fmt"

	"backend/model"
)

// TurnState Execute 阶段产出：本回合所有状态变更（DB 写入在 travel 等路径已完成）。
type TurnState struct {
	Session       model.GameSession
	Scene         model.GameScene
	NPCs          []model.GameNpc
	Flags         WorldFlags
	Moved         bool
	Highlights    []NarrativeLine
	PickedItem    model.GameWorldItem
	PickupCreated bool
}

// executeCommand ③ Execute：结构化指令在此改 session/scene/flags（travel 含 CreateScene）。
func executeCommand(
	ctx context.Context,
	st Store,
	deps TurnDeps,
	snap *SessionSnapshot,
	cmd Command,
) (TurnState, error) {
	state := TurnState{
		Session: snap.Session,
		Scene:   snap.Scene,
		NPCs:    append([]model.GameNpc(nil), snap.NPCs...),
		Flags:   snap.Flags,
	}

	switch cmd.Kind {
	case CmdTravel:
		newScene, newNpcs, moved, err := tryExploreNewArea(
			ctx, st, deps, &state.Session, state.Scene, cmd.Raw, &state.Flags,
		)
		if err != nil {
			return state, err
		}
		if moved {
			state.Scene = newScene
			state.NPCs = newNpcs
			state.Session.SceneID = newScene.ID
			state.Moved = true
			state.Flags.InDialogue = false
			state.Flags.LastTalkNPC = ""
			state.Highlights = []NarrativeLine{{
				Type:    "highlight",
				Content: fmt.Sprintf("📍 你来到了【%s】", newScene.Name),
			}}
		}

	case CmdTalkStart:
		target := cmd.Target
		state.Flags.InDialogue = true
		state.Flags.LastTalkNPC = target
		state.Flags.PlayerFocus = target
		if state.Flags.NpcActivity == nil {
			state.Flags.NpcActivity = map[string]string{}
		}
		state.Flags.NpcActivity[target] = "正在与你交谈"

	case CmdTalkReply:
		npcName := cmd.Target
		if npcName == "" {
			npcName = pickTalkTarget(snap.npcViews(), state.Scene.Name)
		}
		state.Flags.InDialogue = true
		state.Flags.LastTalkNPC = npcName
		state.Flags.PlayerFocus = npcName

	case CmdInspectInventory:
		state.Flags.PlayerFocus = "背包"
		state.Flags.PlayerPosture = "检视物品"

	case CmdInspectScene:
		state.Flags.PlayerFocus = state.Scene.Name + "环境"
		state.Flags.PlayerPosture = "驻足观察"

	case CmdExploreWorld:
		state.Flags.PlayerPosture = "准备出发"
		state.Flags.PlayerFocus = "未知道路"

	case CmdPickup:
		item, created, err := executePickup(ctx, st, snap, &state, cmd.Target)
		if err != nil {
			return state, err
		}
		state.PickedItem = item
		state.PickupCreated = created

	case CmdFreeform:
		// 开放行动：Execute 不改世界，变更由 Commit 阶段 applyWorldMutations 处理

	case CmdAgent:
		// 在线 Agent 通过 world_* 工具改 DB；Execute 阶段不改状态
	}

	return state, nil
}
