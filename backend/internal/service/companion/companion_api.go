package companionapp

import (
	"context"
	"errors"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	companionv1 "backend/api/companion/v1"
	companionbiz "backend/internal/biz/companion"
	"backend/pkg/llminference"

	kerrors "github.com/go-kratos/kratos/v2/errors"
)

const (
	maxCompanionMessageRunes = 4000
	maxCompanionListLimit    = 100
	maxCompanionAgentIDRunes = 64
)

func (s *AppService) requireEngine() (*companionbiz.Engine, error) {
	if s == nil || s.engine == nil {
		return nil, kerrors.ServiceUnavailable("COMPANION_UNAVAILABLE", "伙伴服务暂不可用")
	}
	return s.engine, nil
}

func (s *AppService) GetProfile(ctx context.Context, userID uint, in *companionv1.GetProfileRequest) (*companionv1.GetProfileReply, error) {
	engine, err := s.requireEngine()
	if err != nil {
		return nil, err
	}
	profile, err := engine.GetProfile(ctx, userID)
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

func (s *AppService) UpsertProfile(ctx context.Context, userID uint, in *companionv1.UpsertProfileRequest) (*companionv1.UpsertProfileReply, error) {
	engine, err := s.requireEngine()
	if err != nil {
		return nil, err
	}
	p := &companionbiz.Profile{
		Name:                 in.GetName(),
		Emoji:                in.GetEmoji(),
		AvatarURL:            strings.TrimSpace(in.GetAvatarUrl()),
		Persona:              in.GetPersona(),
		PersonalityTraits:    in.GetPersonalityTraits(),
		GreetingStyle:        in.GetGreetingStyle(),
		SystemPromptOverride: in.GetSystemPromptOverride(),
		AgentID:              in.GetAgentId(),
		LifeEntityID:         int(in.GetLifeEntityId()),
	}
	if utf8.RuneCountInString(p.AgentID) > maxCompanionAgentIDRunes {
		return nil, kerrors.BadRequest("AGENT_ID_TOO_LONG", "Agent ID 不能超过 64 个字符")
	}
	saved, err := engine.UpsertProfile(ctx, userID, p)
	if err != nil {
		return nil, err
	}
	return &companionv1.UpsertProfileReply{
		Profile: toProtoProfile(saved),
	}, nil
}

func (s *AppService) GetState(ctx context.Context, userID uint, in *companionv1.GetStateRequest) (*companionv1.GetStateReply, error) {
	engine, err := s.requireEngine()
	if err != nil {
		return nil, err
	}
	state, profile, err := engine.GetState(ctx, userID)
	if err != nil {
		return nil, err
	}
	return &companionv1.GetStateReply{
		State:   toProtoState(state),
		Profile: toProtoProfile(profile),
	}, nil
}

func (s *AppService) ListMemories(ctx context.Context, userID uint, in *companionv1.ListMemoriesRequest) (*companionv1.ListMemoriesReply, error) {
	engine, err := s.requireEngine()
	if err != nil {
		return nil, err
	}
	memories, err := engine.ListMemories(ctx, userID, clampLimit(in.GetLimit()))
	if err != nil {
		return nil, err
	}
	return &companionv1.ListMemoriesReply{
		Memories: toProtoMemories(memories),
	}, nil
}

func (s *AppService) DeleteMemory(ctx context.Context, userID uint, in *companionv1.DeleteMemoryRequest) (*companionv1.DeleteMemoryReply, error) {
	engine, err := s.requireEngine()
	if err != nil {
		return nil, err
	}
	if err := engine.DeleteMemory(ctx, userID, uint(in.GetMemoryId())); err != nil {
		if errors.Is(err, companionbiz.ErrMemoryNotFound) {
			return nil, kerrors.NotFound("COMPANION_MEMORY_NOT_FOUND", "记忆不存在")
		}
		return nil, err
	}
	return &companionv1.DeleteMemoryReply{}, nil
}

func (s *AppService) SetMemoryPinned(ctx context.Context, userID uint, in *companionv1.SetMemoryPinnedRequest) (*companionv1.SetMemoryPinnedReply, error) {
	engine, err := s.requireEngine()
	if err != nil {
		return nil, err
	}
	memory, err := engine.SetMemoryPinned(ctx, userID, uint(in.GetMemoryId()), in.GetPinned())
	if err != nil {
		if errors.Is(err, companionbiz.ErrMemoryNotFound) {
			return nil, kerrors.NotFound("COMPANION_MEMORY_NOT_FOUND", "记忆不存在")
		}
		return nil, err
	}
	return &companionv1.SetMemoryPinnedReply{
		Memory: toProtoMemory(*memory),
	}, nil
}

func (s *AppService) UpdateMemory(ctx context.Context, userID uint, in *companionv1.UpdateMemoryRequest) (*companionv1.UpdateMemoryReply, error) {
	engine, err := s.requireEngine()
	if err != nil {
		return nil, err
	}
	content := strings.TrimSpace(in.GetContent())
	if content == "" {
		return nil, kerrors.BadRequest("COMPANION_MEMORY_EMPTY", "记忆内容不能为空")
	}
	memory, err := engine.UpdateMemoryContent(ctx, userID, uint(in.GetMemoryId()), content)
	if err != nil {
		if errors.Is(err, companionbiz.ErrMemoryNotFound) {
			return nil, kerrors.NotFound("COMPANION_MEMORY_NOT_FOUND", "记忆不存在")
		}
		return nil, err
	}
	return &companionv1.UpdateMemoryReply{
		Memory: toProtoMemory(*memory),
	}, nil
}

func (s *AppService) ConfirmMemory(ctx context.Context, userID uint, in *companionv1.ConfirmMemoryRequest) (*companionv1.ConfirmMemoryReply, error) {
	engine, err := s.requireEngine()
	if err != nil {
		return nil, err
	}
	memory, err := engine.ConfirmMemory(ctx, userID, uint(in.GetMemoryId()))
	if err != nil {
		if errors.Is(err, companionbiz.ErrMemoryNotFound) {
			return nil, kerrors.NotFound("COMPANION_MEMORY_NOT_FOUND", "记忆不存在")
		}
		return nil, err
	}
	return &companionv1.ConfirmMemoryReply{
		Memory: toProtoMemory(*memory),
	}, nil
}

func (s *AppService) ListChatHistory(ctx context.Context, userID uint, in *companionv1.ListChatHistoryRequest) (*companionv1.ListChatHistoryReply, error) {
	engine, err := s.requireEngine()
	if err != nil {
		return nil, err
	}
	history, err := engine.ListChatHistory(ctx, userID, clampLimit(in.GetLimit()))
	if err != nil {
		return nil, err
	}
	return &companionv1.ListChatHistoryReply{
		Messages: toProtoChatLogs(history),
	}, nil
}

func (s *AppService) ListRelationshipEvents(
	ctx context.Context,
	userID uint,
	in *companionv1.ListRelationshipEventsRequest,
) (*companionv1.ListRelationshipEventsReply, error) {
	engine, err := s.requireEngine()
	if err != nil {
		return nil, err
	}
	events, err := engine.ListRelationshipEvents(ctx, userID, clampLimit(in.GetLimit()))
	if err != nil {
		return nil, err
	}
	return &companionv1.ListRelationshipEventsReply{
		Events: toProtoRelationshipEvents(events),
	}, nil
}

// ChatStream streams one authenticated user's companion response.
func (s *AppService) ChatStream(
	ctx context.Context,
	userID uint,
	message string,
	onChunk llminference.StreamHandler,
) (string, error) {
	return s.ChatStreamWithInference(ctx, userID, message, nil, "", onChunk)
}

// ChatStreamWithInference streams one message with an optional user-selected provider.
func (s *AppService) ChatStreamWithInference(
	ctx context.Context,
	userID uint,
	message string,
	override *llminference.Config,
	scene string,
	onChunk llminference.StreamHandler,
) (string, error) {
	engine, err := s.requireEngine()
	if err != nil {
		return "", err
	}
	message = strings.TrimSpace(message)
	if message == "" {
		return "", kerrors.BadRequest("MESSAGE_REQUIRED", "消息不能为空")
	}
	if utf8.RuneCountInString(message) > maxCompanionMessageRunes {
		return "", kerrors.BadRequest("MESSAGE_TOO_LONG", "消息长度不能超过 4000 个字符")
	}
	return engine.ChatStream(ctx, userID, message, onChunk, scene, override)
}

func clampLimit(raw int32) int {
	limit := int(raw)
	if limit <= 0 {
		return 0
	}
	if limit > maxCompanionListLimit {
		return maxCompanionListLimit
	}
	return limit
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
		AvatarUrl:            p.AvatarURL,
		WorldBindStatus:      p.WorldBindStatus,
	}
}

