package gamebiz

import (
	"context"

	"backend/model"

	"gorm.io/gorm"
)

// Store 文字游戏持久化。
type Store interface {
	Raw() *gorm.DB
	WithContext(ctx context.Context) Store

	CountSeedScenes(ctx context.Context) (int64, error)
	CreateScene(ctx context.Context, row *model.GameScene) error
	CreateNpc(ctx context.Context, row *model.GameNpc) error

	FindSeedSceneByName(ctx context.Context, name string) (model.GameScene, bool, error)
	FindSceneByName(ctx context.Context, name string) (model.GameScene, bool, error)
	ListNpcsByScene(ctx context.Context, sceneID uint) ([]model.GameNpc, error)

	FindActiveSession(ctx context.Context, userID uint) (model.GameSession, bool, error)
	GetSession(ctx context.Context, userID, sessionID uint) (model.GameSession, error)
	DeactivateSessions(ctx context.Context, userID uint) error
	CreateSession(ctx context.Context, row *model.GameSession) error
	UpdateSession(ctx context.Context, sessionID uint, updates map[string]interface{}) error

	GetScene(ctx context.Context, sceneID uint) (model.GameScene, error)

	ListNpcMemories(ctx context.Context, playerID, npcID uint, limit int) ([]model.GameNpcMemory, error)
	CreateNpcMemory(ctx context.Context, row *model.GameNpcMemory) error

	CreateTurnLog(ctx context.Context, row *model.GameTurnLog) error
	ListTurnLogs(ctx context.Context, sessionID uint, limit int) ([]model.GameTurnLog, error)
	ListRecentTurnLogs(ctx context.Context, sessionID uint, limit int) ([]model.GameTurnLog, error)

	CreateWorldItem(ctx context.Context, row *model.GameWorldItem) error
	ListInventoryItems(ctx context.Context, sessionID uint) ([]model.GameWorldItem, error)
	ListSceneItems(ctx context.Context, sessionID, sceneID uint) ([]model.GameWorldItem, error)
	FindWorldItemByName(ctx context.Context, sessionID uint, sceneID uint, name string, inInventory bool) (model.GameWorldItem, bool, error)
	MoveItemToInventory(ctx context.Context, itemID uint) error
}
