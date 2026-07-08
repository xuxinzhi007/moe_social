package lifeapp

import (
	"context"
	"fmt"
	"math"
	"strconv"
	"strings"
	"time"

	lifev1 "backend/api/life/v1"
	lifebiz "backend/internal/biz/life"
	"backend/model"

	"github.com/go-kratos/kratos/v2/errors"
)

func (s *AppService) GetWorld(ctx context.Context, _ *lifev1.GetLifeWorldRequest) (*lifev1.GetLifeWorldReply, error) {
	engine := s.Engine()
	if engine == nil {
		return nil, errors.ServiceUnavailable("LIFE_ENGINE", "engine not ready")
	}
	snap := engine.GetWorldCache().Get(engine.GetConfig().WorldName)
	if snap == nil {
		return nil, errors.NotFound("LIFE_WORLD", "world not found")
	}
	return &lifev1.GetLifeWorldReply{
		World:        lifeWorldToProto(snap.World),
		TickCount:    snap.TickCount,
		EntityCount:  int32(len(snap.Entities)),
		Summary:      lifeSummaryToProto(snap.Summary),
	}, nil
}

func (s *AppService) ListEntities(ctx context.Context, _ *lifev1.ListLifeEntitiesRequest) (*lifev1.ListLifeEntitiesReply, error) {
	engine := s.Engine()
	if engine == nil {
		return nil, errors.ServiceUnavailable("LIFE_ENGINE", "engine not ready")
	}
	snap := engine.GetWorldCache().Get(engine.GetConfig().WorldName)
	if snap == nil {
		return &lifev1.ListLifeEntitiesReply{}, nil
	}
	items := make([]*lifev1.LifeEntity, 0, len(snap.Entities))
	for _, e := range snap.Entities {
		if e == nil {
			continue
		}
		items = append(items, lifeEntityToProto(*e))
	}
	return &lifev1.ListLifeEntitiesReply{Entities: items}, nil
}

func (s *AppService) ListEvents(ctx context.Context, in *lifev1.ListLifeEventsRequest) (*lifev1.ListLifeEventsReply, error) {
	store := s.Store()
	if store == nil {
		return nil, errors.ServiceUnavailable("LIFE_STORE", "store not ready")
	}
	limit := int(in.GetLimit())
	if limit <= 0 {
		limit = 50
	}
	if limit > 200 {
		limit = 200
	}
	logs, err := store.ListRecentEventLogs(ctx, "default", limit)
	if err != nil {
		return nil, err
	}
	items := make([]*lifev1.LifeEventLog, 0, len(logs))
	for _, row := range logs {
		items = append(items, lifeEventLogToProto(row))
	}
	return &lifev1.ListLifeEventsReply{Events: items}, nil
}

func (s *AppService) ListRelationships(ctx context.Context, in *lifev1.ListLifeRelationshipsRequest) (*lifev1.ListLifeRelationshipsReply, error) {
	engine := s.Engine()
	if engine == nil {
		return nil, errors.ServiceUnavailable("LIFE_ENGINE", "engine not ready")
	}
	worldName := strings.TrimSpace(in.GetWorld())
	if worldName == "" {
		worldName = engine.GetConfig().WorldName
	}
	if snap := engine.GetWorldCache().Get(worldName); snap != nil {
		items := make([]*lifev1.LifeRelationship, 0, len(snap.Relationships))
		for _, rel := range snap.Relationships {
			if rel == nil {
				continue
			}
			items = append(items, lifeRelationshipToProto(*rel))
		}
		return &lifev1.ListLifeRelationshipsReply{Relationships: items}, nil
	}
	store := s.Store()
	if store == nil {
		return nil, errors.ServiceUnavailable("LIFE_STORE", "store not ready")
	}
	rels, err := store.ListRelationshipsByWorld(ctx, worldName)
	if err != nil {
		return nil, err
	}
	items := make([]*lifev1.LifeRelationship, 0, len(rels))
	for _, rel := range rels {
		if rel == nil {
			continue
		}
		items = append(items, lifeRelationshipToProto(*rel))
	}
	return &lifev1.ListLifeRelationshipsReply{Relationships: items}, nil
}

