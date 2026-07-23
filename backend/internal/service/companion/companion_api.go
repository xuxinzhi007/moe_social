package companionapp

import (
	"context"
	"fmt"

	companionv1 "backend/api/companion/v1"
	companionbiz "backend/internal/biz/companion"
)

func (s *AppService) requireEngine() (*companionbiz.Engine, error) {
	if s == nil || s.engine == nil {
		return nil, fmt.Errorf("companion service unavailable")
	}
	return s.engine, nil
}

func (s *AppService) GetProfile(ctx context.Context, in *companionv1.GetProfileRequest) (*companionv1.GetProfileReply, error) {
	engine, err := s.requireEngine()
	if err != nil {
		return nil, err
	}
	profile, err := engine.GetProfile(ctx, 1) // TODO: 从 JWT 提取 userID
	if err != nil {
		return nil, err
	}
	if profile == nil {
		return &companionv1.GetProfileReply{}, nil
	}
	return &companionv1.GetProfileReply{
		Profile: toProtoProfile(profile),
	}, nil
}

func (s *AppService) UpsertProfile(ctx context.Context, in *companionv1.UpsertProfileRequest) (*companionv1.UpsertProfileReply, error) {
	engine, err := s.requireEngine()
	if err != nil {
		return nil, err
	}
	p := &companionbiz.Profile{
		Name:                 in.GetName(),
		Emoji:                in.GetEmoji(),
		Persona:              in.GetPersona(),
		PersonalityTraits:    in.GetPersonalityTraits(),
		GreetingStyle:        in.GetGreetingStyle(),
		SystemPromptOverride: in.GetSystemPromptOverride(),
		AgentID:              in.GetAgentId(),
		LifeEntityID:         int(in.GetLifeEntityId()),
	}
	saved, err := engine.UpsertProfile(ctx, 1, p) // TODO: 从 JWT 提取 userID
	if err != nil {
		return nil, err
	}
	return &companionv1.UpsertProfileReply{
		Profile: toProtoProfile(saved),
	}, nil
}

func (s *AppService) GetState(ctx context.Context, in *companionv1.GetStateRequest) (*companionv1.GetStateReply, error) {
	engine, err := s.requireEngine()
	if err != nil {
		return nil, err
	}
	state, profile, err := engine.GetState(ctx, 1) // TODO: 从 JWT 提取 userID
	if err != nil {
		return nil, err
	}
	return &companionv1.GetStateReply{
		State:   toProtoState(state),
		Profile: toProtoProfile(profile),
	}, nil
}

func (s *AppService) ListMemories(ctx context.Context, in *companionv1.ListMemoriesRequest) (*companionv1.ListMemoriesReply, error) {
	engine, err := s.requireEngine()
	if err != nil {
		return nil, err
	}
	memories, err := engine.ListMemories(ctx, 1, int(in.GetLimit())) // TODO: 从 JWT 提取 userID
	if err != nil {
		return nil, err
	}
	return &companionv1.ListMemoriesReply{
		Memories: toProtoMemories(memories),
	}, nil
}

func (s *AppService) ListChatHistory(ctx context.Context, in *companionv1.ListChatHistoryRequest) (*companionv1.ListChatHistoryReply, error) {
	engine, err := s.requireEngine()
	if err != nil {
		return nil, err
	}
	history, err := engine.ListChatHistory(ctx, 1, int(in.GetLimit())) // TODO: 从 JWT 提取 userID
	if err != nil {
		return nil, err
	}
	return &companionv1.ListChatHistoryReply{
		Messages: toProtoChatLogs(history),
	}, nil
}

// ── Proto 转换函数 ──

func toProtoProfile(p *companionbiz.Profile) *companionv1.CompanionProfileMsg {
	if p == nil {
		return nil
	}
	return &companionv1.CompanionProfileMsg{
		Name:                 p.Name,
		Emoji:                p.Emoji,
		Persona:              p.Persona,
		PersonalityTraits:    p.PersonalityTraits,
		GreetingStyle:        p.GreetingStyle,
		RelationshipLevel:    int32(p.RelationshipLevel),
		IntimacyScore:        p.IntimacyScore,
		SystemPromptOverride: p.SystemPromptOverride,
		AgentId:              p.AgentID,
		LifeEntityId:         int32(p.LifeEntityID),
	}
}

func toProtoState(s *companionbiz.State) *companionv1.CompanionStateMsg {
	if s == nil {
		return nil
	}
	moments := make([]*companionv1.CompanionMomentMsg, 0, len(s.Moments))
	for _, m := range s.Moments {
		moments = append(moments, &companionv1.CompanionMomentMsg{
			Text:      m.Text,
			Icon:      m.Icon,
			TimeLabel: m.TimeLabel,
		})
	}
	return &companionv1.CompanionStateMsg{
		MoodThought:   s.MoodThought,
		ActivityLabel: s.ActivityLabel,
		Greeting:      s.Greeting,
		Moments:       moments,
		Mood:          s.Mood,
		Hunger:        s.Hunger,
		Energy:        s.Energy,
	}
}

func toProtoMemories(memories []companionbiz.Memory) []*companionv1.CompanionMemoryMsg {
	out := make([]*companionv1.CompanionMemoryMsg, 0, len(memories))
	for _, m := range memories {
		out = append(out, &companionv1.CompanionMemoryMsg{
			Id:         uint64(m.ID),
			MemoryType: m.MemoryType,
			Content:    m.Content,
			Importance: int32(m.Importance),
			CreatedAt:  m.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}
	return out
}

func toProtoChatLogs(logs []companionbiz.ChatLog) []*companionv1.CompanionChatLogMsg {
	out := make([]*companionv1.CompanionChatLogMsg, 0, len(logs))
	for _, l := range logs {
		out = append(out, &companionv1.CompanionChatLogMsg{
			Id:        uint64(l.ID),
			Role:      l.Role,
			Content:   l.Content,
			CreatedAt: l.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}
	return out
}
