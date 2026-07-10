package lifebiz

import (
	"context"
	"time"

	"backend/internal/platform/moelog"
	"backend/model"
)

const (
	entityChanSize = 1000
	eventChanSize  = 1000
	deleteChanSize = 200
	gridChanSize   = 10
	relChanSize    = 500
	relDelChanSize = 200
)

// gridPersistRequest 生态网格持久化请求
type gridPersistRequest struct {
	worldName string
	gridData  string
}

// PersistenceWriter 异步批量写入器
type PersistenceWriter struct {
	store    Store
	entityCh chan *model.LifeEntity
	eventCh  chan *model.LifeEventLog
	deleteCh chan uint // 待软删除的实体 ID
	gridCh   chan gridPersistRequest
	relCh    chan *model.LifeRelationship // 关系 upsert
	relDelCh chan uint                    // 关系删除 ID
	config   LifeConfig
}

// NewPersistenceWriter 创建异步批量写入器
func NewPersistenceWriter(store Store, config LifeConfig) *PersistenceWriter {
	return &PersistenceWriter{
		store:    store,
		entityCh: make(chan *model.LifeEntity, entityChanSize),
		eventCh:  make(chan *model.LifeEventLog, eventChanSize),
		deleteCh: make(chan uint, deleteChanSize),
		gridCh:   make(chan gridPersistRequest, gridChanSize),
		relCh:    make(chan *model.LifeRelationship, relChanSize),
		relDelCh: make(chan uint, relDelChanSize),
		config:   config,
	}
}

// Start 启动后台 flush goroutine
func (w *PersistenceWriter) Start(ctx context.Context) {
	go func() {
		defer func() {
			if r := recover(); r != nil {
				moelog.Errorf("life: PersistenceWriter panic: %v", r)
			}
		}()
		ticker := time.NewTicker(w.config.FlushInterval)
		defer ticker.Stop()
		cleanupTicker := time.NewTicker(6 * time.Hour)
		defer cleanupTicker.Stop()
		for {
			select {
			case <-ctx.Done():
				// 使用独立 context，避免已取消的 ctx 导致 DB 操作失败
				flushCtx, flushCancel := context.WithTimeout(context.Background(), 10*time.Second)
				w.flush(flushCtx)
				flushCancel()
				return
			case <-ticker.C:
				w.flush(ctx)
			case <-cleanupTicker.C:
				if n, err := w.store.CleanupOldEventLogs(ctx); err != nil {
					moelog.Errorf("life: cleanup old event logs: %v", err)
				} else if n > 0 {
					moelog.Infof("life: cleaned up %d old event logs (tiered)", n)
				}
			default:
				// 检查 channel 是否达到 batch size
				if len(w.entityCh) >= w.config.FlushBatchSize {
					w.flush(ctx)
				}
				time.Sleep(100 * time.Millisecond) // 避免空转
			}
		}
	}()
}

// EnqueueEntity 入队实体更新（非阻塞）
func (w *PersistenceWriter) EnqueueEntity(e *model.LifeEntity) {
	select {
	case w.entityCh <- e:
	default:
		// channel 满，丢弃最旧的数据
		moelog.Warnf("life: entity persist queue full, dropping update for entity %d", e.ID)
	}
}

// EnqueueEvent 入队事件日志（非阻塞）
func (w *PersistenceWriter) EnqueueEvent(e *model.LifeEventLog) {
	select {
	case w.eventCh <- e:
	default:
		moelog.Warnf("life: event persist queue full, dropping event for entity %d", e.EntityID)
	}
}

// EnqueueDeleteEntity 入队实体软删除请求（非阻塞）
func (w *PersistenceWriter) EnqueueDeleteEntity(entityID uint) {
	select {
	case w.deleteCh <- entityID:
	default:
		moelog.Warnf("life: delete persist queue full, dropping delete for entity %d", entityID)
	}
}

// EnqueueGridPersist 入队生态网格持久化请求（非阻塞）
func (w *PersistenceWriter) EnqueueGridPersist(worldName string, gridData string) {
	select {
	case w.gridCh <- gridPersistRequest{worldName: worldName, gridData: gridData}:
	default:
		moelog.Warnf("life: grid persist queue full, dropping grid update for world %q", worldName)
	}
}

// EnqueueRelationship 入队关系 upsert（非阻塞）
func (w *PersistenceWriter) EnqueueRelationship(rel *model.LifeRelationship) {
	select {
	case w.relCh <- rel:
	default:
		moelog.Warnf("life: relationship persist queue full, dropping rel %d-%d", rel.EntityID, rel.TargetID)
	}
}

// EnqueueDeleteRelationship 入队关系删除（非阻塞）
func (w *PersistenceWriter) EnqueueDeleteRelationship(relID uint) {
	select {
	case w.relDelCh <- relID:
	default:
		moelog.Warnf("life: relationship delete queue full, dropping delete for rel %d", relID)
	}
}

func (w *PersistenceWriter) flush(ctx context.Context) {
	// drain entityCh → BatchUpsertEntities
	var entities []*model.LifeEntity
	for {
		select {
		case e := <-w.entityCh:
			entities = append(entities, e)
		default:
			goto doneEntities
		}
	}
doneEntities:
	if len(entities) > 0 {
		if err := w.store.BatchUpsertEntities(ctx, entities); err != nil {
			moelog.Errorf("life: batch upsert %d entities: %v", len(entities), err)
		}
	}

	// drain eventCh → BatchCreateEventLogs
	var events []*model.LifeEventLog
	for {
		select {
		case e := <-w.eventCh:
			events = append(events, e)
		default:
			goto doneEvents
		}
	}
doneEvents:
	if len(events) > 0 {
		if err := w.store.BatchCreateEventLogs(ctx, events); err != nil {
			moelog.Errorf("life: batch create %d event logs: %v", len(events), err)
		}
	}

	// drain deleteCh → SoftDeleteEntity（逐个执行）
	for {
		select {
		case id := <-w.deleteCh:
			if err := w.store.SoftDeleteEntity(ctx, id); err != nil {
				moelog.Errorf("life: soft delete entity %d: %v", id, err)
			}
		default:
			goto doneDeletes
		}
	}
doneDeletes:

	// drain gridCh → UpdateWorldGridData（只取最新的一条）
	var latestGrid *gridPersistRequest
	for {
		select {
		case g := <-w.gridCh:
			latestGrid = &g
		default:
			goto doneGrid
		}
	}
doneGrid:
	if latestGrid != nil {
		if err := w.store.UpdateWorldGridData(ctx, latestGrid.worldName, latestGrid.gridData); err != nil {
			moelog.Errorf("life: update world grid data for %q: %v", latestGrid.worldName, err)
		}
	}

	// drain relCh → BatchUpsertRelationships
	var rels []*model.LifeRelationship
	for {
		select {
		case r := <-w.relCh:
			rels = append(rels, r)
		default:
			goto doneRels
		}
	}
doneRels:
	if len(rels) > 0 {
		if err := w.store.BatchUpsertRelationships(ctx, rels); err != nil {
			moelog.Errorf("life: batch upsert %d relationships: %v", len(rels), err)
		}
	}

	// drain relDelCh → BatchDeleteRelationships
	var relDelIDs []uint
	for {
		select {
		case id := <-w.relDelCh:
			relDelIDs = append(relDelIDs, id)
		default:
			goto doneRelDels
		}
	}
doneRelDels:
	if len(relDelIDs) > 0 {
		if err := w.store.BatchDeleteRelationships(ctx, relDelIDs); err != nil {
			moelog.Errorf("life: batch delete %d relationships: %v", len(relDelIDs), err)
		}
	}
}
