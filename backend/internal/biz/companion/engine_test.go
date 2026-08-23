package companionbiz

import (
	"context"
	"errors"
	"strings"
	"sync"
	"testing"
	"time"

	"backend/model"
	"backend/pkg/llminference"

	"gorm.io/gorm"
)

func TestGetProfileCreatesStableLifeBinding(t *testing.T) {
	store := newFakeStore()
	life := &fakeLifeStore{entities: []model.LifeEntity{
		{ID: 9, Name: "Nine", Emoji: "9", IsAlive: true},
		{ID: 2, Name: "Two", Emoji: "2", IsAlive: true},
	}}
	engine := NewEngine(store, life, llminference.Config{}, "")

	profile, err := engine.GetProfile(context.Background(), 7)
	if err != nil {
		t.Fatalf("GetProfile() error = %v", err)
	}
	if profile.LifeEntityID != 2 || profile.Name != "Two" {
		t.Fatalf("GetProfile() binding = (%d, %q), want (2, Two)", profile.LifeEntityID, profile.Name)
	}

	again, err := engine.GetProfile(context.Background(), 7)
	if err != nil {
		t.Fatalf("GetProfile() second error = %v", err)
	}
	if again.LifeEntityID != profile.LifeEntityID {
		t.Fatalf("GetProfile() binding changed from %d to %d", profile.LifeEntityID, again.LifeEntityID)
	}
}

func TestBuildContextUsesOneCanonicalSnapshot(t *testing.T) {
	store := newFakeStore()
	store.profiles[7] = profileToModel(7, &Profile{Name: "Mochi"})
	store.memories = []model.CompanionMemory{{
		ID:         1,
		UserID:     7,
		MemoryType: "fact",
		Content:    "likes tea",
	}}
	store.logs = []model.CompanionChatLog{{
		ID:      1,
		UserID:  7,
		Role:    "user",
		Content: "hello",
	}}
	store.logs = append(store.logs, model.CompanionChatLog{
		ID:      2,
		UserID:  7,
		Role:    "user",
		Content: "下次继续聊我的旅行计划",
	})
	store.relationshipEvents = []model.CompanionRelationshipEvent{{
		ID:                2,
		UserID:            7,
		EventType:         "first_chat",
		Title:             "第一次聊天",
		Content:           "你们开始了第一次对话",
		RelationshipLevel: 1,
	}}
	engine := NewEngine(store, nil, llminference.Config{}, "")

	snapshot, err := engine.BuildContext(context.Background(), 7, "morning")
	if err != nil {
		t.Fatalf("BuildContext() error = %v", err)
	}
	if snapshot.Profile.Name != "Mochi" || snapshot.Scene != "morning" {
		t.Fatalf("snapshot identity = (%q, %q)", snapshot.Profile.Name, snapshot.Scene)
	}
	if len(snapshot.Memories) != 1 || len(snapshot.History) != 2 || snapshot.IsFirstChat {
		t.Fatalf("snapshot data = memories=%d history=%d first=%v", len(snapshot.Memories), len(snapshot.History), snapshot.IsFirstChat)
	}
	if len(snapshot.RelationshipEvents) != 1 || snapshot.RelationshipEvents[0].Title != "第一次聊天" {
		t.Fatalf("snapshot relationship events = %+v", snapshot.RelationshipEvents)
	}
	if len(snapshot.UnfinishedTopics) != 1 || snapshot.UnfinishedTopics[0] != "下次继续聊我的旅行计划" {
		t.Fatalf("snapshot unfinished topics = %+v", snapshot.UnfinishedTopics)
	}
}

func TestExtractUnfinishedTopicsOnlyUsesExplicitMarkers(t *testing.T) {
	topics := extractUnfinishedTopics([]ChatLog{
		{Role: "user", Content: "今天的天气不错"},
		{Role: "user", Content: "之后继续聊这本书"},
		{Role: "user", Content: "之后继续聊这本书"},
	})
	if len(topics) != 1 || topics[0] != "之后继续聊这本书" {
		t.Fatalf("extractUnfinishedTopics() = %+v", topics)
	}
}

func TestVoiceChatCompletionProducesVoiceEvent(t *testing.T) {
	store := newFakeStore()
	engine := NewEngine(store, nil, llminference.Config{}, "")

	engine.recordChatCompletedEvent(context.Background(), 7, "comfort", "llm", "voice")

	foundVoice := false
	foundChatInputMode := false
	for _, event := range store.companionEvents {
		if event.EventType == "voice_turn_completed" {
			foundVoice = true
		}
		if event.EventType == "chat_turn_completed" && strings.Contains(event.PayloadJSON, `"input_mode":"voice"`) {
			foundChatInputMode = true
		}
	}
	if !foundVoice || !foundChatInputMode {
		t.Fatalf("events = %+v, want voice and voice-mode chat events", store.companionEvents)
	}
}

func TestChatStreamReportsUnconfiguredModel(t *testing.T) {
	engine := NewEngine(newFakeStore(), nil, llminference.Config{}, "")

	if _, err := engine.ChatStreamWithInputMode(
		context.Background(), 7, "hello", nil, "", "text",
	); err == nil {
		t.Fatal("ChatStreamWithInputMode() error = nil, want model configuration error")
	}
}

func TestUpsertProfileClearsMissingLifeBinding(t *testing.T) {
	engine := NewEngine(
		newFakeStore(),
		&fakeLifeStore{entities: []model.LifeEntity{{ID: 2, IsAlive: true}}},
		llminference.Config{},
		"",
	)

	saved, err := engine.UpsertProfile(context.Background(), 7, &Profile{LifeEntityID: 99})
	if err != nil {
		t.Fatalf("UpsertProfile() error = %v, want nil", err)
	}
	if saved.LifeEntityID != 0 {
		t.Fatalf("UpsertProfile() binding = %d, want 0", saved.LifeEntityID)
	}
}

