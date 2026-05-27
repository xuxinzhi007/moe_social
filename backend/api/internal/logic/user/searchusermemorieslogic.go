package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type SearchUserMemoriesLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewSearchUserMemoriesLogic(ctx context.Context, svcCtx *svc.ServiceContext) *SearchUserMemoriesLogic {
	return &SearchUserMemoriesLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *SearchUserMemoriesLogic) SearchUserMemories(req *types.SearchUserMemoriesReq) (map[string]interface{}, error) {
	const listLimit = 200
	limit := req.Limit
	if limit <= 0 {
		limit = 8
	}

	memResp, err := l.svcCtx.LLMGW.GetUserMemories(l.ctx, &super.GetUserMemoriesReq{
		UserId: req.UserId,
		Limit:  listLimit,
		Offset: 0,
	})
	if err != nil {
		base := common.HandleRPCError(err, "")
		return map[string]interface{}{
			"code": base.Code, "message": base.Message, "success": false,
		}, nil
	}

	result := HybridSearchUserFacingMemories(l.ctx, l.svcCtx, req.UserId, memResp.Memories, req.Q, limit)
	base := common.HandleRPCError(nil, "记忆检索成功")
	return map[string]interface{}{
		"code":    base.Code,
		"message": base.Message,
		"success": base.Success,
		"data":    result,
	}, nil
}
