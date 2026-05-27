package user

import (
	"context"
	"errors"

	"backend/api/internal/svc"
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

func (l *RebuildUserMemoryEmbeddingsLogic) RebuildUserMemoryEmbeddings(userID string) (map[string]interface{}, error) {
	if userID == "" {
		return nil, errors.New("user_id 不能为空")
	}
	resp, err := l.svcCtx.LLMGW.RebuildUserMemoryEmbeddings(l.ctx, &super.RebuildUserMemoryEmbeddingsReq{
		UserId: userID,
	})
	if err != nil {
		return nil, err
	}
	return map[string]interface{}{
		"indexed":  resp.Indexed,
		"provider": resp.Provider,
		"model":    resp.Model,
	}, nil
}