func TestFetchLifeDataDoesNotFallbackToAnotherEntity(t *testing.T) {
	engine := NewEngine(
		newFakeStore(),
		&fakeLifeStore{entities: []model.LifeEntity{{ID: 2, IsAlive: true}}},
		llminference.Config{},
		"",
	)

	entity, events := engine.fetchLifeData(context.Background(), 99)
	if entity != nil || len(events) != 0 {
		t.Fatalf("fetchLifeData() = (%v, %v), want nil and no events", entity, events)
	}
}

func TestGetProfileKeepsExistingProfileUnboundUntilExplicitlyBound(t *testing.T) {
	store := newFakeStore()
	life := &fakeLifeStore{}
	engine := NewEngine(store, life, llminference.Config{}, "")

	initial, err := engine.GetProfile(context.Background(), 7)
	if err != nil {
		t.Fatalf("GetProfile() initial error = %v", err)
	}
	if initial.LifeEntityID != 0 {
		t.Fatalf("GetProfile() initial binding = %d, want 0", initial.LifeEntityID)
	}

	life.entities = []model.LifeEntity{{ID: 3, Name: "Three", Emoji: "3", IsAlive: true}}
	bound, err := engine.GetProfile(context.Background(), 7)
	if err != nil {
		t.Fatalf("GetProfile() after Life startup error = %v", err)
	}
	if bound.LifeEntityID != 0 {
		t.Fatalf("GetProfile() binding = %d, want 0", bound.LifeEntityID)
	}
	if store.profiles[7].LifeEntityID != 0 {
		t.Fatalf("persisted binding = %d, want 0", store.profiles[7].LifeEntityID)
	}
}

func TestBindLifeEntityDoesNotOverwriteCustomIdentity(t *testing.T) {
	store := newFakeStore()
	store.profiles[7] = profileToModel(7, &Profile{
		Name:         "小花",
		Emoji:        "🐰",
		AvatarURL:    "https://example.com/a.png",
		LifeEntityID: 3,
	})
	life := &fakeLifeStore{entities: []model.LifeEntity{
		{ID: 3, Name: "啾啾", Emoji: "🐥", IsAlive: true},
	}}
	engine := NewEngine(store, life, llminference.Config{}, "")

	profile, err := engine.GetProfile(context.Background(), 7)
	if err != nil {
		t.Fatalf("GetProfile() error = %v", err)
	}
	if profile.LifeEntityID != 3 {
		t.Fatalf("LifeEntityID = %d, want 3", profile.LifeEntityID)
	}
	if profile.Name != "小花" || profile.Emoji != "🐰" || profile.AvatarURL != "https://example.com/a.png" {
		t.Fatalf("identity overwritten: name=%q emoji=%q avatar=%q",
			profile.Name, profile.Emoji, profile.AvatarURL)
	}
}

func TestDeadLifeBindingKeptWithMissingStatus(t *testing.T) {
	store := newFakeStore()
	store.profiles[7] = profileToModel(7, &Profile{LifeEntityID: 2, Name: "Old"})
	life := &fakeLifeStore{
		entities: []model.LifeEntity{
			{ID: 2, Name: "Old", Emoji: "2", IsAlive: false},
			{ID: 3, Name: "Three", Emoji: "3", IsAlive: true},
		},
	}
	engine := NewEngine(store, life, llminference.Config{}, "")

	stale, err := engine.GetProfile(context.Background(), 7)
	if err != nil {
		t.Fatalf("GetProfile() stale binding error = %v", err)
	}
	if stale.LifeEntityID != 2 {
		t.Fatalf("GetProfile() binding = %d, want 2 (keep)", stale.LifeEntityID)
	}
	if stale.WorldBindStatus != WorldBindMissing {
		t.Fatalf("WorldBindStatus = %q, want %q", stale.WorldBindStatus, WorldBindMissing)
	}

	rebound, err := engine.UpsertProfile(context.Background(), 7, &Profile{LifeEntityID: 3})
	if err != nil {
		t.Fatalf("UpsertProfile() rebound error = %v", err)
	}
	if rebound.LifeEntityID != 3 || rebound.WorldBindStatus != WorldBindOK {
		t.Fatalf("UpsertProfile() = (%d, %q), want (3, bound_ok)", rebound.LifeEntityID, rebound.WorldBindStatus)
	}
}

func TestFetchLifeDataLoadsEventsWhenEntityDead(t *testing.T) {
	life := &fakeLifeStore{
		entities: []model.LifeEntity{{ID: 2, Name: "Two", IsAlive: false}},
		events: []model.LifeEventLog{
			{EntityID: 2, Description: "吃了点东西", EventType: "eat", CreatedAt: time.Now()},
		},
	}
	engine := NewEngine(newFakeStore(), life, llminference.Config{}, "")
	entity, events := engine.fetchLifeData(context.Background(), 2)
	if entity == nil || entity.IsAlive {
		t.Fatalf("entity = %v, want dead entity", entity)
	}
	if len(events) != 1 {
		t.Fatalf("events len = %d, want 1", len(events))
	}
	state := computeState(&Profile{LifeEntityID: 2, WorldBindStatus: WorldBindMissing}, entity, events)
	if state.EntityAlive || len(state.Moments) != 1 {
		t.Fatalf("state alive=%v moments=%d", state.EntityAlive, len(state.Moments))
	}
}

