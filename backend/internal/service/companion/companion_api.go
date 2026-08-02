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
	"backend/model"
	"backend/pkg/llminference"

	kerrors "github.com/go-kratos/kratos/v2/errors"
	"gorm.io/gorm"
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

func (s *AppService) GetProactiveSettings(ctx context.Context, userID uint, in *companionv1.GetProactiveSettingsRequest) (*companionv1.GetProactiveSettingsReply, error) {
	engine, err := s.requireEngine()
	if err != nil {
		return nil, err
	}
	settings, err := engine.GetProactiveSettings(ctx, userID)
	if err != nil {
		return nil, err
	}
	return &companionv1.GetProactiveSettingsReply{Settings: toProtoProactiveSettings(settings)}, nil
}

func (s *AppService) UpdateProactiveSettings(ctx context.Context, userID uint, in *companionv1.UpdateProactiveSettingsRequest) (*companionv1.UpdateProactiveSettingsReply, error) {
	engine, err := s.requireEngine()
	if err != nil {
		return nil, err
	}
	settings, err := engine.UpdateProactiveSettings(ctx, userID, companionbiz.ProactiveSettings{
		Enabled:        in.GetEnabled(),
		DailyLimit:     int(in.GetDailyLimit()),
		QuietStart:     int(in.GetQuietStart()),
		QuietEnd:       int(in.GetQuietEnd()),
		TimezoneOffset: int(in.GetTimezoneOffset()),
	})
	if err != nil {
		return nil, err
	}
	return &companionv1.UpdateProactiveSettingsReply{Settings: toProtoProactiveSettings(settings)}, nil
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

func (s *AppService) ListMemoryConflicts(
	ctx context.Context,
	userID uint,
	in *companionv1.ListMemoryConflictsRequest,
) (*companionv1.ListMemoryConflictsReply, error) {
	engine, err := s.requireEngine()
	if err != nil {
		return nil, err
	}
	conflicts, err := engine.ListMemoryConflicts(ctx, userID, clampLimit(in.GetLimit()))
	if err != nil {
		return nil, err
	}
	return &companionv1.ListMemoryConflictsReply{
		Conflicts: toProtoMemoryConflicts(conflicts),
	}, nil
}

func (s *AppService) ResolveMemoryConflict(
	ctx context.Context,
	userID uint,
	in *companionv1.ResolveMemoryConflictRequest,
) (*companionv1.ResolveMemoryConflictReply, error) {
	engine, err := s.requireEngine()
	if err != nil {
		return nil, err
	}
	if err := engine.ResolveMemoryConflict(ctx, userID, uint(in.GetConflictId()), in.GetResolution()); err != nil {
		switch {
		case errors.Is(err, companionbiz.ErrMemoryConflictNotFound),
			errors.Is(err, companionbiz.ErrMemoryNotFound):
			return nil, kerrors.NotFound("COMPANION_MEMORY_CONFLICT_NOT_FOUND", "记忆冲突不存在")
		case errors.Is(err, companionbiz.ErrMemoryConflictResolved):
			return nil, kerrors.Conflict("COMPANION_MEMORY_CONFLICT_RESOLVED", "记忆冲突已处理")
		default:
			return nil, err
		}
	}
	return &companionv1.ResolveMemoryConflictReply{}, nil
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

func (s *AppService) ListEvents(
	ctx context.Context,
	userID uint,
	in *companionv1.ListEventsRequest,
) (*companionv1.ListEventsReply, error) {
	engine, err := s.requireEngine()
	if err != nil {
		return nil, err
	}
	events, err := engine.ListEvents(ctx, userID, clampLimit(in.GetLimit()))
	if err != nil {
		return nil, err
	}
	return &companionv1.ListEventsReply{Events: toProtoEvents(events)}, nil
}

func (s *AppService) GetTimeline(
	ctx context.Context,
	userID uint,
	in *companionv1.ListEventsRequest,
) (*companionv1.ListEventsReply, error) {
	return s.ListEvents(ctx, userID, in)
}

// GetContextPreview returns safe metadata for the canonical companion context.
func (s *AppService) GetContextPreview(
	ctx context.Context,
	userID uint,
	in *companionv1.ContextPreviewRequest,
) (*companionv1.ContextPreviewReply, error) {
	engine, err := s.requireEngine()
	if err != nil {
		return nil, err
	}
	scene := strings.TrimSpace(in.GetScene())
	snapshot, err := engine.BuildContext(ctx, userID, scene)
	if err != nil {
		return nil, err
	}
	reply := &companionv1.ContextPreviewReply{
		Scene:                  snapshot.Scene,
		HistoryCount:           int32(len(snapshot.History)),
		MemoryCount:            int32(len(snapshot.Memories)),
		RelationshipEventCount: int32(len(snapshot.RelationshipEvents)),
		UnfinishedTopicCount:   int32(len(snapshot.UnfinishedTopics)),
		FirstChat:              snapshot.IsFirstChat,
	}
	if snapshot.Profile != nil {
		reply.RelationshipLevel = int32(snapshot.Profile.RelationshipLevel)
		reply.IntimacyScore = snapshot.Profile.IntimacyScore
		reply.WorldBindStatus = snapshot.Profile.WorldBindStatus
	}
	return reply, nil
}

// ListProactiveDeliveries returns rebuildable proactive delivery states.
func (s *AppService) ListProactiveDeliveries(
	ctx context.Context,
	userID uint,
	in *companionv1.ListProactiveDeliveriesRequest,
) (*companionv1.ListProactiveDeliveriesReply, error) {
	engine, err := s.requireEngine()
	if err != nil {
		return nil, err
	}
	deliveries, err := engine.ListProactiveDeliveries(ctx, userID, clampLimit(in.GetLimit()))
	if err != nil {
		return nil, err
	}
	out := make([]*companionv1.CompanionProactiveDeliveryMsg, 0, len(deliveries))
	for _, delivery := range deliveries {
		item := &companionv1.CompanionProactiveDeliveryMsg{
			DeliveryKey:    delivery.DeliveryKey,
			NotificationId: uint64(delivery.NotificationID),
			Status:         delivery.Status,
			Reason:         delivery.Reason,
			Priority:       int32(delivery.Priority),
			ScheduledAt:    delivery.ScheduledAt.Format(time.RFC3339),
		}
		if delivery.DeliveredAt != nil {
			item.DeliveredAt = delivery.DeliveredAt.Format(time.RFC3339)
		}
		if delivery.ReadAt != nil {
			item.ReadAt = delivery.ReadAt.Format(time.RFC3339)
		}
		if delivery.ExpiresAt != nil {
			item.ExpiresAt = delivery.ExpiresAt.Format(time.RFC3339)
		}
		if delivery.RevokedAt != nil {
			item.RevokedAt = delivery.RevokedAt.Format(time.RFC3339)
		}
		out = append(out, item)
	}
	return &companionv1.ListProactiveDeliveriesReply{Deliveries: out}, nil
}

// RevokeProactiveDelivery records a user-scoped withdrawal of a proactive delivery.
func (s *AppService) RevokeProactiveDelivery(
	ctx context.Context,
	userID uint,
	in *companionv1.RevokeProactiveDeliveryRequest,
) (*companionv1.RevokeProactiveDeliveryReply, error) {
	engine, err := s.requireEngine()
	if err != nil {
		return nil, err
	}
	deliveryKey := strings.TrimSpace(in.GetDeliveryKey())
	if deliveryKey == "" {
		return nil, kerrors.BadRequest("COMPANION_PROACTIVE_DELIVERY_INVALID", "delivery key is required")
	}
	if err := engine.RevokeProactiveDelivery(ctx, userID, deliveryKey, in.GetReason()); err != nil {
		return nil, err
	}
	return &companionv1.RevokeProactiveDeliveryReply{}, nil
}

func (s *AppService) MarkProactiveRead(
	ctx context.Context,
	userID uint,
	in *companionv1.MarkProactiveReadRequest,
) (*companionv1.MarkProactiveReadReply, error) {
	engine, err := s.requireEngine()
	if err != nil {
		return nil, err
	}
	if s.db == nil {
		return nil, kerrors.ServiceUnavailable("COMPANION_UNAVAILABLE", "浼欎即鏈嶅姟鏆備笉鍙敤")
	}
	notificationID := uint(in.GetNotificationId())
	if notificationID == 0 {
		return nil, kerrors.BadRequest("COMPANION_PROACTIVE_NOTIFICATION_INVALID", "涓诲姩娑堟伅 ID 鏃犳晥")
	}
	var notice model.Notification
	if err := s.db.WithContext(ctx).
		Where("id = ? AND user_id = ? AND type = ?", notificationID, userID, 9).
		First(&notice).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, kerrors.NotFound("COMPANION_PROACTIVE_NOT_FOUND", "涓诲姩娑堟伅涓嶅瓨鍦ㄦ垨鏃犳潈闄")
		}
		return nil, err
	}
	if !notice.IsRead {
		if err := s.db.WithContext(ctx).Model(&model.Notification{}).
			Where("id = ? AND user_id = ? AND type = ?", notificationID, userID, 9).
			Update("is_read", true).Error; err != nil {
			return nil, err
		}
	}
	if err := engine.RecordProactiveRead(ctx, userID, notificationID); err != nil {
		return nil, err
	}
	return &companionv1.MarkProactiveReadReply{}, nil
}

