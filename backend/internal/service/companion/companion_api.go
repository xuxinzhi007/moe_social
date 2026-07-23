package companionapp

import (
	"context"
	"errors"
	"strconv"
	"strings"
	"unicode/utf8"

	companionv1 "backend/api/companion/v1"
	companionbiz "backend/internal/biz/companion"
	"backend/model"
	"backend/pkg/llminference"

	kerrors "github.com/go-kratos/kratos/v2/errors"
)

const (
	maxCompanionMessageRunes = 4000
	maxCompanionListLimit    = 100
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
		Persona:              in.GetPersona(),
		PersonalityTraits:    in.GetPersonalityTraits(),
		GreetingStyle:        in.GetGreetingStyle(),
		SystemPromptOverride: in.GetSystemPromptOverride(),
		AgentID:              in.GetAgentId(),
		LifeEntityID:         int(in.GetLifeEntityId()),
	}
	saved, err := engine.UpsertProfile(ctx, userID, p)
	if err != nil {
		if errors.Is(err, companionbiz.ErrLifeEntityNotFound) {
			return nil, kerrors.BadRequest("LIFE_ENTITY_NOT_FOUND", "选择的伙伴不存在或已离开")
		}
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

// ChatStream streams one authenticated user's companion response.
func (s *AppService) ChatStream(
	ctx context.Context,
	userID uint,
	message string,
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
	return engine.ChatStream(ctx, userID, message, onChunk)
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
	agentID := strings.TrimSpace(profile.AgentID)
	if agentID == "" {
		return nil, kerrors.NotFound("COMPANION_IDENTITY_NOT_FOUND", "伙伴社区身份不存在")
	}

	var botUser model.User
	if err := s.db.WithContext(ctx).
		Where("is_bot = ? AND bot_agent_key = ?", true, agentID).
		First(&botUser).Error; err != nil {
		return nil, kerrors.NotFound("COMPANION_IDENTITY_NOT_FOUND", "伙伴社区身份不存在")
	}

	userName := strings.TrimSpace(botUser.Username)
	if userName == "" {
		userName = strings.TrimSpace(botUser.Email)
	}
	if userName == "" {
		userName = profile.Name
	}
	userAvatar := strings.TrimSpace(botUser.Avatar)
	if userAvatar == "" {
		userAvatar = "https://picsum.photos/150"
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
