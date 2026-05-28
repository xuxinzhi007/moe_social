package aidata

import (
	"context"
	"fmt"
	"strings"

	aibiz "backend/internal/biz/ai"
	"backend/model"

	"gorm.io/gorm"
)

type store struct {
	db *gorm.DB
}

// NewStore 构造 biz.AiStore（P4-D）。
func NewStore(db *gorm.DB) aibiz.AiStore {
	if db == nil {
		return nil
	}
	return &store{db: db}
}

func (s *store) Raw() *gorm.DB { return s.db }

func (s *store) WithContext(ctx context.Context) aibiz.AiStore {
	return &store{db: s.db.WithContext(ctx)}
}

func (s *store) LoadOrCreateConfig(ctx context.Context, userID uint) (*model.AiUserConfig, error) {
	var cfg model.AiUserConfig
	err := s.db.WithContext(ctx).Where("user_id = ?", userID).First(&cfg).Error
	if err == nil {
		return &cfg, nil
	}
	if err != gorm.ErrRecordNotFound {
		return nil, err
	}
	cfg = model.AiUserConfig{
		UserID:               userID,
		ProviderProfilesJSON: "[]",
		AgentsJSON:           "[]",
		LorebooksJSON:        "[]",
		UserPersona:          "",
		PreferencesJSON:      "{}",
	}
	if err := s.db.WithContext(ctx).Create(&cfg).Error; err != nil {
		return nil, err
	}
	return &cfg, nil
}

func (s *store) SaveConfig(ctx context.Context, cfg *model.AiUserConfig) error {
	return s.db.WithContext(ctx).Save(cfg).Error
}

func (s *store) FindAllConfigs(ctx context.Context) ([]model.AiUserConfig, error) {
	var configs []model.AiUserConfig
	err := s.db.WithContext(ctx).Find(&configs).Error
	return configs, err
}

func (s *store) GetUserDisplayName(ctx context.Context, userID uint) string {
	var user model.User
	if err := s.db.WithContext(ctx).Select("id", "username", "email", "feishu_name").First(&user, userID).Error; err != nil {
		return fmt.Sprintf("user#%d", userID)
	}
	username := strings.TrimSpace(user.Username)
	feishuName := strings.TrimSpace(user.FeishuName)
	if username != "" && feishuName != "" && username != feishuName {
		return username + "（飞书：" + feishuName + "）"
	}
	if username != "" {
		return username
	}
	if feishuName != "" {
		return feishuName
	}
	if strings.TrimSpace(user.Email) != "" {
		return user.Email
	}
	return fmt.Sprintf("user#%d", userID)
}
