package logic

import (
	"context"
	"strings"

	"backend/model"
	"backend/pkg/memory"
	"backend/pkg/memory/embed"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type RebuildUserMemoryEmbeddingsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewRebuildUserMemoryEmbeddingsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *RebuildUserMemoryEmbeddingsLogic {
	return &RebuildUserMemoryEmbeddingsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *RebuildUserMemoryEmbeddingsLogic) RebuildUserMemoryEmbeddings(in *super.RebuildUserMemoryEmbeddingsReq) (*super.RebuildUserMemoryEmbeddingsResp, error) {
	userID, err := parseUserIDUint(in.UserId)
	if err != nil || userID == 0 {
		return nil, errorx.InvalidArgument("无效的user_id")
	}

	var memories []model.UserMemory
	if err := l.svcCtx.DB.Where("user_id = ?", userID).
		Order("updated_at desc").
		Limit(200).
		Find(&memories).Error; err != nil {
		return nil, errorx.Internal("读取记忆失败")
	}

	texts := make([]string, 0, len(memories))
	keys := make([]string, 0, len(memories))
	for _, m := range memories {
		if memory.IsTechnical(m.Key, m.Source) {
			continue
		}
		v := strings.TrimSpace(m.Value)
		if v == "" {
			continue
		}
		keys = append(keys, m.Key)
		texts = append(texts, m.Key+": "+v)
	}
	if len(texts) == 0 {
		_ = deleteEmbeddingsForUser(l.svcCtx.DB, userID)
		return &super.RebuildUserMemoryEmbeddingsResp{Indexed: 0}, nil
	}

	chain := embed.NewChain(embed.LoadProviders(viperInferenceBaseURL()))
	vecs, provider, model, err := chain.Embed(l.ctx, texts)
	if err != nil {
		return nil, errorx.Internal("生成记忆向量失败: " + err.Error())
	}

	_ = deleteEmbeddingsForUser(l.svcCtx.DB, userID)
	for i, key := range keys {
		if i >= len(vecs) {
			break
		}
		if err := upsertMemoryEmbedding(l.svcCtx.DB, userID, key, texts[i], provider, model, vecs[i]); err != nil {
			l.Errorf("upsert embedding failed key=%s: %v", key, err)
		}
	}

	triggerMemoryRelationsSyncAsync(l.svcCtx.DB, userID, l.Logger)

	return &super.RebuildUserMemoryEmbeddingsResp{
		Indexed:  int32(len(vecs)),
		Provider: provider,
		Model:    model,
	}, nil
}