// RecordSocialEvent projects a successful social action into CompanionEvent.
func (s *AppService) RecordSocialEvent(
	ctx context.Context,
	userID uint,
	eventType string,
	sourceID uint,
	payload map[string]interface{},
) error {
	engine, err := s.requireEngine()
	if err != nil {
		return err
	}
	return engine.RecordSocialEvent(ctx, userID, eventType, sourceID, payload)
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
	return s.ChatStreamWithInputMode(ctx, userID, message, override, scene, "text", onChunk)
}

// ChatStreamWithInputMode streams one turn and records its input channel.
func (s *AppService) ChatStreamWithInputMode(
	ctx context.Context,
	userID uint,
	message string,
	override *llminference.Config,
	scene string,
	inputMode string,
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
	return engine.ChatStreamWithInputMode(ctx, userID, message, onChunk, scene, inputMode, override)
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

func toProtoProactiveSettings(settings *companionbiz.ProactiveSettings) *companionv1.CompanionProactiveSettingsMsg {
	if settings == nil {
		return nil
	}
	return &companionv1.CompanionProactiveSettingsMsg{
		Enabled:        settings.Enabled,
		DailyLimit:     int32(settings.DailyLimit),
		QuietStart:     int32(settings.QuietStart),
		QuietEnd:       int32(settings.QuietEnd),
		TimezoneOffset: int32(settings.TimezoneOffset),
	}
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

func toProtoMemoryConflicts(conflicts []companionbiz.MemoryConflict) []*companionv1.CompanionMemoryConflictMsg {
	out := make([]*companionv1.CompanionMemoryConflictMsg, 0, len(conflicts))
	for _, conflict := range conflicts {
		out = append(out, &companionv1.CompanionMemoryConflictMsg{
			Id:               uint64(conflict.ID),
			MemoryId:         uint64(conflict.MemoryID),
			MemoryType:       conflict.MemoryType,
			MemoryKey:        conflict.MemoryKey,
			CandidateContent: conflict.CandidateContent,
			Confidence:       conflict.Confidence,
			Status:           conflict.Status,
			CreatedAt:        conflict.CreatedAt.Format("2006-01-02 15:04:05"),
			ResolvedAt:       formatOptionalTime(conflict.ResolvedAt),
		})
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

func toProtoEvents(events []companionbiz.Event) []*companionv1.CompanionEventMsg {
	out := make([]*companionv1.CompanionEventMsg, 0, len(events))
	for _, event := range events {
		out = append(out, &companionv1.CompanionEventMsg{
			Id:                uint64(event.ID),
			EventType:         event.EventType,
			SourceDomain:      event.SourceDomain,
			SourceId:          uint64(event.SourceID),
			DedupeKey:         event.DedupeKey,
			PayloadJson:       event.PayloadJSON,
			Visibility:        event.Visibility,
			Sensitivity:       event.Sensitivity,
			RelationshipDelta: event.RelationshipDelta,
			OccurredAt:        event.OccurredAt.Format(time.RFC3339),
			CreatedAt:         event.CreatedAt.Format(time.RFC3339),
		})
	}
	return out
}