func TestDeleteAndPinMemory(t *testing.T) {
	store := newFakeStore()
	engine := NewEngine(store, nil, llminference.Config{}, "")
	exp := time.Now().Add(24 * time.Hour)
	if err := store.CreateMemory(context.Background(), &model.CompanionMemory{
		UserID:     7,
		MemoryType: "fact",
		Content:    "喜欢猫",
		Importance: 0,
		ExpiresAt:  &exp,
	}); err != nil {
		t.Fatalf("CreateMemory: %v", err)
	}

	pinned, err := engine.SetMemoryPinned(context.Background(), 7, 1, true)
	if err != nil {
		t.Fatalf("SetMemoryPinned: %v", err)
	}
	if !pinned.Pinned || pinned.Importance < 2 || pinned.ExpiresAt != nil {
		t.Fatalf("pin result = %+v", pinned)
	}

	edited, err := engine.UpdateMemoryContent(context.Background(), 7, 1, "其实更喜欢狗")
	if err != nil {
		t.Fatalf("UpdateMemoryContent: %v", err)
	}
	if edited.Content != "其实更喜欢狗" || !edited.UserConfirmed || edited.ConfirmedAt == nil {
		t.Fatalf("content = %q", edited.Content)
	}
	confirmed, err := engine.ConfirmMemory(context.Background(), 7, 1)
	if err != nil {
		t.Fatalf("ConfirmMemory: %v", err)
	}
	if !confirmed.UserConfirmed || confirmed.ConfirmedAt == nil {
		t.Fatalf("confirm result = %+v", confirmed)
	}

	if err := engine.DeleteMemory(context.Background(), 7, 1); err != nil {
		t.Fatalf("DeleteMemory: %v", err)
	}
	if err := engine.DeleteMemory(context.Background(), 7, 1); !errors.Is(err, ErrMemoryNotFound) {
		t.Fatalf("second delete err = %v, want ErrMemoryNotFound", err)
	}
}

func TestMemoryDedupeKeyNormalizesWhitespaceAndCase(t *testing.T) {
	left := memoryDedupeKey(" Preference ", "  I  like  tea ")
	right := memoryDedupeKey("preference", "i like tea")
	if left != right {
		t.Fatalf("keys differ: %q != %q", left, right)
	}
}

func TestListEventsIsolatesUsersAndPreservesPayload(t *testing.T) {
	store := newFakeStore()
	store.companionEvents = []model.CompanionEvent{
		{
			ID:          1,
			UserID:      7,
			EventType:   "relationship_level_up",
			PayloadJSON: `{"title":"level up"}`,
			OccurredAt:  time.Now(),
		},
		{ID: 2, UserID: 8, EventType: "chat_turn_completed", OccurredAt: time.Now()},
	}
	engine := NewEngine(store, nil, llminference.Config{}, "")

	events, err := engine.ListEvents(context.Background(), 7, 10)
	if err != nil {
		t.Fatalf("ListEvents() error = %v", err)
	}
	if len(events) != 1 || events[0].UserID != 7 {
		t.Fatalf("ListEvents() = %+v, want only user 7", events)
	}
	if events[0].PayloadJSON != `{"title":"level up"}` {
		t.Fatalf("payload = %q, want preserved JSON", events[0].PayloadJSON)
	}
}

func TestObserveLifeEventProjectsOnlyBoundUsers(t *testing.T) {
	store := newFakeStore()
	store.profiles[7] = profileToModel(7, &Profile{LifeEntityID: 42})
	store.profiles[8] = profileToModel(8, &Profile{LifeEntityID: 99})
	engine := NewEngine(store, nil, llminference.Config{}, "")

	engine.ObserveLifeEvent(context.Background(), &model.LifeEventLog{
		ID:          12,
		WorldID:     "default",
		EntityID:    42,
		EventType:   "growth",
		Description: "grew up",
		CreatedAt:   time.Now(),
	})

	if len(store.companionEvents) != 1 || store.companionEvents[0].UserID != 7 {
		t.Fatalf("projected events = %+v, want only user 7", store.companionEvents)
	}
	if store.companionEvents[0].EventType != "life_moment_created" {
		t.Fatalf("event type = %q, want life_moment_created", store.companionEvents[0].EventType)
	}
}

func TestObserveLifeEventSkipsRoutineLifeEvents(t *testing.T) {
	store := newFakeStore()
	store.profiles[7] = profileToModel(7, &Profile{LifeEntityID: 42})
	engine := NewEngine(store, nil, llminference.Config{}, "")

	engine.ObserveLifeEvent(context.Background(), &model.LifeEventLog{
		ID:        13,
		EntityID:  42,
		EventType: "eating",
		CreatedAt: time.Now(),
	})

	if len(store.companionEvents) != 0 {
		t.Fatalf("projected routine events = %+v, want none", store.companionEvents)
	}
}

func TestObserveLifeCareEventUsesCareEventType(t *testing.T) {
	store := newFakeStore()
	store.profiles[7] = profileToModel(7, &Profile{LifeEntityID: 42})
	engine := NewEngine(store, nil, llminference.Config{}, "")

	engine.ObserveLifeEvent(context.Background(), &model.LifeEventLog{
		ID:        14,
		EntityID:  42,
		EventType: "user_feed",
		CreatedAt: time.Now(),
	})

	if len(store.companionEvents) != 1 || store.companionEvents[0].EventType != "life_care_completed" {
		t.Fatalf("projected care events = %+v, want life_care_completed", store.companionEvents)
	}
}

func TestRecordProactiveReadPersistsUnifiedEvent(t *testing.T) {
	store := newFakeStore()
	engine := NewEngine(store, nil, llminference.Config{}, "")

	if err := engine.RecordProactiveRead(context.Background(), 7, 42); err != nil {
		t.Fatalf("RecordProactiveRead() error = %v", err)
	}
	if len(store.companionEvents) != 1 {
		t.Fatalf("companion events=%d, want 1", len(store.companionEvents))
	}
	event := store.companionEvents[0]
	if event.EventType != "proactive_read" || event.SourceID != 42 ||
		event.DedupeKey != "proactive_read:42" {
		t.Fatalf("event=%+v, want proactive read acknowledgement", event)
	}
}

func TestRecordProactiveReadIsIdempotent(t *testing.T) {
	store := newFakeStore()
	engine := NewEngine(store, nil, llminference.Config{}, "")
	eventCount := 0
	engine.OnEvent = func(_ uint, _ *model.CompanionEvent) {
		eventCount++
	}

	for range 2 {
		if err := engine.RecordProactiveRead(context.Background(), 7, 42); err != nil {
			t.Fatalf("RecordProactiveRead() error = %v", err)
		}
	}
	if len(store.companionEvents) != 1 || eventCount != 1 {
		t.Fatalf("events=%d broadcasts=%d, want one idempotent event", len(store.companionEvents), eventCount)
	}
}