func (s *AppService) GetCommunityIdentity(ctx context.Context, userID uint, in *companionv1.GetCommunityIdentityRequest) (*companionv1.GetCommunityIdentityReply, error) {
	engine, err := s.requireEngine()
	if err != nil {
		return nil, err
	}
	if s.db == nil {
		return nil, kerrors.ServiceUnavailable("COMPANION_IDENTITY_UNAVAILABLE", "伙伴社区身份暂不可用")
	}

	profile, err := engine.GetProfile(ctx, userID)
	if err != nil {
		return nil, err
	}
	botUser, agentID, err := s.ensureCommunityBot(ctx, userID, profile)
	if err != nil {
		return nil, err
	}
	if botUser == nil || agentID == "" {
		return &companionv1.GetCommunityIdentityReply{}, nil
	}

	userName := strings.TrimSpace(botUser.Username)
	if userName == "" {
		userName = strings.TrimSpace(profile.Name)
	}
	if userName == "" {
		userName = "AI伙伴"
	}
	userAvatar := strings.TrimSpace(botUser.Avatar)
	if userAvatar == "" {
		userAvatar = strings.TrimSpace(profile.AvatarURL)
	}

	return &companionv1.GetCommunityIdentityReply{
		Identity: &companionv1.CommunityIdentityMsg{
			UserId:            strconv.FormatUint(uint64(botUser.ID), 10),
			UserName:          userName,
			UserAvatar:        userAvatar,
			AgentId:           agentID,
			AuthorIsBot:       true,
			AuthorBotAgentKey: strings.TrimSpace(botUser.BotAgentKey),
		},
	}, nil
}

