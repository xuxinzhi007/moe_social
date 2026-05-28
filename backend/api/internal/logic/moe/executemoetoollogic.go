package moe

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type ExecuteMoeToolLogic struct {
	logx.Logger
	ctx      context.Context
	svcCtx   *svc.ServiceContext
	actorUID uint
}

func NewExecuteMoeToolLogic(ctx context.Context, svcCtx *svc.ServiceContext, actorUID uint) *ExecuteMoeToolLogic {
	return &ExecuteMoeToolLogic{
		Logger:   logx.WithContext(ctx),
		ctx:      ctx,
		svcCtx:   svcCtx,
		actorUID: actorUID,
	}
}

func (l *ExecuteMoeToolLogic) ExecuteMoeTool(req *types.MoeToolExecuteReq) (*types.MoeToolExecuteResp, error) {
	rpcResp, err := l.svcCtx.MoeGW.MoeExecuteTool(l.ctx, &super.MoeExecuteToolReq{
		Tool:           req.Tool,
		ArgumentsJson:  req.Arguments,
		AgentKey:       req.AgentKey,
		ActorUserId:    uint64(l.actorUID),
		IdempotencyKey: req.IdempotencyKey,
		Source:         "api",
	})
	if err != nil {
		return &types.MoeToolExecuteResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	return &types.MoeToolExecuteResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data: types.MoeToolExecuteData{
			Ok:     rpcResp.Ok,
			Result: rpcResp.Result,
			Error:  rpcResp.Error,
		},
	}, nil
}
