package companionbiz

import (
	"context"
	"errors"
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

func TestDeadLifeBindingCanBeReplaced(t *testing.T) {
	store := newFakeStore()
	store.profiles[7] = profileToModel(7, &Profile{LifeEntityID: 2, Name: "Old"})
	life := &fakeLifeStore{entities: []model.LifeEntity{{ID: 3, Name: "Three", Emoji: "3", IsAlive: true}}}
	engine := NewEngine(store, life, llminference.Config{}, "")

	stale, err := engine.GetProfile(context.Background(), 7)
	if err != nil {
		t.Fatalf("GetProfile() stale binding error = %v", err)
	}
	if stale.LifeEntityID != 0 {
		t.Fatalf("GetProfile() stale binding = %d, want 0", stale.LifeEntityID)
	}

	rebound, err := engine.UpsertProfile(context.Background(), 7, &Profile{LifeEntityID: 3})
	if err != nil {
		t.Fatalf("UpsertProfile() rebound error = %v", err)
	}
	if rebound.LifeEntityID != 3 {
		t.Fatalf("UpsertProfile() binding = %d, want 3", rebound.LifeEntityID)
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

	if err := engine.DeleteMemory(context.Background(), 7, 1); err != nil {
		t.Fatalf("DeleteMemory: %v", err)
	}
	if err := engine.DeleteMemory(context.Background(), 7, 1); !errors.Is(err, ErrMemoryNotFound) {
		t.Fatalf("second delete err = %v, want ErrMemoryNotFound", err)
	}
}

type fakeStore struct {
	profiles map[uint]*model.CompanionProfile
	memories []model.CompanionMemory
	logs     []model.CompanionChatLog
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

func (s *fakeStore) CleanupExpiredMemories(_ context.Context) (int64, error) {
	return 0, nil
}

func (s *fakeStore) AppendChatLog(_ context.Context, chatLog *model.CompanionChatLog) error {
	s.logs = append(s.logs, *chatLog)
	return nil
}

func (s *fakeStore) ListRecentChatLogs(_ context.Context, userID uint, limit int) ([]model.CompanionChatLog, error) {
	return nil, nil
}

type fakeLifeStore struct {
	entities []model.LifeEntity
	events   []model.LifeEventLog
}

func (s *fakeLifeStore) ListEntities(_ context.Context, worldID string) ([]model.LifeEntity, error) {
	return append([]model.LifeEntity(nil), s.entities...), nil
}

func (s *fakeLifeStore) ListRecentEventLogsByEntity(
	_ context.Context,
	worldID string,
	entityID uint,
	limit int,
) ([]model.LifeEventLog, error) {
	return append([]model.LifeEventLog(nil), s.events...), nil
}
