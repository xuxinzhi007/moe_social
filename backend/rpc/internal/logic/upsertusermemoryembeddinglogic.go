package logic

import (
	"context"

	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpsertUserMemoryEmbeddingLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewUpsertUserMemoryEmbeddingLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpsertUserMemoryEmbeddingLogic {
	return &UpsertUserMemoryEmbeddingLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *UpsertUserMemoryEmbeddingLogic) UpsertUserMemoryEmbedding(in *super.UpsertUserMemoryEmbeddingReq) (*super.UpsertUserMemoryEmbeddingResp, error) {
	userID, err := parseUserIDUint(in.UserId)
	if err != nil || userID == 0 {
		return nil, errorx.InvalidArgument("无效的user_id")
	}
	if in.MemoryKey == "" || len(in.Values) == 0 {
		return nil, errorx.InvalidArgument("memory_key 与 values 不能为空")
	}
	vec := make([]float32, len(in.Values))
	for i, v := range in.Values {
		vec[i] = v
	}
	if err := upsertMemoryEmbedding(l.svcCtx.DB, userID, in.MemoryKey, in.ChunkText, in.Provider, in.Model, vec); err != nil {
		return nil, errorx.Internal("写入记忆向量失败")
	}
	return &super.UpsertUserMemoryEmbeddingResp{}, nil
}
