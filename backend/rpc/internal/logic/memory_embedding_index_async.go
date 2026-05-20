package logic

import (
	"context"
	"strings"
	"time"

	"backend/pkg/memory"
	"backend/pkg/memory/embed"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

// indexMemoryEmbeddingAsync 单条记忆写入后异步更新向量（学习效果：随记忆变更刷新索引）。
func indexMemoryEmbeddingAsync(db *gorm.DB, userID uint, key, value, source string, logger logx.Logger) {
	if db == nil || userID == 0 {
		return
	}
	if memory.IsTechnical(key, source) || memory.IsDailyNoteKey(key) {
		return
	}
	value = strings.TrimSpace(value)
	if value == "" {
		return
	}
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
		defer cancel()
		text := key + ": " + value
		chain := embed.NewChain(embed.LoadProviders(viperOllamaBaseURL()))
		vecs, provider, model, err := chain.Embed(ctx, []string{text})
		if err != nil {
			if logger != nil {
				logger.Errorf("async embed failed user_id=%d key=%s: %v", userID, key, err)
			}
			return
		}
		if len(vecs) == 0 {
			return
		}
		if err := upsertMemoryEmbedding(db, userID, key, text, provider, model, vecs[0]); err != nil && logger != nil {
			logger.Errorf("async embed upsert failed user_id=%d key=%s: %v", userID, key, err)
		}
	}()
}
