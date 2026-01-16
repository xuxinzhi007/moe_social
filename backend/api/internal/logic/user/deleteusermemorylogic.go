package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type DeleteUserMemoryLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewDeleteUserMemoryLogic(ctx context.Context, svcCtx *svc.ServiceContext) *DeleteUserMemoryLogic {
	return &DeleteUserMemoryLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *DeleteUserMemoryLogic) DeleteUserMemory(req *types.DeleteUserMemoryReq) (resp *types.DeleteUserMemoryResp, err error) {
	_, err = l.svcCtx.SuperRpcClient.DeleteUserMemory(l.ctx, &super.DeleteUserMemoryReq{
		UserId: req.UserId,
		Key:    req.Key,
	})
	if err != nil {
		return &types.DeleteUserMemoryResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	return &types.DeleteUserMemoryResp{
		BaseResp: common.HandleRPCError(nil, "删除用户记忆成功"),
	}, nil
}