func TestRecordSocialEventKeepsMetadataOnlyPayload(t *testing.T) {
	store := newFakeStore()
	engine := NewEngine(store, nil, llminference.Config{}, "")

	if err := engine.RecordSocialEvent(context.Background(), 7, "post_created", 42, map[string]interface{}{
		"topic_tag_count": 2,
	}); err != nil {
		t.Fatalf("RecordSocialEvent() error = %v", err)
	}
	if len(store.companionEvents) != 1 {
		t.Fatalf("companion events=%d, want 1", len(store.companionEvents))
	}
	event := store.companionEvents[0]
	if event.SourceDomain != "social" || event.SourceID != 42 ||
		event.PayloadJSON != `{"topic_tag_count":2}` {
		t.Fatalf("event=%+v, want social metadata event", event)
	}
}

func TestRecordMemoryConflictDoesNotExposeCandidateContent(t *testing.T) {
	store := newFakeStore()
	engine := NewEngine(store, nil, llminference.Config{}, "")
	previous := model.CompanionMemory{
		ID:            9,
		MemoryType:    "preference",
		MemoryKey:     "favorite_color",
		Content:       "用户喜欢蓝色",
		UserConfirmed: true,
	}
	candidate := extractedMemory{
		MemoryType: "preference",
		MemoryKey:  "favorite_color",
		Content:    "用户喜欢绿色",
		Confidence: 0.8,
	}

	engine.recordMemoryConflict(context.Background(), 7, previous, candidate)
	engine.recordMemoryConflict(context.Background(), 7, previous, candidate)
	if len(store.companionEvents) != 1 {
		t.Fatalf("companion events=%d, want 1", len(store.companionEvents))
	}
	event := store.companionEvents[0]
	if event.EventType != "memory_conflict_detected" ||
		strings.Contains(event.PayloadJSON, candidate.Content) {
		t.Fatalf("event=%+v, want metadata-only conflict event", event)
	}
	if len(store.conflicts) != 1 || store.conflicts[0].CandidateContent != candidate.Content {
		t.Fatalf("conflicts=%+v, want user-owned candidate", store.conflicts)
	}
}

func TestResolveMemoryConflictAcceptsCandidateAndIsIdempotent(t *testing.T) {
	store := newFakeStore()
	store.memories = []model.CompanionMemory{{
		ID: 1, UserID: 7, MemoryType: "preference", MemoryKey: "favorite_color",
		Content: "喜欢蓝色", UserConfirmed: true,
	}}
	store.conflicts = []model.CompanionMemoryConflict{{
		ID: 3, UserID: 7, MemoryID: 1, MemoryType: "preference",
		MemoryKey: "favorite_color", CandidateContent: "喜欢绿色", Confidence: 0.9,
		Status: "pending",
	}}
	engine := NewEngine(store, nil, llminference.Config{}, "")

	if err := engine.ResolveMemoryConflict(context.Background(), 7, 3, "accepted"); err != nil {
		t.Fatalf("ResolveMemoryConflict() error = %v", err)
	}
	if store.memories[0].Content != "喜欢绿色" || store.conflicts[0].Status != "accepted" {
		t.Fatalf("memory=%+v conflict=%+v, want accepted candidate", store.memories[0], store.conflicts[0])
	}
	if err := engine.ResolveMemoryConflict(context.Background(), 7, 3, "accepted"); !errors.Is(err, ErrMemoryConflictResolved) {
		t.Fatalf("second resolve error = %v, want ErrMemoryConflictResolved", err)
	}
}

func TestPushProactiveOnlyAfterInactivityCooldown(t *testing.T) {
	store := newFakeStore()
	store.logs = []model.CompanionChatLog{
		{
			UserID:    7,
			Role:      "user",
			Content:   "我明天要面试",
			CreatedAt: time.Now().Add(-25 * time.Hour),
		},
	}
	engine := NewEngine(store, nil, llminference.Config{}, "")
	messages := make([]string, 0, 2)
	engine.OnProactive = func(_ uint, message, _ string) (uint, bool) {
		messages = append(messages, message)
		return 42, true
	}

	engine.pushProactive(7)
	engine.pushProactive(7)

	if len(messages) != 1 || !strings.Contains(messages[0], "面试") {
		t.Fatalf("messages=%v, want one interview follow-up", messages)
	}
	var delivered *model.CompanionEvent
	for index := range store.companionEvents {
		if store.companionEvents[index].EventType == "proactive_delivered" {
			delivered = &store.companionEvents[index]
		}
	}
	if delivered == nil || delivered.SourceID != 42 || !strings.Contains(delivered.PayloadJSON, `"notification_id":42`) {
		t.Fatalf("delivered event=%+v, want notification correlation", delivered)
	}
}

func TestPushProactiveHonorsConfiguredDailyLimitAboveOne(t *testing.T) {
	store := newFakeStore()
	store.profiles[7] = profileToModel(7, &Profile{
		ProactiveEnabled:        true,
		ProactiveDailyLimit:     2,
		ProactiveQuietStart:     0,
		ProactiveQuietEnd:       0,
		ProactiveTimezoneOffset: 0,
	})
	store.logs = []model.CompanionChatLog{{
		UserID:    7,
		Role:      "user",
		Content:   "old topic",
		CreatedAt: time.Now().Add(-25 * time.Hour),
	}}
	engine := NewEngine(store, nil, llminference.Config{}, "")
	delivered := 0
	engine.OnProactive = func(_ uint, _, _ string) (uint, bool) {
		delivered++
		return uint(delivered), true
	}

	engine.pushProactive(7)
	engine.pushProactive(7)
	engine.pushProactive(7)

	if delivered != 2 {
		t.Fatalf("delivered = %d, want configured daily limit of two", delivered)
	}
}

