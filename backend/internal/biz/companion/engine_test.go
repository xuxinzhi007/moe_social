package companionbiz

import (
	"context"
	"errors"
	"testing"

	"backend/model"
	"backend/pkg/llminference"
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

func TestUpsertProfileRejectsMissingLifeBinding(t *testing.T) {
	engine := NewEngine(
		newFakeStore(),
		&fakeLifeStore{entities: []model.LifeEntity{{ID: 2, IsAlive: true}}},
		llminference.Config{},
		"",
	)

	_, err := engine.UpsertProfile(context.Background(), 7, &Profile{LifeEntityID: 99})
	if !errors.Is(err, ErrLifeEntityNotFound) {
		t.Fatalf("UpsertProfile() error = %v, want ErrLifeEntityNotFound", err)
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

func TestGetProfileBindsWhenLifeEntityAppearsLater(t *testing.T) {
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
	if bound.LifeEntityID != 3 {
		t.Fatalf("GetProfile() binding = %d, want 3", bound.LifeEntityID)
	}
	if store.profiles[7].LifeEntityID != 3 {
		t.Fatalf("persisted binding = %d, want 3", store.profiles[7].LifeEntityID)
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
	if stale.LifeEntityID != 2 {
		t.Fatalf("GetProfile() stale binding = %d, want 2", stale.LifeEntityID)
	}

	rebound, err := engine.UpsertProfile(context.Background(), 7, &Profile{LifeEntityID: 3})
	if err != nil {
		t.Fatalf("UpsertProfile() rebound error = %v", err)
	}
	if rebound.LifeEntityID != 3 {
		t.Fatalf("UpsertProfile() binding = %d, want 3", rebound.LifeEntityID)
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

func (s *fakeStore) ListProfileUserIDs(_ context.Context) ([]uint, error) {
	userIDs := make([]uint, 0, len(s.profiles))
	for userID := range s.profiles {
		userIDs = append(userIDs, userID)
	}
	return userIDs, nil
}

func (s *fakeStore) CreateMemory(_ context.Context, memory *model.CompanionMemory) error {
	s.memories = append(s.memories, *memory)
	return nil
}

func (s *fakeStore) ListActiveMemories(_ context.Context, userID uint, limit int) ([]model.CompanionMemory, error) {
	return nil, nil
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
