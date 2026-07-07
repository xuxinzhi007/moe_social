package lifebiz

import (
	"fmt"
	"math"
	"math/rand"
	"time"

	"backend/model"
)

// 关系类型常量
const (
	RelFriend = "friend"
	RelRival  = "rival"
	RelMate   = "mate"
)

// SocialSystem 管理实体间的社交关系
type SocialSystem struct{}

// NewSocialSystem 创建社交关系系统
func NewSocialSystem() *SocialSystem { return &SocialSystem{} }

// entityDistance 计算两个实体之间的欧氏距离
func entityDistance(a, b *model.LifeEntity) float64 {
	dx := a.PositionX - b.PositionX
	dy := a.PositionY - b.PositionY
	return math.Sqrt(dx*dx + dy*dy)
}

// relKey 生成实体对的唯一键（小 ID 在前，保证双向一致）
func relKey(entityID, targetID uint) (uint, uint) {
	if entityID < targetID {
		return entityID, targetID
	}
	return targetID, entityID
}

// UpdateRelationships 每 tick 更新社交关系
// 参数：worldID 世界ID，entities 当前存活实体 map，existingRels 现有关系列表
// 返回：新增/更新的关系、删除的关系ID、产生的事件
func (s *SocialSystem) UpdateRelationships(
	worldID string,
	entities map[uint]*model.LifeEntity,
	existingRels []*model.LifeRelationship,
) (newRels []*model.LifeRelationship, updatedRels []*model.LifeRelationship, deletedRelIDs []uint, events []*model.LifeEventLog) {
	now := time.Now()

	// 构建现有关系索引（使用规范化键）
	relMap := make(map[string]*model.LifeRelationship, len(existingRels))
	for _, r := range existingRels {
		a, b := relKey(r.EntityID, r.TargetID)
		key := fmt.Sprintf("%d_%d", a, b)
		relMap[key] = r
	}

	// 收集实体 ID 列表，保证遍历顺序确定
	entityIDs := make([]uint, 0, len(entities))
	for id := range entities {
		entityIDs = append(entityIDs, id)
	}

	// 1. 关系形成：遍历所有实体对
	for i := 0; i < len(entityIDs); i++ {
		for j := i + 1; j < len(entityIDs); j++ {
			idA := entityIDs[i]
			idB := entityIDs[j]
			eA := entities[idA]
			eB := entities[idB]
			if eA == nil || eB == nil {
				continue
			}

			dist := entityDistance(eA, eB)
			a, b := relKey(idA, idB)
			key := fmt.Sprintf("%d_%d", a, b)
			existing, hasRel := relMap[key]

			if hasRel {
				// 已有关系 → 更新亲密度
				rel := *existing // 拷贝避免并发问题
				changed := false

				switch rel.RelationType {
				case RelFriend:
					if dist < 100 {
						rel.Affinity = clamp(rel.Affinity+0.5, 0, 100)
						changed = true
					} else if dist > 200 {
						rel.Affinity = clamp(rel.Affinity-0.3, 0, 100)
						changed = true
					}
					// 关系升级：friend → mate
					if rel.Affinity > 50 {
						bothMature := (eA.GrowthStage == StageAdolescent || eA.GrowthStage == StageAdult) &&
							(eB.GrowthStage == StageAdolescent || eB.GrowthStage == StageAdult)
						if bothMature && rand.Float64() < 0.01 {
							rel.RelationType = RelMate
							changed = true
							evt := &model.LifeEventLog{
								WorldID:     worldID,
								EntityID:    eA.ID,
								EntityType:  eA.Name,
								EventType:   "mate_formed",
								Description: fmt.Sprintf("%s和%s结为了伴侣！💕", eA.Name, eB.Name),
								PositionX:   eA.PositionX,
								PositionY:   eA.PositionY,
								CreatedAt:   now,
							}
							events = append(events, evt)
						}
					}
				case RelRival:
					if dist < 80 {
						rel.Affinity = clamp(rel.Affinity+0.3, 0, 100)
						changed = true
					}
				case RelMate:
					rel.Affinity = clamp(rel.Affinity+0.2, 0, 100)
					changed = true
				}

				if changed {
					rel.LastInteractionAt = now
					rel.UpdatedAt = now
				}

				// 亲密度耗尽 → 解除关系
				if rel.Affinity <= 0 {
					deletedRelIDs = append(deletedRelIDs, rel.ID)
					delete(relMap, key)
					evt := &model.LifeEventLog{
						WorldID:     worldID,
						EntityID:    eA.ID,
						EntityType:  eA.Name,
						EventType:   "relation_dissolved",
						Description: fmt.Sprintf("%s和%s的关系破裂了…", eA.Name, eB.Name),
						PositionX:   eA.PositionX,
						PositionY:   eA.PositionY,
						CreatedAt:   now,
					}
					events = append(events, evt)
				} else if changed {
					updatedRels = append(updatedRels, &rel)
					relMap[key] = &rel
				}
				continue
			}

			// 没有关系 → 尝试建立新关系
			// friend 关系：距离 < 100
			if dist < 100 {
				chance := 0.02
				// 不同成长阶段概率减半
				if eA.GrowthStage != eB.GrowthStage {
					chance *= 0.5
				}
				// juvenile 更容易建立关系
				if eA.GrowthStage == StageJuvenile || eB.GrowthStage == StageJuvenile {
					chance *= 1.5
				}
				if rand.Float64() < chance {
					rel := &model.LifeRelationship{
						WorldID:           worldID,
						EntityID:          a,
						TargetID:          b,
						RelationType:      RelFriend,
						Affinity:          10,
						LastInteractionAt: now,
						CreatedAt:         now,
						UpdatedAt:         now,
					}
					newRels = append(newRels, rel)
					relMap[key] = rel
					evt := &model.LifeEventLog{
						WorldID:     worldID,
						EntityID:    eA.ID,
						EntityType:  eA.Name,
						EventType:   "friend_made",
						Description: fmt.Sprintf("%s和%s成为了朋友！🤝", eA.Name, eB.Name),
						PositionX:   eA.PositionX,
						PositionY:   eA.PositionY,
						CreatedAt:   now,
					}
					events = append(events, evt)
					continue
				}
			}

			// rival 关系：距离 < 50 且都在 seeking_food
			if dist < 50 &&
				eA.CurrentAction == string(ActionSeekingFood) &&
				eB.CurrentAction == string(ActionSeekingFood) {
				if rand.Float64() < 0.03 {
					rel := &model.LifeRelationship{
						WorldID:           worldID,
						EntityID:          a,
						TargetID:          b,
						RelationType:      RelRival,
						Affinity:          20,
						LastInteractionAt: now,
						CreatedAt:         now,
						UpdatedAt:         now,
					}
					newRels = append(newRels, rel)
					relMap[key] = rel
					evt := &model.LifeEventLog{
						WorldID:     worldID,
						EntityID:    eA.ID,
						EntityType:  eA.Name,
						EventType:   "rival_formed",
						Description: fmt.Sprintf("%s和%s因为争夺食物产生了竞争！⚡", eA.Name, eB.Name),
						PositionX:   eA.PositionX,
						PositionY:   eA.PositionY,
						CreatedAt:   now,
					}
					events = append(events, evt)
				}
			}
		}
	}

	// 清理死亡实体的关系（实体已不在 entities map 中）
	for _, r := range existingRels {
		_, aExists := entities[r.EntityID]
		_, bExists := entities[r.TargetID]
		if !aExists || !bExists {
			// 避免重复添加
			found := false
			for _, id := range deletedRelIDs {
				if id == r.ID {
					found = true
					break
				}
			}
			if !found {
				deletedRelIDs = append(deletedRelIDs, r.ID)
			}
		}
	}

	return newRels, updatedRels, deletedRelIDs, events
}

