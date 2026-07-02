package gamebiz

import (
	"context"
	"fmt"
	"strings"
)

// RunTurn 回合引擎唯一入口：Load → Parse → Execute → Narrate → Commit。
func RunTurn(
	ctx context.Context,
	st Store,
	deps TurnDeps,
	userIDRaw string,
	sessionID uint64,
	action string,
	onChunk ProseStreamHandler,
) (ActResult, error) {
	if st == nil {
		return ActResult{}, fmt.Errorf("game store unavailable")
	}
	action = strings.TrimSpace(action)
	if action == "" {
		return ActResult{}, fmt.Errorf("action required")
	}
	userID, err := parseUserID(userIDRaw)
	if err != nil {
		return ActResult{}, err
	}
	st = st.WithContext(ctx)

	snap, err := loadSnapshot(ctx, st, deps, userID, uint(sessionID))
	if err != nil {
		return ActResult{}, err
	}

	cmd := parseCommand(action, snap)

	state, err := executeCommand(ctx, st, deps, snap, cmd)
	if err != nil {
		return ActResult{}, err
	}

	// 移动 / 拾取后刷新快照中的物品列表
	if state.Moved {
		snap.Scene = state.Scene
		snap.SceneItems, _ = st.ListSceneItems(ctx, snap.Session.ID, state.Scene.ID)
	}
	if cmd.Kind == CmdPickup {
		snap.Inventory, _ = st.ListInventoryItems(ctx, snap.Session.ID)
		snap.SceneItems, _ = st.ListSceneItems(ctx, snap.Session.ID, state.Scene.ID)
	}
	snap.Flags = state.Flags

	output, narrativeSource, err := narrateTurn(ctx, st, deps, snap, cmd, state, onChunk)
	if err != nil {
		return ActResult{}, err
	}

	flags := state.Flags

	var extras []NarrativeLine
	if cmd.Kind == CmdFreeform {
		extras, err = applyWorldMutations(ctx, st, &state.Session, &state.Scene, &state.NPCs, &flags, output)
		if err != nil {
			return ActResult{}, err
		}
	}

	lines := narrativeFromOutput(output, action)
	if prose := lastProseFromLines(lines); prose != "" {
		if prev := lastSessionProse(ctx, st, snap.Session.ID); prev != "" && prose == prev {
			intent := resolvePlayerIntent(ctx, deps, action, state.Scene.Name, flags)
			output.Prose = varyRepeatedProse(output.Prose, intent, flags.TurnCount)
			lines = narrativeFromOutput(output, action)
		}
	}
	if len(extras) > 0 {
		lines = append(lines, extras...)
	}
	if len(state.Highlights) > 0 {
		lines = append(state.Highlights, lines...)
	}

	// 模板类叙事：SSE 一次性推送整段 prose（对话/开放行动在 narrate 内流式）
	if onChunk != nil && isTemplateNarration(cmd.Kind) && strings.TrimSpace(output.Prose) != "" {
		_ = onChunk(output.Prose)
	}

	return persistActResult(
		ctx, st, userID, state.Session, state.Scene, state.NPCs,
		flags, snap.Favor, output, lines, action, narrativeSource, snap.LlmOnline,
	)
}

func isTemplateNarration(kind CommandKind) bool {
	switch kind {
	case CmdInspectInventory, CmdInspectScene, CmdExploreWorld, CmdTravel, CmdPickup:
		return true
	default:
		return false
	}
}
