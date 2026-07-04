package gamebiz

import (
	"context"
	"fmt"
	"strings"

	"backend/internal/platform/moelog"
)

// RunTurn 回合引擎 SSOT：Load → Execute(离线) → Agent/Narrate → 投递事件 → Commit。
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

	turnCtx, cancelTurn := turnContext(ctx)
	defer cancelTurn()
	ctx = turnCtx

	snap, err := loadSnapshot(ctx, st, deps, userID, uint(sessionID))
	if err != nil {
		return ActResult{}, err
	}

	cmd := parseCommand(action, snap)
	execCmd := cmd
	if !snap.LlmOnline || IsNarratorMode(deps) {
		execCmd = parseOfflineCommand(action, snap)
	}

	state, err := executeCommand(ctx, st, deps, snap, execCmd)
	if err != nil {
		return ActResult{}, err
	}

	refreshSnapshotItems(ctx, st, snap, &state, execCmd)

	output, narrativeSource, err := narrateTurn(ctx, st, deps, snap, cmd, state, onChunk)
	if err != nil {
		return ActResult{}, err
	}

	refreshSnapshotItems(ctx, st, snap, &state, execCmd)

	flags := state.Flags

	// 事件唯一投递口：Agent/后台 tick 写入 DB，此处统一读取一次。
	var eventLines []NarrativeLine
	if dbEvents, err := loadUndeliveredEventLines(ctx, st, snap.Session.ID); err != nil {
		moelog.Warnf("game: load undelivered events: %v", err)
	} else {
		eventLines = dbEvents
	}

	lines := assembleTurnLines(eventLines, output, action)

	// 离线开放行动仍走 legacy mutations；在线 narrator/agent 均通过 Execute+工具改世界。
	if !snap.LlmOnline && (cmd.Kind == CmdFreeform || execCmd.Kind == CmdFreeform) {
		extras, err := applyWorldMutations(ctx, st, &state.Session, &state.Scene, &state.NPCs, &flags, output)
		if err != nil {
			return ActResult{}, err
		}
		lines = append(lines, extras...)
		lines = dedupeNarrativeLines(lines)
	}

	if prose := lastProseFromLines(lines); prose != "" {
		if prev := lastSessionProse(ctx, st, snap.Session.ID); prev != "" && prose == prev {
			intent := resolvePlayerIntent(ctx, deps, action, state.Scene.Name, flags)
			output.Prose = varyRepeatedProse(output.Prose, intent, flags.TurnCount)
			lines = assembleTurnLines(eventLines, output, action)
		}
	}

	if onChunk != nil && strings.HasPrefix(narrativeSource, "offline") && strings.TrimSpace(output.Prose) != "" {
		_ = onChunk(output.Prose)
	}

	return persistActResult(
		ctx, st, userID, state.Session, state.Scene, state.NPCs,
		flags, snap.Favor, output, lines, action, narrativeSource, snap.LlmOnline,
	)
}

func refreshSnapshotItems(ctx context.Context, st Store, snap *SessionSnapshot, state *TurnState, execCmd Command) {
	snap.Flags = state.Flags
	if state.Moved {
		snap.Scene = state.Scene
	}
	if !state.Moved && execCmd.Kind != CmdPickup && state.PickedItem.Name == "" {
		return
	}
	if items, err := st.ListSceneItems(ctx, snap.Session.ID, state.Scene.ID); err == nil {
		snap.SceneItems = items
	}
	if inv, err := st.ListInventoryItems(ctx, snap.Session.ID); err == nil {
		snap.Inventory = inv
	}
}