// FindNearbyFriend 查找附近的朋友/伴侣（用于行为决策）
// 返回最近的 friend/mate 实体 ID 和距离，如果没有则返回 0, +Inf
func FindNearbyFriend(entity *model.LifeEntity, entities map[uint]*model.LifeEntity, rels []*model.LifeRelationship) (uint, float64) {
	bestID := uint(0)
	bestDist := math.MaxFloat64
	for _, r := range rels {
		if r.RelationType != RelFriend && r.RelationType != RelMate {
			continue
		}
		var otherID uint
		if r.EntityID == entity.ID {
			otherID = r.TargetID
		} else if r.TargetID == entity.ID {
			otherID = r.EntityID
		} else {
			continue
		}
		other, ok := entities[otherID]
		if !ok || other == nil {
			continue
		}
		dist := entityDistance(entity, other)
		if dist < bestDist {
			bestDist = dist
			bestID = otherID
		}
	}
	return bestID, bestDist
}

// FindNearbyRival 查找附近的对手（用于行为决策）
// 返回最近的 rival 实体 ID 和距离
func FindNearbyRival(entity *model.LifeEntity, entities map[uint]*model.LifeEntity, rels []*model.LifeRelationship) (uint, float64) {
	bestID := uint(0)
	bestDist := math.MaxFloat64
	for _, r := range rels {
		if r.RelationType != RelRival {
			continue
		}
		var otherID uint
		if r.EntityID == entity.ID {
			otherID = r.TargetID
		} else if r.TargetID == entity.ID {
			otherID = r.EntityID
		} else {
			continue
		}
		other, ok := entities[otherID]
		if !ok || other == nil {
			continue
		}
		dist := entityDistance(entity, other)
		if dist < bestDist {
			bestDist = dist
			bestID = otherID
		}
	}
	return bestID, bestDist
}

// HasMateRelationship 检查实体是否有 mate 关系（用于繁殖加成）
func HasMateRelationship(entity *model.LifeEntity, rels []*model.LifeRelationship) bool {
	for _, r := range rels {
		if r.RelationType == RelMate && (r.EntityID == entity.ID || r.TargetID == entity.ID) {
			return true
		}
	}
	return false
}
