// Package llmapp LLM 域应用服务。
package llmapp

import (
	"context"

	llmbiz "backend/internal/biz/llm"
	"backend/pkg/localmodels"
	"backend/pkg/llminference"
	"backend/rpc/pb/super"

	"gorm.io/gorm"
)

// Deps 进程内 LLM 服务依赖。
type Deps struct {
	Inference              llminference.Config
	MemoryModel            string
	MemorySummaryPrompt    string
	MemoryExtractPrompt    string
	LocalModelsStorageDir  string
	LocalModelsCatalog     []localmodels.CatalogEntry
}

// AppService LLM 应用层。
type AppService struct {
	db   *gorm.DB
	deps Deps
}

// New 构造 AppService。
func New(db *gorm.DB, deps Deps) *AppService {
	return &AppService{db: db, deps: deps}
}

func (s *AppService) ListModels(ctx context.Context) ([]string, error) {
	return llmbiz.ListModelNames(ctx, s.deps.Inference)
}

func (s *AppService) LocalCatalog() ([]llmbiz.CatalogItem, error) {
	return llmbiz.LoadLocalCatalog(s.deps.LocalModelsStorageDir, s.deps.LocalModelsCatalog)
}

func (s *AppService) ConfigSnapshot() llmbiz.ConfigSnapshot {
	return llmbiz.ConfigSnapshot{
		InferenceBaseURL:       s.deps.Inference.BaseURL,
		InferenceAPIStyle:      string(s.deps.Inference.APIStyle),
		InferenceTimeoutSec:    int(s.deps.Inference.Timeout.Seconds()),
		MemoryModel:            s.deps.MemoryModel,
		HasSummaryPrompt:       s.deps.MemorySummaryPrompt != "",
		HasExtractPrompt:       s.deps.MemoryExtractPrompt != "",
		LocalModelsStorageDir:  s.deps.LocalModelsStorageDir,
		LocalModelsCatalogSize: len(s.deps.LocalModelsCatalog),
		MemoryBudget:           llmbiz.DefaultMemoryBudget(),
	}
}

func (s *AppService) RecordLlmChatTurn(ctx context.Context, in *super.RecordLlmChatTurnReq) (*super.RecordLlmChatTurnResp, error) {
	return llmbiz.RecordChatTurn(ctx, s.db, in)
}

// FindLocalModel 按 id 查找本地模型（供 download handler 使用）。
func (s *AppService) FindLocalModel(id string) (localmodels.Meta, error) {
	return localmodels.FindByID(s.deps.LocalModelsStorageDir, s.deps.LocalModelsCatalog, id)
}

// PostChatCompletion 调用推理服务完成对话补全（F103 biz 化）。
func (s *AppService) PostChatCompletion(
	ctx context.Context,
	model string,
	messages []llmbiz.ChatMessage,
	opts llmbiz.ChatOptions,
) (string, error) {
	return llmbiz.PostChatCompletion(ctx, s.deps.Inference, model, messages, opts)
}

// UpsertUserMemory 写入用户记忆（含异步索引）。
func (s *AppService) UpsertUserMemory(ctx context.Context, in *super.UpsertUserMemoryReq) (*super.UpsertUserMemoryResp, error) {
	return llmbiz.UpsertUserMemory(ctx, s.db, in, llmbiz.MemoryWriteOptions{
		InferenceBaseURL: s.deps.Inference.BaseURL,
	})
}
