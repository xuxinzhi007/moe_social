package gameapp

import (
	"context"

	gamev1 "backend/api/game/v1"
	gamebiz "backend/internal/biz/game"
	"backend/pkg/llminference"
)

func (s *AppService) InitGameSession(ctx context.Context, in *gamev1.InitGameSessionRequest) (*gamev1.InitGameSessionReply, error) {
	view, err := gamebiz.InitSession(ctx, s.store, in.GetUserId(), in.GetForceNew())
	if err != nil {
		return nil, err
	}
	return &gamev1.InitGameSessionReply{
		SessionId:           view.SessionID,
		Scene:               toProtoScene(view.Scene),
		Npcs:                toProtoNpcs(view.Npcs),
		Opening:             toProtoNarrative(view.Opening),
		History:             toProtoNarrative(view.History),
		GameTime:            view.GameTime,
		OverallFavorability: view.OverallFavorability,
		PlayerFocus:         view.PlayerFocus,
		LlmOnline:           llminference.Ping(ctx, s.deps.Inference),
		Inventory:           toProtoItems(view.Inventory),
	}, nil
}

func (s *AppService) Act(ctx context.Context, in *gamev1.ActRequest) (*gamev1.ActReply, error) {
	result, err := gamebiz.Act(ctx, s.store, s.turnDeps(), in.GetUserId(), in.GetSessionId(), in.GetAction())
	if err != nil {
		return nil, err
	}
	return &gamev1.ActReply{
		Narrative:           toProtoNarrative(result.Narrative),
		Location:            result.Location,
		GameTime:            result.GameTime,
		OverallFavorability: result.OverallFavorability,
		PlayerFocus:         result.PlayerFocus,
		NarrativeSource:     result.NarrativeSource,
		LlmOnline:           result.LlmOnline,
		SuggestedActions:    result.SuggestedActions,
		Inventory:           toProtoItems(result.Inventory),
		Npcs:                toProtoNpcs(result.Npcs),
	}, nil
}

func (s *AppService) GetGameState(ctx context.Context, in *gamev1.GetGameStateRequest) (*gamev1.GetGameStateReply, error) {
	view, err := gamebiz.GetState(ctx, s.store, in.GetUserId(), in.GetSessionId())
	if err != nil {
		return nil, err
	}
	return &gamev1.GetGameStateReply{
		SessionId:           view.SessionID,
		Scene:               toProtoScene(view.Scene),
		Npcs:                toProtoNpcs(view.Npcs),
		GameTime:            view.GameTime,
		OverallFavorability: view.OverallFavorability,
		FlagsJson:           view.FlagsJSON,
		PlayerFocus:         view.PlayerFocus,
		Inventory:           toProtoItems(view.Inventory),
	}, nil
}

func toProtoScene(v gamebiz.SceneView) *gamev1.GameScene {
	return &gamev1.GameScene{
		Id:          uint64(v.ID),
		Name:        v.Name,
		Description: v.Description,
		Exits:       v.Exits,
	}
}

func toProtoNpcs(npcs []gamebiz.NpcView) []*gamev1.GameNpc {
	out := make([]*gamev1.GameNpc, 0, len(npcs))
	for _, npc := range npcs {
		out = append(out, &gamev1.GameNpc{
			Id:           uint64(npc.ID),
			Name:         npc.Name,
			Persona:      npc.Persona,
			Favorability: npc.Favorability,
		})
	}
	return out
}

func toProtoItems(items []gamebiz.ItemView) []*gamev1.GameItem {
	out := make([]*gamev1.GameItem, 0, len(items))
	for _, item := range items {
		out = append(out, &gamev1.GameItem{
			Id:          uint64(item.ID),
			Name:        item.Name,
			Description: item.Description,
			InInventory: item.InInventory,
		})
	}
	return out
}

func toProtoNarrative(lines []gamebiz.NarrativeLine) []*gamev1.GameNarrativeLine {
	out := make([]*gamev1.GameNarrativeLine, 0, len(lines))
	for _, line := range lines {
		out = append(out, &gamev1.GameNarrativeLine{
			Type:    line.Type,
			Content: line.Content,
			Name:    line.Name,
		})
	}
	return out
}