func (s *AppService) ApplyAction(ctx context.Context, in *lifev1.ApplyLifeActionRequest) (*lifev1.ApplyLifeActionReply, error) {
	engine := s.Engine()
	if engine == nil {
		return nil, errors.ServiceUnavailable("LIFE_ENGINE", "engine not ready")
	}
	action := strings.TrimSpace(in.GetAction())
	if action == "" {
		return nil, errors.BadRequest("LIFE_ACTION", "action is required")
	}
	entityID := uint(in.GetEntityId())
	if entityID == 0 {
		return nil, errors.BadRequest("LIFE_ENTITY", "entity_id is required")
	}
	params := make(map[string]interface{}, len(in.GetParams()))
	for k, v := range in.GetParams() {
		params[k] = v
	}
	worldName := engine.GetConfig().WorldName
	result := engine.ApplyUserAction(worldName, entityID, action, params)
	if !result.Success {
		if strings.Contains(result.Message, "cooldown") {
			retryAfter := extractRetrySeconds(result.Message)
			return nil, errors.New(429, "LIFE_ACTION_COOLDOWN", "action in cooldown").
				WithMetadata(map[string]string{"retry_after": fmt.Sprintf("%.0f", retryAfter)})
		}
		return &lifev1.ApplyLifeActionReply{
			Success: false,
			Message: result.Message,
		}, nil
	}
	reply := &lifev1.ApplyLifeActionReply{
		Success: true,
		Message: result.Message,
	}
	if result.Entity != nil {
		reply.Entity = lifeEntityToProto(*result.Entity)
	}
	return reply, nil
}

func lifeWorldToProto(w model.LifeWorld) *lifev1.LifeWorld {
	return &lifev1.LifeWorld{
		Id:        uint64(w.ID),
		Name:      w.Name,
		TickCount: w.TickCount,
		IsRunning: w.IsRunning,
		GridData:  w.GridData,
		UpdatedAt: formatLifeTime(w.UpdatedAt),
		CreatedAt: formatLifeTime(w.CreatedAt),
	}
}

func lifeSummaryToProto(s lifebiz.WorldSummary) *lifev1.LifeWorldSummary {
	return &lifev1.LifeWorldSummary{
		EntityCount:    int32(s.EntityCount),
		AliveCount:     int32(s.AliveCount),
		BirthCount:     int32(s.BirthCount),
		DeathCount:     int32(s.DeathCount),
		AvgHunger:      s.AvgHunger,
		AvgEnergy:      s.AvgEnergy,
		AvgMood:        s.AvgMood,
		TotalFood:      s.TotalFood,
		HabitableCells: int32(s.HabitableCells),
		DangerCells:    int32(s.DangerCells),
	}
}

func lifeEntityToProto(e model.LifeEntity) *lifev1.LifeEntity {
	out := &lifev1.LifeEntity{
		Id:            uint64(e.ID),
		WorldId:       e.WorldID,
		Name:          e.Name,
		Emoji:         e.Emoji,
		Hunger:        e.Hunger,
		Energy:        e.Energy,
		Mood:          e.Mood,
		CurrentAction: e.CurrentAction,
		PositionX:     e.PositionX,
		PositionY:     e.PositionY,
		Age:           int32(e.Age),
		GrowthStage:   e.GrowthStage,
		Experience:    e.Experience,
		IsAlive:       e.IsAlive,
		LastActionAt:  formatLifeTime(e.LastActionAt),
		UpdatedAt:     formatLifeTime(e.UpdatedAt),
		CreatedAt:     formatLifeTime(e.CreatedAt),
	}
	if e.TargetEntityID != nil {
		out.TargetEntityId = uint64(*e.TargetEntityID)
	}
	return out
}

func lifeEventLogToProto(e model.LifeEventLog) *lifev1.LifeEventLog {
	return &lifev1.LifeEventLog{
		Id:          uint64(e.ID),
		WorldId:     e.WorldID,
		EntityId:    uint64(e.EntityID),
		EntityType:  e.EntityType,
		EventType:   e.EventType,
		Description: e.Description,
		PositionX:   e.PositionX,
		PositionY:   e.PositionY,
		CreatedAt:   formatLifeTime(e.CreatedAt),
	}
}

func lifeRelationshipToProto(r model.LifeRelationship) *lifev1.LifeRelationship {
	return &lifev1.LifeRelationship{
		Id:                uint64(r.ID),
		WorldId:           r.WorldID,
		EntityId:          uint64(r.EntityID),
		TargetId:          uint64(r.TargetID),
		RelationType:      r.RelationType,
		Affinity:          r.Affinity,
		LastInteractionAt: formatLifeTime(r.LastInteractionAt),
		CreatedAt:         formatLifeTime(r.CreatedAt),
		UpdatedAt:         formatLifeTime(r.UpdatedAt),
	}
}

func formatLifeTime(t time.Time) string {
	if t.IsZero() {
		return ""
	}
	return t.Format(time.RFC3339)
}

func extractRetrySeconds(msg string) float64 {
	var seconds float64
	if _, err := fmt.Sscanf(msg, "action in cooldown, retry after %f seconds", &seconds); err == nil {
		if seconds < 1 {
			return 1
		}
		return math.Ceil(seconds)
	}
	if n, err := strconv.ParseFloat(strings.TrimSpace(msg), 64); err == nil && n > 0 {
		return math.Ceil(n)
	}
	return 3
}
