package lifebiz

import (
	"context"
	"testing"

	"backend/model"
)

// mockStore 实现 Store 接口的所有方法（返回 nil/空）
type mockStore struct{}

func (m *mockStore) ListEntities(_ context.Context, _ string) ([]model.LifeEntity, error) {
	return nil, nil
}
func (m *mockStore) UpsertEntity(_ context.Context, _ *model.LifeEntity) error { return nil }
func (m *mockStore) BatchUpsertEntities(_ context.Context, _ []*model.LifeEntity) error {
	return nil
}
func (m *mockStore) SoftDeleteEntity(_ context.Context, _ uint) error { return nil }
func (m *mockStore) GetWorld(_ context.Context, _ string) (*model.LifeWorld, error) {
	return nil, nil
}
func (m *mockStore) UpsertWorld(_ context.Context, _ *model.LifeWorld) error { return nil }
func (m *mockStore) UpdateWorldGridData(_ context.Context, _ string, _ string) error {
	return nil
}
func (m *mockStore) CreateEventLog(_ context.Context, _ *model.LifeEventLog) error { return nil }
func (m *mockStore) BatchCreateEventLogs(_ context.Context, _ []*model.LifeEventLog) error {
	return nil
}
func (m *mockStore) ListRecentEventLogs(_ context.Context, _ string, _ int) ([]model.LifeEventLog, error) {
	return nil, nil
}
func (m *mockStore) CleanupOldEventLogs(_ context.Context) (int64, error) { return 0, nil }
func (m *mockStore) UpsertRelationship(_ context.Context, _ *model.LifeRelationship) error {
	return nil
}
func (m *mockStore) BatchUpsertRelationships(_ context.Context, _ []*model.LifeRelationship) error {
	return nil
}
func (m *mockStore) ListRelationshipsByWorld(_ context.Context, _ string) ([]*model.LifeRelationship, error) {
	return nil, nil
}
func (m *mockStore) ListRelationshipsByEntity(_ context.Context, _ uint) ([]*model.LifeRelationship, error) {
	return nil, nil
}
func (m *mockStore) DeleteRelationship(_ context.Context, _ uint) error { return nil }
func (m *mockStore) BatchDeleteRelationships(_ context.Context, _ []uint) error {
	return nil
}
func (m *mockStore) ListItems(_ context.Context) ([]*model.LifeItem, error) { return nil, nil }
func (m *mockStore) GetItem(_ context.Context, _ uint) (*model.LifeItem, error) {
	return nil, nil
}
func (m *mockStore) SeedItems(_ context.Context, _ []*model.LifeItem) error { return nil }
func (m *mockStore) GetInventory(_ context.Context, _ string) ([]*model.LifeInventory, error) {
	return nil, nil
}
func (m *mockStore) DecrementInventory(_ context.Context, _ string, _ uint) error { return nil }
func (m *mockStore) GrantItem(_ context.Context, _ string, _ uint, _ int) error { return nil }

// 确保 mockStore 实现了 Store 接口
var _ Store = (*mockStore)(nil)

func TestEnqueueEntity(t *testing.T) {
	pw := NewPersistenceWriter(&mockStore{}, DefaultConfig())
	e := &model.LifeEntity{ID: 1, Name: "test", Hunger: 80}
	pw.EnqueueEntity(e)

	// 检查 channel 有一条数据
	if len(pw.entityCh) != 1 {
		t.Errorf("entityCh len=%d, want 1", len(pw.entityCh))
	}
	got := <-pw.entityCh
	if got.ID != 1 || got.Name != "test" {
		t.Errorf("dequeued entity mismatch: %+v", got)
	}
}

func TestEnqueueEvent(t *testing.T) {
	pw := NewPersistenceWriter(&mockStore{}, DefaultConfig())
	evt := &model.LifeEventLog{EntityID: 42, EventType: "eating"}
	pw.EnqueueEvent(evt)

	if len(pw.eventCh) != 1 {
		t.Errorf("eventCh len=%d, want 1", len(pw.eventCh))
	}
	got := <-pw.eventCh
	if got.EntityID != 42 || got.EventType != "eating" {
		t.Errorf("dequeued event mismatch: %+v", got)
	}
}

func TestEnqueueDeleteEntity(t *testing.T) {
	pw := NewPersistenceWriter(&mockStore{}, DefaultConfig())
	pw.EnqueueDeleteEntity(99)

	if len(pw.deleteCh) != 1 {
		t.Errorf("deleteCh len=%d, want 1", len(pw.deleteCh))
	}
	got := <-pw.deleteCh
	if got != 99 {
		t.Errorf("dequeued delete id=%d, want 99", got)
	}
}

func TestChannelFull(t *testing.T) {
	// 创建 capacity=1 的 channel 模拟满的情况
	pw := NewPersistenceWriter(&mockStore{}, DefaultConfig())

	// 填满 entityCh（容量 entityChanSize=1000）
	// 直接填满
	for i := 0; i < entityChanSize; i++ {
		pw.entityCh <- &model.LifeEntity{ID: uint(i)}
	}

	// 再入队一条，应走 default 分支（丢弃），不阻塞
	pw.EnqueueEntity(&model.LifeEntity{ID: 9999})
	// 不 panic 不阻塞就通过

	// 填满 eventCh
	for i := 0; i < eventChanSize; i++ {
		pw.eventCh <- &model.LifeEventLog{EntityID: uint(i)}
	}
	pw.EnqueueEvent(&model.LifeEventLog{EntityID: 9999})

	// 填满 deleteCh
	for i := 0; i < deleteChanSize; i++ {
		pw.deleteCh <- uint(i)
	}
	pw.EnqueueDeleteEntity(9999)
}