func TestPushProactiveResumesPendingScheduledDelivery(t *testing.T) {
	store := newFakeStore()
	store.profiles[7] = profileToModel(7, &Profile{
		ProactiveEnabled:        true,
		ProactiveDailyLimit:     1,
		ProactiveQuietStart:     0,
		ProactiveQuietEnd:       0,
		ProactiveTimezoneOffset: 0,
	})
	store.logs = []model.CompanionChatLog{{
		UserID:    7,
		Role:      "user",
		Content:   "pending topic",
		CreatedAt: time.Now().Add(-25 * time.Hour),
	}}
	const deliveryKey = "proactive:7:2026-08-02:1:pending"
	store.companionEvents = []model.CompanionEvent{{
		ID:           1,
		UserID:       7,
		SourceDomain: "proactive",
		EventType:    "proactive_scheduled",
		DedupeKey:    deliveryKey,
		PayloadJSON:  `{"reason":"follow-up","priority":50,"expires_at":"2099-08-02T10:00:00Z"}`,
		OccurredAt:   time.Now().Add(-time.Minute),
	}}
	engine := NewEngine(store, nil, llminference.Config{}, "")
	delivered := 0
	engine.OnProactive = func(_ uint, _, _ string) (uint, bool) {
		delivered++
		return 42, true
	}

	engine.pushProactive(7)

	if delivered != 1 {
		t.Fatalf("delivered = %d, want pending scheduled delivery resumed", delivered)
	}
	for _, event := range store.companionEvents {
		if event.EventType == "proactive_delivered" && event.DedupeKey == deliveryKey+":delivered" {
			return
		}
	}
	t.Fatalf("events=%+v, want delivered event for pending key", store.companionEvents)
}

func TestPushProactiveRestoresPersistedDailyLimit(t *testing.T) {
	store := newFakeStore()
	store.profiles[7] = profileToModel(7, &Profile{
		ProactiveEnabled:        true,
		ProactiveDailyLimit:     1,
		ProactiveQuietStart:     0,
		ProactiveQuietEnd:       0,
		ProactiveTimezoneOffset: 0,
	})
	store.logs = []model.CompanionChatLog{{
		UserID:    7,
		Role:      "user",
		Content:   "old topic",
		CreatedAt: time.Now().Add(-25 * time.Hour),
	}}
	store.companionEvents = []model.CompanionEvent{{
		UserID:     7,
		EventType:  "proactive_delivered",
		OccurredAt: time.Now().UTC(),
	}}
	engine := NewEngine(store, nil, llminference.Config{}, "")
	delivered := 0
	engine.OnProactive = func(_ uint, _, _ string) (uint, bool) {
		delivered++
		return 42, true
	}

	engine.pushProactive(7)

	if delivered != 0 {
		t.Fatalf("delivered = %d, want persisted daily limit to block duplicate", delivered)
	}
}

func TestPushProactiveDoesNotRecordDeliveryWhenCallbackFails(t *testing.T) {
	store := newFakeStore()
	store.profiles[7] = profileToModel(7, &Profile{
		ProactiveEnabled:        true,
		ProactiveDailyLimit:     1,
		ProactiveQuietStart:     0,
		ProactiveQuietEnd:       0,
		ProactiveTimezoneOffset: 0,
	})
	store.logs = []model.CompanionChatLog{{
		UserID:    7,
		Role:      "user",
		Content:   "old topic",
		CreatedAt: time.Now().Add(-25 * time.Hour),
	}}
	engine := NewEngine(store, nil, llminference.Config{}, "")
	attempts := 0
	engine.OnProactive = func(_ uint, _, _ string) (uint, bool) {
		attempts++
		return 0, false
	}

	engine.pushProactive(7)
	engine.pushProactive(7)

	if attempts != 2 {
		t.Fatalf("attempts = %d, want failed delivery to release the limit", attempts)
	}
	for _, event := range store.companionEvents {
		if event.EventType == "proactive_delivered" {
			t.Fatal("failed callback must not record proactive_delivered")
		}
	}
}

func TestPushProactiveFailureOnlyReleasesItsOwnReservation(t *testing.T) {
	store := newFakeStore()
	store.profiles[7] = profileToModel(7, &Profile{
		ProactiveEnabled:        true,
		ProactiveDailyLimit:     2,
		ProactiveQuietStart:     0,
		ProactiveQuietEnd:       0,
		ProactiveTimezoneOffset: 0,
	})
	store.logs = []model.CompanionChatLog{{
		UserID:    7,
		Role:      "user",
		Content:   "old topic",
		CreatedAt: time.Now().Add(-25 * time.Hour),
	}}
	engine := NewEngine(store, nil, llminference.Config{}, "")
	var callbackMu sync.Mutex
	callbackCount := 0
	firstEntered := make(chan struct{})
	secondEntered := make(chan struct{})
	releaseFirst := make(chan struct{})
	engine.OnProactive = func(_ uint, _, _ string) (uint, bool) {
		callbackMu.Lock()
		callbackCount++
		current := callbackCount
		callbackMu.Unlock()
		if current == 1 {
			close(firstEntered)
			<-releaseFirst
			return 0, false
		}
		if current == 2 {
			close(secondEntered)
		}
		return 42, true
	}

	var waitGroup sync.WaitGroup
	waitGroup.Add(1)
	go func() {
		defer waitGroup.Done()
		engine.pushProactive(7)
	}()
	<-firstEntered
	waitGroup.Add(1)
	go func() {
		defer waitGroup.Done()
		engine.pushProactive(7)
	}()
	<-secondEntered
	close(releaseFirst)
	waitGroup.Wait()

	engine.pushProactive(7)
	engine.pushProactive(7)
	callbackMu.Lock()
	defer callbackMu.Unlock()
	if callbackCount != 3 {
		t.Fatalf("callback count = %d, want two reservations plus one available retry", callbackCount)
	}
}

