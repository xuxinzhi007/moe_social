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
)

// PersistenceWriter 异步批量写入器
type PersistenceWriter struct {
	store    Store
	entityCh chan *model.LifeEntity
	eventCh  chan *model.LifeEventLog
	config   LifeConfig
}

// NewPersistenceWriter 创建异步批量写入器
func NewPersistenceWriter(store Store, config LifeConfig) *PersistenceWriter {
	return &PersistenceWriter{
		store:    store,
		entityCh: make(chan *model.LifeEntity, entityChanSize),
		eventCh:  make(chan *model.LifeEventLog, eventChanSize),
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
}
