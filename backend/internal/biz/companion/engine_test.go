package companionbiz

import (
	"context"
	"errors"
	"strings"
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
	if edited.Content != "其实更喜欢狗" {
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
	engine.OnProactive = func(_ uint, message, _ string) {
		messages = append(messages, message)
	}

	engine.pushProactive(7)
	engine.pushProactive(7)

	if len(messages) != 1 || !strings.Contains(messages[0], "面试") {
		t.Fatalf("messages=%v, want one interview follow-up", messages)
	}
}

type fakeStore struct {
	profiles           map[uint]*model.CompanionProfile
	memories           []model.CompanionMemory
	logs               []model.CompanionChatLog
	relationshipEvents []model.CompanionRelationshipEvent
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
	profileCopy.ID = uint(len(s.profiles) + 1)
	s.profiles[profile.UserID] = &profileCopy
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

func (s *fakeStore) UpdateMemoryContent(_ context.Context, userID, memoryID uint, content string) error {
	for i := range s.memories {
		if s.memories[i].ID == memoryID && s.memories[i].UserID == userID {
			s.memories[i].Content = content
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