// BumpIntimacyByReason 供照料等互动调用（chat 由 ChatStream 内部处理）。
func (s *AppService) BumpIntimacyByReason(ctx context.Context, userID uint, reason string) (*companionbiz.Profile, error) {
	engine, err := s.requireEngine()
	if err != nil {
		return nil, err
	}
	delta := companionbiz.IntimacyDeltaForReason(reason)
	if delta <= 0 {
		return nil, kerrors.BadRequest("INVALID_REASON", "不支持的亲密度原因")
	}
	if err := engine.BumpIntimacy(ctx, userID, delta); err != nil {
		return nil, err
	}
	profile, err := engine.GetProfile(ctx, userID)
	if err != nil {
		return nil, err
	}
	return profile, nil
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
		MoodThought:     s.MoodThought,
		ActivityLabel:   s.ActivityLabel,
		Greeting:        s.Greeting,
		Moments:         moments,
		Mood:            s.Mood,
		Hunger:          s.Hunger,
		Energy:          s.Energy,
		EntityAlive:     s.EntityAlive,
		WorldBindStatus: s.WorldBindStatus,
	}
}

func toProtoMemories(memories []companionbiz.Memory) []*companionv1.CompanionMemoryMsg {
	out := make([]*companionv1.CompanionMemoryMsg, 0, len(memories))
	for _, m := range memories {
		out = append(out, toProtoMemory(m))
	}
	return out
}

func toProtoMemory(m companionbiz.Memory) *companionv1.CompanionMemoryMsg {
	return &companionv1.CompanionMemoryMsg{
		Id:            uint64(m.ID),
		MemoryType:    m.MemoryType,
		Content:       m.Content,
		Importance:    int32(m.Importance),
		CreatedAt:     m.CreatedAt.Format("2006-01-02 15:04:05"),
		Pinned:        m.Pinned,
		UserConfirmed: m.UserConfirmed,
		ConfirmedAt:   formatOptionalTime(m.ConfirmedAt),
		MemoryKey:     m.MemoryKey,
		Confidence:    m.Confidence,
	}
}

func formatOptionalTime(value *time.Time) string {
	if value == nil {
		return ""
	}
	return value.Format("2006-01-02 15:04:05")
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

func toProtoRelationshipEvents(events []companionbiz.RelationshipEvent) []*companionv1.CompanionRelationshipEventMsg {
	out := make([]*companionv1.CompanionRelationshipEventMsg, 0, len(events))
	for _, event := range events {
		out = append(out, &companionv1.CompanionRelationshipEventMsg{
			Id:                uint64(event.ID),
			EventType:         event.EventType,
			Title:             event.Title,
			Content:           event.Content,
			RelationshipLevel: int32(event.RelationshipLevel),
			IntimacyScore:     event.IntimacyScore,
			CreatedAt:         event.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}
	return out
}
