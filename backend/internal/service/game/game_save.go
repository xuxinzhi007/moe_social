package gameapp

import (
	"context"
	"strconv"
	"strings"

	gamev1 "backend/api/game/v1"
	gamebiz "backend/internal/biz/game"
)

func (s *AppService) SaveGame(ctx context.Context, in *gamev1.SaveGameRequest) (*gamev1.SaveGameReply, error) {
	userID, err := parseSvcUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	err = gamebiz.SaveGame(ctx, s.store, userID, uint(in.GetSessionId()), uint8(in.GetSlotIndex()), in.GetLabel())
	if err != nil {
		return nil, err
	}
	return &gamev1.SaveGameReply{
		Success: true,
		Slot: &gamev1.SaveSlotInfo{
			SlotIndex: in.GetSlotIndex(),
			Label:     in.GetLabel(),
		},
	}, nil
}

func (s *AppService) LoadGame(ctx context.Context, in *gamev1.LoadGameRequest) (*gamev1.LoadGameReply, error) {
	userID, err := parseSvcUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	snap, err := gamebiz.LoadGame(ctx, s.store, userID, uint8(in.GetSlotIndex()))
	if err != nil {
		return nil, err
	}
	return &gamev1.LoadGameReply{
		SessionId: uint64(snap.Session.ID),
		SceneName: snap.Scene.Name,
		TurnCount: int32(snap.Flags.TurnCount),
	}, nil
}

func (s *AppService) ListSaveSlots(ctx context.Context, in *gamev1.ListSaveSlotsRequest) (*gamev1.ListSaveSlotsReply, error) {
	userID, err := parseSvcUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	slots, err := gamebiz.ListSaveSlots(ctx, s.store, userID)
	if err != nil {
		return nil, err
	}
	out := make([]*gamev1.SaveSlotInfo, 0, len(slots))
	for _, slot := range slots {
		out = append(out, &gamev1.SaveSlotInfo{
			SlotIndex: uint32(slot.SlotIndex),
			Label:     slot.Label,
			TurnCount: int32(slot.TurnCount),
			SceneName: slot.SceneName,
			UpdatedAt: slot.UpdatedAt.Format("2006-01-02 15:04:05"),
		})
	}
	return &gamev1.ListSaveSlotsReply{Slots: out}, nil
}

func (s *AppService) DeleteSaveSlot(ctx context.Context, in *gamev1.DeleteSaveSlotRequest) (*gamev1.DeleteSaveSlotReply, error) {
	userID, err := parseSvcUserID(in.GetUserId())
	if err != nil {
		return nil, err
	}
	err = gamebiz.DeleteSaveSlot(ctx, s.store, userID, uint8(in.GetSlotIndex()))
	if err != nil {
		return nil, err
	}
	return &gamev1.DeleteSaveSlotReply{Success: true}, nil
}

func parseSvcUserID(raw string) (uint, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return 0, gamebizErr("user_id required")
	}
	n, err := strconv.ParseUint(raw, 10, 64)
	if err != nil || n == 0 {
		return 0, gamebizErr("invalid user_id")
	}
	return uint(n), nil
}
