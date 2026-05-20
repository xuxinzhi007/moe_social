package logic

import (
	"context"

	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type ListUserMemoryEmbeddingsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewListUserMemoryEmbeddingsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListUserMemoryEmbeddingsLogic {
	return &ListUserMemoryEmbeddingsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *ListUserMemoryEmbeddingsLogic) ListUserMemoryEmbeddings(in *super.ListUserMemoryEmbeddingsReq) (*super.ListUserMemoryEmbeddingsResp, error) {
	userID, err := parseUserIDUint(in.UserId)
	if err != nil || userID == 0 {
		return nil, errorx.InvalidArgument("无效的user_id")
	}
	m, err := listMemoryEmbeddings(l.svcCtx.DB, userID)
	if err != nil {
		return nil, errorx.Internal("查询记忆向量失败")
	}
	items := make([]*super.UserMemoryEmbeddingItem, 0, len(m))
	for key, vec := range m {
		vals := make([]float32, len(vec))
		copy(vals, vec)
		items = append(items, &super.UserMemoryEmbeddingItem{
			MemoryKey: key,
			Values:    vals,
		})
	}
	return &super.ListUserMemoryEmbeddingsResp{Items: items}, nil
}
