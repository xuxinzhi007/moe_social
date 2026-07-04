package gamebiz

import (
	"context"
	"time"

	"backend/model"

	"gorm.io/gorm"
)

// TurnLogSummary 回合摘要 DTO，用于减少历史查询数据传输量。
type TurnLogSummary struct {
	ID              uint
	SessionID       uint
	UserAction      string
	NarrativePrefix string // system_narrative 前 500 字符
	CreatedAt       time.Time
}

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
	BatchListNpcMemories(ctx context.Context, playerID uint, npcIDs []uint, limitPerNpc int) ([]model.GameNpcMemory, error)
	CreateNpcMemory(ctx context.Context, row *model.GameNpcMemory) error

	CreateTurnLog(ctx context.Context, row *model.GameTurnLog) error
	ListTurnLogs(ctx context.Context, sessionID uint, limit int) ([]model.GameTurnLog, error)
	ListRecentTurnLogs(ctx context.Context, sessionID uint, limit int) ([]model.GameTurnLog, error)
	ListRecentTurnLogSummaries(ctx context.Context, sessionID uint, limit int) ([]TurnLogSummary, error)

	CreateWorldItem(ctx context.Context, row *model.GameWorldItem) error
	ListInventoryItems(ctx context.Context, sessionID uint) ([]model.GameWorldItem, error)
	ListSceneItems(ctx context.Context, sessionID, sceneID uint) ([]model.GameWorldItem, error)
	FindWorldItemByName(ctx context.Context, sessionID uint, sceneID uint, name string, inInventory bool) (model.GameWorldItem, bool, error)
	MoveItemToInventory(ctx context.Context, itemID uint) error

	// NPC 模板相关
	ListNpcTemplates(ctx context.Context, activeOnly bool) ([]model.GameNpcTemplate, error)
	FindNpcTemplateByKey(ctx context.Context, npcKey string) (*model.GameNpcTemplate, error)
	FindNpcTemplateByName(ctx context.Context, displayName string) (*model.GameNpcTemplate, error)
	UpsertNpcTemplate(ctx context.Context, tpl *model.GameNpcTemplate) error

	// 存档相关
	ListSaveSlots(ctx context.Context, userID uint) ([]model.GameSaveSlot, error)
	SaveGame(ctx context.Context, slot *model.GameSaveSlot) error
	DeleteSaveSlot(ctx context.Context, userID uint, slotIndex uint8) error

	// 条件对话模板
	FindMatchingDialogueTemplates(ctx context.Context, npcKey string, limit int) ([]model.GameDialogueTemplate, error)

	// 故事线配置
	ListActiveStoryArcs(ctx context.Context) ([]model.GameStoryArc, error)

	// WorldState 独立字段表（双写架构）
	UpsertWorldState(ctx context.Context, row *model.GameWorldState) error
	GetWorldState(ctx context.Context, sessionID uint) (*model.GameWorldState, error)
	UpsertDiscoveredItem(ctx context.Context, row *model.GameDiscoveredItem) error
	ListDiscoveredItems(ctx context.Context, sessionID uint) ([]model.GameDiscoveredItem, error)
	UpsertVisitedScene(ctx context.Context, row *model.GameVisitedScene) error
	ListVisitedScenes(ctx context.Context, sessionID uint) ([]model.GameVisitedScene, error)
	UpsertNpcActivity(ctx context.Context, row *model.GameNpcActivity) error
	ListNpcActivities(ctx context.Context, sessionID uint) ([]model.GameNpcActivity, error)

	// Agent 运行时（NPC-Agent 绑定）
	FindAgentRuntime(ctx context.Context, agentRuntimeID uint) (*model.MoeAgentRuntime, error)

	// 世界事件（开放世界自主运转）
	CreateWorldEvent(ctx context.Context, row *model.GameWorldEvent) error
	ListUndeliveredWorldEvents(ctx context.Context, sessionID uint, limit int) ([]model.GameWorldEvent, error)
	ListRecentWorldEvents(ctx context.Context, sessionID uint, limit int) ([]model.GameWorldEvent, error)
	MarkWorldEventsDelivered(ctx context.Context, ids []uint) error
	ListActiveSessions(ctx context.Context, limit int) ([]model.GameSession, error)
}
