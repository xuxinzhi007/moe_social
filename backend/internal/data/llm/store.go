package llmdata

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	aidata "backend/internal/data/ai"
	"backend/model"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// Store implements the managed-model ledger without depending on biz.
type Store struct{ db *gorm.DB }

func NewStore(db *gorm.DB) *Store {
	if db == nil {
		return nil
	}
	return &Store{db: db}
}
func (s *Store) Get(ctx context.Context, owner uint, agent string) (model.LLMManagedModel, error) {
	var row model.LLMManagedModel
	err := s.db.WithContext(ctx).Where("owner_id = ? AND agent_id = ?", owner, agent).First(&row).Error
	return row, err
}
func (s *Store) List(ctx context.Context, owner uint) ([]model.LLMManagedModel, error) {
	rows := []model.LLMManagedModel{}
	err := s.db.WithContext(ctx).Where("owner_id = ?", owner).Order("id ASC").Find(&rows).Error
	return rows, err
}
func (s *Store) ByName(ctx context.Context, name string) (model.LLMManagedModel, error) {
	var row model.LLMManagedModel
	err := s.db.WithContext(ctx).Where("managed_name = ?", name).First(&row).Error
	return row, err
}

// Reserve atomically loads the card, counts quota and persists a checked intent.
func (s *Store) Reserve(ctx context.Context, owner uint, agent string, mutate func(*model.LLMManagedModel, map[string]any, int64, int64) error) (model.LLMManagedModel, error) {
	aidata.ConfigWriteMu.Lock()
	defer aidata.ConfigWriteMu.Unlock()
	var row model.LLMManagedModel
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		err := tx.Where("owner_id = ? AND agent_id = ?", owner, agent).First(&row).Error
		if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}
		var cfg model.AiUserConfig
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).Where("user_id = ?", owner).First(&cfg).Error; err != nil {
			return err
		}
		var cards []map[string]any
		if err := json.Unmarshal([]byte(cfg.AgentsJSON), &cards); err != nil {
			return err
		}
		var card map[string]any
		for _, c := range cards {
			if c["id"] == agent {
				card = c
				break
			}
		}
		if card == nil {
			return gorm.ErrRecordNotFound
		}
		var userCount, globalCount int64
		occupied := tx.Model(&model.LLMManagedModel{}).Where("state <> ?", "deleted")
		if err := occupied.Count(&globalCount).Error; err != nil {
			return err
		}
		if err := tx.Model(&model.LLMManagedModel{}).Where("state <> ? AND owner_id = ?", "deleted", owner).Count(&userCount).Error; err != nil {
			return err
		}
		if err := mutate(&row, card, userCount, globalCount); err != nil {
			return err
		}
		return tx.Save(&row).Error
	})
	return row, err
}

// Finish persists the operation and conditionally binds an unchanged card in one transaction.
func (s *Store) Finish(ctx context.Context, row *model.LLMManagedModel, bind bool) error {
	aidata.ConfigWriteMu.Lock()
	defer aidata.ConfigWriteMu.Unlock()
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if bind || row.State == "deleted" {
			var cfg model.AiUserConfig
			err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).Where("user_id = ?", row.OwnerID).First(&cfg).Error
			if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
				return err
			}
			if err == nil {
				var cards []map[string]any
				if err := json.Unmarshal([]byte(cfg.AgentsJSON), &cards); err != nil {
					return err
				}
				changed := false
				for _, card := range cards {
					if card["id"] != row.AgentID {
						continue
					}
					snapshot, err := json.Marshal(card)
					if err != nil {
						return err
					}
					if bind && string(snapshot) == row.CardSnapshot {
						card["model_name"] = row.ManagedName
						row.BindingApplied = true
						changed = true
					}
					if row.State == "deleted" && card["model_name"] == row.ManagedName {
						card["model_name"] = row.BaseModel
						changed = true
						row.BindingApplied = false
					}
				}
				if changed {
					raw, err := json.Marshal(cards)
					if err != nil {
						return err
					}
					if err = tx.Model(&cfg).Update("agents_json", string(raw)).Error; err != nil {
						return err
					}
				}
			}
		}
		result := tx.Model(&model.LLMManagedModel{}).Where("id = ? AND request_id = ?", row.ID, row.RequestID).Select("*").Updates(row)
		if result.Error != nil {
			return result.Error
		}
		if result.RowsAffected != 1 {
			return fmt.Errorf("managed intent changed")
		}
		return nil
	})
}

// SaveIntent updates a previously reserved row with compare-and-swap request identity.
func (s *Store) SaveIntent(ctx context.Context, row *model.LLMManagedModel, previousRequest string) error {
	aidata.ConfigWriteMu.Lock()
	defer aidata.ConfigWriteMu.Unlock()
	result := s.db.WithContext(ctx).Model(&model.LLMManagedModel{}).Where("id = ? AND request_id = ?", row.ID, previousRequest).Select("*").Updates(row)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected != 1 {
		return fmt.Errorf("managed intent changed")
	}
	return nil
}