func TestUpdateProactiveSettingsClampsPersistedValues(t *testing.T) {
	store := newFakeStore()
	engine := NewEngine(store, nil, llminference.Config{}, "")

	settings, err := engine.UpdateProactiveSettings(context.Background(), 7, ProactiveSettings{
		Enabled:        true,
		DailyLimit:     99,
		QuietStart:     -10,
		QuietEnd:       2000,
		TimezoneOffset: -2000,
	})
	if err != nil {
		t.Fatalf("UpdateProactiveSettings() error = %v", err)
	}
	if settings.DailyLimit != 3 || settings.QuietStart != 0 || settings.QuietEnd != 1439 || settings.TimezoneOffset != -840 {
		t.Fatalf("settings = %+v, want clamped values", settings)
	}

	profile, err := engine.GetProfile(context.Background(), 7)
	if err != nil {
		t.Fatalf("GetProfile() error = %v", err)
	}
	if profile.ProactiveDailyLimit != 3 || profile.ProactiveQuietStart != 0 || profile.ProactiveQuietEnd != 1439 || profile.ProactiveTimezoneOffset != -840 {
		t.Fatalf("profile = %+v, want clamped values persisted", profile)
	}
}

func TestUpsertProfileDoesNotResetProactiveSettings(t *testing.T) {
	store := newFakeStore()
	store.profiles[7] = profileToModel(7, &Profile{
		Name:                    "Existing",
		ProactiveEnabled:        false,
		ProactiveDailyLimit:     2,
		ProactiveQuietStart:     60,
		ProactiveQuietEnd:       120,
		ProactiveTimezoneOffset: 480,
	})
	engine := NewEngine(store, nil, llminference.Config{}, "")

	if _, err := engine.UpsertProfile(context.Background(), 7, &Profile{Name: "Renamed"}); err != nil {
		t.Fatalf("UpsertProfile() error = %v", err)
	}
	profile, err := engine.GetProfile(context.Background(), 7)
	if err != nil {
		t.Fatalf("GetProfile() error = %v", err)
	}
	if profile.ProactiveEnabled || profile.ProactiveDailyLimit != 2 ||
		profile.ProactiveQuietStart != 60 || profile.ProactiveQuietEnd != 120 ||
		profile.ProactiveTimezoneOffset != 480 {
		t.Fatalf("profile proactive settings = %+v, want unchanged settings", profile)
	}
}

func TestListProactiveDeliveriesRebuildsReadState(t *testing.T) {
	store := newFakeStore()
	scheduledAt := time.Now().Add(-3 * time.Minute)
	deliveredAt := time.Now().Add(-2 * time.Minute)
	readAt := time.Now().Add(-time.Minute)
	store.companionEvents = []model.CompanionEvent{
		{
			ID:           1,
			UserID:       7,
			SourceDomain: "proactive",
			DedupeKey:    "proactive:7:2026-08-02:1:100",
			PayloadJSON:  `{"reason":"follow-up","priority":75,"expires_at":"2099-08-02T10:00:00Z"}`,
			OccurredAt:   scheduledAt,
		},
		{
			ID:           2,
			UserID:       7,
			SourceDomain: "proactive",
			SourceID:     42,
			DedupeKey:    "proactive:7:2026-08-02:1:100:delivered",
			PayloadJSON:  `{"reason":"follow-up","notification_id":42}`,
			OccurredAt:   deliveredAt,
		},
		{
			ID:           3,
			UserID:       7,
			SourceDomain: "proactive",
			SourceID:     42,
			EventType:    "proactive_read",
			DedupeKey:    "proactive_read:42",
			PayloadJSON:  `{"notification_id":42}`,
			OccurredAt:   readAt,
		},
	}
	engine := NewEngine(store, nil, llminference.Config{}, "")

	deliveries, err := engine.ListProactiveDeliveries(context.Background(), 7, 10)
	if err != nil {
		t.Fatalf("ListProactiveDeliveries() error = %v", err)
	}
	if len(deliveries) != 1 {
		t.Fatalf("deliveries=%+v, want one delivery", deliveries)
	}
	delivery := deliveries[0]
	if delivery.Status != "read" || delivery.NotificationID != 42 || delivery.Priority != 75 ||
		delivery.ExpiresAt == nil || delivery.ReadAt == nil {
		t.Fatalf("delivery=%+v, want rebuilt read state", delivery)
	}
}

func TestListProactiveDeliveriesPrioritizesUrgentItems(t *testing.T) {
	store := newFakeStore()
	store.companionEvents = []model.CompanionEvent{
		{
			ID:           1,
			UserID:       7,
			SourceDomain: "proactive",
			DedupeKey:    "proactive:7:2026-08-02:1:low",
			PayloadJSON:  `{"reason":"routine","priority":20}`,
			OccurredAt:   time.Now().Add(-time.Minute),
		},
		{
			ID:           2,
			UserID:       7,
			SourceDomain: "proactive",
			DedupeKey:    "proactive:7:2026-08-02:2:urgent",
			PayloadJSON:  `{"reason":"urgent","priority":90}`,
			OccurredAt:   time.Now().Add(-2 * time.Minute),
		},
	}
	engine := NewEngine(store, nil, llminference.Config{}, "")

	deliveries, err := engine.ListProactiveDeliveries(context.Background(), 7, 1)
	if err != nil {
		t.Fatalf("ListProactiveDeliveries() error = %v", err)
	}
	if len(deliveries) != 1 || deliveries[0].Priority != 90 {
		t.Fatalf("deliveries=%+v, want highest-priority item", deliveries)
	}
}

func TestRevokeProactiveDeliveryWritesAuditableEvent(t *testing.T) {
	store := newFakeStore()
	engine := NewEngine(store, nil, llminference.Config{}, "")
	deliveryKey := "proactive:7:2026-08-02:1:100"

	if err := engine.RevokeProactiveDelivery(context.Background(), 7, deliveryKey, "expired context"); err != nil {
		t.Fatalf("RevokeProactiveDelivery() error = %v", err)
	}
	if len(store.companionEvents) != 1 || store.companionEvents[0].EventType != "proactive_revoked" ||
		!strings.Contains(store.companionEvents[0].PayloadJSON, deliveryKey) {
		t.Fatalf("events=%+v, want auditable revoke event", store.companionEvents)
	}
}

