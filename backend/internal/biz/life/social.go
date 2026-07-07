package lifebiz

import (
	"fmt"
	"math"
	"math/rand"
	"time"

	"backend/model"
)

const (
	RelFriend = "friend"
	RelRival  = "rival"
	RelMate   = "mate"
)

const socialNeighborCellSize = 160.0

type SocialSystem struct{}

func NewSocialSystem() *SocialSystem { return &SocialSystem{} }

func entityDistance(a, b *model.LifeEntity) float64 {
	dx := a.PositionX - b.PositionX
	dy := a.PositionY - b.PositionY
	return math.Sqrt(dx*dx + dy*dy)
}

func relKey(entityID, targetID uint) (uint, uint) {
	if entityID < targetID {
		return entityID, targetID
	}
	return targetID, entityID
}

type socialBucket struct {
	x int
	y int
}

func bucketForEntity(entity *model.LifeEntity) socialBucket {
	return socialBucket{
		x: int(entity.PositionX / socialNeighborCellSize),
		y: int(entity.PositionY / socialNeighborCellSize),
	}
}

func relationMapKey(a, b uint) string {
	return fmt.Sprintf("%d_%d", a, b)
}

func (s *SocialSystem) UpdateRelationships(
	worldID string,
	entities map[uint]*model.LifeEntity,
	existingRels []*model.LifeRelationship,
) (newRels []*model.LifeRelationship, updatedRels []*model.LifeRelationship, deletedRelIDs []uint, events []*model.LifeEventLog) {
	now := time.Now()

	relMap := make(map[string]*model.LifeRelationship, len(existingRels))
	for _, r := range existingRels {
		a, b := relKey(r.EntityID, r.TargetID)
		relMap[relationMapKey(a, b)] = r
	}

	entityIDs := make([]uint, 0, len(entities))
	entityBucket := make(map[uint]socialBucket, len(entities))
	bucketMembers := make(map[socialBucket][]uint)
	for id, entity := range entities {
		if entity == nil {
			continue
		}
		entityIDs = append(entityIDs, id)
		bucket := bucketForEntity(entity)
		entityBucket[id] = bucket
		bucketMembers[bucket] = append(bucketMembers[bucket], id)
	}

	visitedPairs := make(map[string]struct{}, len(entityIDs)*2)

	for _, idA := range entityIDs {
		eA := entities[idA]
		if eA == nil {
			continue
		}
		bucket := entityBucket[idA]
		for dx := -1; dx <= 1; dx++ {
			for dy := -1; dy <= 1; dy++ {
				neighborBucket := socialBucket{x: bucket.x + dx, y: bucket.y + dy}
				for _, idB := range bucketMembers[neighborBucket] {
					if idA >= idB {
						continue
					}
					eB := entities[idB]
					if eB == nil {
						continue
					}

					a, b := relKey(idA, idB)
					key := relationMapKey(a, b)
					if _, seen := visitedPairs[key]; seen {
						continue
					}
					visitedPairs[key] = struct{}{}

					dist := entityDistance(eA, eB)
					existing, hasRel := relMap[key]

					if hasRel {
						rel := *existing
						changed := false

						switch rel.RelationType {
						case RelFriend:
							if dist < 100 {
								rel.Affinity = clamp(rel.Affinity+0.5, 0, 100)
								changed = true
							}
							if rel.Affinity > 50 {
								bothMature := (eA.GrowthStage == StageAdolescent || eA.GrowthStage == StageAdult) &&
									(eB.GrowthStage == StageAdolescent || eB.GrowthStage == StageAdult)
								if bothMature && rand.Float64() < 0.01 {
									rel.RelationType = RelMate
									changed = true
									events = append(events, &model.LifeEventLog{
										WorldID:     worldID,
										EntityID:    eA.ID,
										EntityType:  eA.Name,
										EventType:   "mate_formed",
										Description: fmt.Sprintf("%s和%s结为伴侣", eA.Name, eB.Name),
										PositionX:   eA.PositionX,
										PositionY:   eA.PositionY,
										CreatedAt:   now,
									})
								}
							}
						case RelRival:
							if dist < 80 {
								rel.Affinity = clamp(rel.Affinity+0.3, 0, 100)
								changed = true
							}
						case RelMate:
							if dist < 120 {
								rel.Affinity = clamp(rel.Affinity+0.2, 0, 100)
								changed = true
							}
						}

						if changed {
							rel.LastInteractionAt = now
							rel.UpdatedAt = now
							updatedRels = append(updatedRels, &rel)
							relMap[key] = &rel
						}
						continue
					}

					if dist < 100 {
						chance := 0.02
						if eA.GrowthStage != eB.GrowthStage {
							chance *= 0.5
						}
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
							events = append(events, &model.LifeEventLog{
								WorldID:     worldID,
								EntityID:    eA.ID,
								EntityType:  eA.Name,
								EventType:   "friend_made",
								Description: fmt.Sprintf("%s和%s成为了朋友", eA.Name, eB.Name),
								PositionX:   eA.PositionX,
								PositionY:   eA.PositionY,
								CreatedAt:   now,
							})
							continue
						}
					}

					if dist < 50 &&
						eA.CurrentAction == string(ActionSeekingFood) &&
						eB.CurrentAction == string(ActionSeekingFood) &&
						rand.Float64() < 0.03 {
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
						events = append(events, &model.LifeEventLog{
							WorldID:     worldID,
							EntityID:    eA.ID,
							EntityType:  eA.Name,
							EventType:   "rival_formed",
							Description: fmt.Sprintf("%s和%s因争夺资源产生竞争", eA.Name, eB.Name),
							PositionX:   eA.PositionX,
							PositionY:   eA.PositionY,
							CreatedAt:   now,
						})
					}
				}
			}
		}
	}

	deletedSet := make(map[uint]struct{})
	for _, r := range existingRels {
		_, aExists := entities[r.EntityID]
		_, bExists := entities[r.TargetID]
		if !aExists || !bExists {
			deletedSet[r.ID] = struct{}{}
			continue
		}

		a, b := relKey(r.EntityID, r.TargetID)
		key := relationMapKey(a, b)
		if _, seen := visitedPairs[key]; seen {
			continue
		}

		rel := *r
		changed := false
		switch rel.RelationType {
		case RelFriend:
			rel.Affinity = clamp(rel.Affinity-0.3, 0, 100)
			changed = true
		case RelMate:
			rel.Affinity = clamp(rel.Affinity-0.15, 0, 100)
			changed = true
		}

		if rel.Affinity <= 0 {
			deletedSet[r.ID] = struct{}{}
			events = append(events, &model.LifeEventLog{
				WorldID:     worldID,
				EntityID:    r.EntityID,
				EntityType:  "",
				EventType:   "relation_dissolved",
				Description: "一段关系因疏远而消散",
				CreatedAt:   now,
			})
			continue
		}

		if changed {
			rel.LastInteractionAt = now
			rel.UpdatedAt = now
			updatedRels = append(updatedRels, &rel)
			relMap[key] = &rel
		}
	}

	deletedRelIDs = make([]uint, 0, len(deletedSet))
	for id := range deletedSet {
		deletedRelIDs = append(deletedRelIDs, id)
	}

	return newRels, updatedRels, deletedRelIDs, events
}

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

func HasMateRelationship(entity *model.LifeEntity, rels []*model.LifeRelationship) bool {
	for _, r := range rels {
		if r.RelationType == RelMate && (r.EntityID == entity.ID || r.TargetID == entity.ID) {
			return true
		}
	}
	return false
}