type fakeStore struct {
	profiles           map[uint]*model.CompanionProfile
	memories           []model.CompanionMemory
	logs               []model.CompanionChatLog
	relationshipEvents []model.CompanionRelationshipEvent
	companionEvents    []model.CompanionEvent
	conflicts          []model.CompanionMemoryConflict
}

func newFakeStore() *fakeStore {
	return &fakeStore{profiles: make(map[uint]*model.CompanionProfile)}
}

func (s *fakeStore) GetProfileByUserID(_ context.Context, userID uint) (*model.CompanionProfile, error) {
	profile := s.profiles[userID]
	if profile == nil {
		return nil, nil
	}
	profileCopy := *profile
	return &profileCopy, nil
}

func (s *fakeStore) UpsertProfile(_ context.Context, profile *model.CompanionProfile) error {
	profileCopy := *profile
	if existing := s.profiles[profile.UserID]; existing != nil {
		profileCopy.ID = existing.ID
		profileCopy.RelationshipLevel = existing.RelationshipLevel
		profileCopy.IntimacyScore = existing.IntimacyScore
		profileCopy.ProactiveEnabled = existing.ProactiveEnabled
		profileCopy.ProactiveDailyLimit = existing.ProactiveDailyLimit
		profileCopy.ProactiveQuietStart = existing.ProactiveQuietStart
		profileCopy.ProactiveQuietEnd = existing.ProactiveQuietEnd
		profileCopy.ProactiveTimezoneOffset = existing.ProactiveTimezoneOffset
	} else {
		profileCopy.ID = uint(len(s.profiles) + 1)
	}
	s.profiles[profile.UserID] = &profileCopy
	return nil
}

func (s *fakeStore) UpdateProactiveSettings(
	_ context.Context,
	userID uint,
	enabled bool,
	dailyLimit, quietStart, quietEnd, timezoneOffset int,
) error {
	row := s.profiles[userID]
	if row == nil {
		return nil
	}
	row.ProactiveEnabled = enabled
	row.ProactiveDailyLimit = dailyLimit
	row.ProactiveQuietStart = quietStart
	row.ProactiveQuietEnd = quietEnd
	row.ProactiveTimezoneOffset = timezoneOffset
	return nil
}

func (s *fakeStore) UpdateIntimacy(_ context.Context, userID uint, intimacy float64, level int) error {
	row := s.profiles[userID]
	if row == nil {
		return nil
	}
	row.IntimacyScore = intimacy
	row.RelationshipLevel = level
	return nil
}

func (s *fakeStore) ListProfileUserIDs(_ context.Context) ([]uint, error) {
	userIDs := make([]uint, 0, len(s.profiles))
	for userID := range s.profiles {
		userIDs = append(userIDs, userID)
	}
	return userIDs, nil
}

func (s *fakeStore) ListProfileUserIDsByLifeEntityID(_ context.Context, entityID uint) ([]uint, error) {
	userIDs := make([]uint, 0)
	for userID, profile := range s.profiles {
		if profile.LifeEntityID == int(entityID) {
			userIDs = append(userIDs, userID)
		}
	}
	return userIDs, nil
}

func (s *fakeStore) CreateMemory(_ context.Context, memory *model.CompanionMemory) error {
	memory.ID = uint(len(s.memories) + 1)
	s.memories = append(s.memories, *memory)
	return nil
}

func (s *fakeStore) ListActiveMemories(_ context.Context, userID uint, limit int) ([]model.CompanionMemory, error) {
	out := make([]model.CompanionMemory, 0, len(s.memories))
	for _, m := range s.memories {
		if m.UserID == userID {
			out = append(out, m)
		}
	}
	if limit > 0 && len(out) > limit {
		out = out[:limit]
	}
	return out, nil
}

func (s *fakeStore) GetMemoryByID(_ context.Context, userID, memoryID uint) (*model.CompanionMemory, error) {
	for i := range s.memories {
		if s.memories[i].ID == memoryID && s.memories[i].UserID == userID {
			row := s.memories[i]
			return &row, nil
		}
	}
	return nil, nil
}

func (s *fakeStore) DeleteMemory(_ context.Context, userID, memoryID uint) error {
	for i := range s.memories {
		if s.memories[i].ID == memoryID && s.memories[i].UserID == userID {
			s.memories = append(s.memories[:i], s.memories[i+1:]...)
			return nil
		}
	}
	return gorm.ErrRecordNotFound
}

func (s *fakeStore) UpdateMemoryPinned(
	_ context.Context,
	userID, memoryID uint,
	pinned bool,
	importance int,
	expiresAt *time.Time,
) error {
	for i := range s.memories {
		if s.memories[i].ID == memoryID && s.memories[i].UserID == userID {
			s.memories[i].Pinned = pinned
			s.memories[i].Importance = importance
			s.memories[i].ExpiresAt = expiresAt
			return nil
		}
	}
	return gorm.ErrRecordNotFound
}

func (s *fakeStore) CorrectMemoryContent(
	_ context.Context,
	userID, memoryID uint,
	content string,
	confirmedAt time.Time,
) error {
	for i := range s.memories {
		if s.memories[i].ID == memoryID && s.memories[i].UserID == userID {
			s.memories[i].Content = content
			s.memories[i].UserConfirmed = true
			s.memories[i].ConfirmedAt = &confirmedAt
			return nil
		}
	}
	return gorm.ErrRecordNotFound
}

func (s *fakeStore) UpdateMemoryRecord(
	_ context.Context,
	userID, memoryID uint,
	memoryType, memoryKey, content string,
	importance int,
	expiresAt *time.Time,
	confidence float64,
) error {
	for index := range s.memories {
		memory := &s.memories[index]
		if memory.ID == memoryID && memory.UserID == userID && !memory.UserConfirmed {
			memory.MemoryType = memoryType
			memory.MemoryKey = memoryKey
			memory.Content = content
			memory.Importance = importance
			memory.ExpiresAt = expiresAt
			memory.Confidence = confidence
			return nil
		}
	}
	return gorm.ErrRecordNotFound
}

func (s *fakeStore) ConfirmMemory(_ context.Context, userID, memoryID uint, confirmedAt time.Time) error {
	for index := range s.memories {
		if s.memories[index].ID == memoryID && s.memories[index].UserID == userID {
			s.memories[index].UserConfirmed = true
			s.memories[index].ConfirmedAt = &confirmedAt
			return nil
		}
	}
	return gorm.ErrRecordNotFound
}

func (s *fakeStore) CleanupExpiredMemories(_ context.Context) (int64, error) {
	return 0, nil
}

func (s *fakeStore) CreateMemoryConflict(_ context.Context, conflict *model.CompanionMemoryConflict) error {
	for _, existing := range s.conflicts {
		if existing.DedupeKey == conflict.DedupeKey {
			return gorm.ErrDuplicatedKey
		}
	}
	conflict.ID = uint(len(s.conflicts) + 1)
	s.conflicts = append(s.conflicts, *conflict)
	return nil
}

func (s *fakeStore) ListMemoryConflicts(_ context.Context, userID uint, limit int) ([]model.CompanionMemoryConflict, error) {
	out := make([]model.CompanionMemoryConflict, 0, len(s.conflicts))
	for _, conflict := range s.conflicts {
		if conflict.UserID == userID && conflict.Status == "pending" {
			out = append(out, conflict)
		}
	}
	if limit > 0 && len(out) > limit {
		out = out[:limit]
	}
	return out, nil
}

func (s *fakeStore) GetMemoryConflict(_ context.Context, userID, conflictID uint) (*model.CompanionMemoryConflict, error) {
	for index := range s.conflicts {
		if s.conflicts[index].ID == conflictID && s.conflicts[index].UserID == userID {
			row := s.conflicts[index]
			return &row, nil
		}
	}
	return nil, nil
}

func (s *fakeStore) ResolveMemoryConflict(_ context.Context, userID, conflictID uint, status string, resolvedAt time.Time) error {
	for index := range s.conflicts {
		if s.conflicts[index].ID == conflictID && s.conflicts[index].UserID == userID && s.conflicts[index].Status == "pending" {
			s.conflicts[index].Status = status
			s.conflicts[index].ResolvedAt = &resolvedAt
			return nil
		}
	}
	return gorm.ErrRecordNotFound
}

func (s *fakeStore) AppendChatLog(_ context.Context, chatLog *model.CompanionChatLog) error {
	s.logs = append(s.logs, *chatLog)
	return nil
}

func (s *fakeStore) ListRecentChatLogs(_ context.Context, userID uint, limit int) ([]model.CompanionChatLog, error) {
	out := make([]model.CompanionChatLog, 0, len(s.logs))
	for index := len(s.logs) - 1; index >= 0; index-- {
		if s.logs[index].UserID == userID {
			out = append(out, s.logs[index])
		}
	}
	for left, right := 0, len(out)-1; left < right; left, right = left+1, right-1 {
		out[left], out[right] = out[right], out[left]
	}
	if limit > 0 && len(out) > limit {
		out = out[len(out)-limit:]
	}
	return out, nil
}

func (s *fakeStore) CreateRelationshipEvent(_ context.Context, event *model.CompanionRelationshipEvent) error {
	event.ID = uint(len(s.relationshipEvents) + 1)
	s.relationshipEvents = append(s.relationshipEvents, *event)
	return nil
}

func (s *fakeStore) ListRelationshipEvents(
	_ context.Context,
	userID uint,
	limit int,
) ([]model.CompanionRelationshipEvent, error) {
	out := make([]model.CompanionRelationshipEvent, 0, len(s.relationshipEvents))
	for index := len(s.relationshipEvents) - 1; index >= 0; index-- {
		event := s.relationshipEvents[index]
		if event.UserID == userID {
			out = append(out, event)
		}
	}
	if limit > 0 && len(out) > limit {
		out = out[:limit]
	}
	return out, nil
}

func (s *fakeStore) CreateCompanionEvent(_ context.Context, event *model.CompanionEvent) error {
	for _, existing := range s.companionEvents {
		if existing.DedupeKey == event.DedupeKey {
			return nil
		}
	}
	event.ID = uint(len(s.companionEvents) + 1)
	s.companionEvents = append(s.companionEvents, *event)
	return nil
}

func (s *fakeStore) ListCompanionEvents(
	_ context.Context,
	userID uint,
	limit int,
) ([]model.CompanionEvent, error) {
	out := make([]model.CompanionEvent, 0, len(s.companionEvents))
	for index := len(s.companionEvents) - 1; index >= 0; index-- {
		event := s.companionEvents[index]
		if event.UserID == userID {
			out = append(out, event)
		}
	}
	if limit > 0 && len(out) > limit {
		out = out[:limit]
	}
	return out, nil
}

type fakeLifeStore struct {
	entities []model.LifeEntity
	events   []model.LifeEventLog
}

func (s *fakeLifeStore) ListEntities(_ context.Context, worldID string) ([]model.LifeEntity, error) {
	out := make([]model.LifeEntity, 0, len(s.entities))
	for _, e := range s.entities {
		if e.IsAlive {
			out = append(out, e)
		}
	}
	return out, nil
}

func (s *fakeLifeStore) GetEntityByID(_ context.Context, entityID uint) (*model.LifeEntity, error) {
	for i := range s.entities {
		if s.entities[i].ID == entityID {
			cp := s.entities[i]
			return &cp, nil
		}
	}
	return nil, nil
}

func (s *fakeLifeStore) ListRecentEventLogsByEntity(
	_ context.Context,
	worldID string,
	entityID uint,
	limit int,
) ([]model.LifeEventLog, error) {
	out := make([]model.LifeEventLog, 0, len(s.events))
	for _, e := range s.events {
		if e.EntityID == entityID {
			out = append(out, e)
		}
	}
	if limit > 0 && len(out) > limit {
		out = out[:limit]
	}
	return out, nil
}
