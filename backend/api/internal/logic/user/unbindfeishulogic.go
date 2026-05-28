// Code scaffolded by goctl. Safe to edit.
// goctl 1.10.1

package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type UnbindFeishuLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewUnbindFeishuLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UnbindFeishuLogic {
	return &UnbindFeishuLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *UnbindFeishuLogic) UnbindFeishu(req *types.EmptyReq) (resp *types.UnbindFeishuResp, err error) {
	userID, err := common.UserIDString(l.ctx)
	if err != nil {
		return nil, err
	}
	rpcResp, rpcErr := l.svcCtx.UserGW.UnbindFeishu(l.ctx, &moe.UnbindFeishuReq{
		UserId: userID,
	})
	if rpcErr != nil {
		return &types.UnbindFeishuResp{BaseResp: common.HandleRPCError(rpcErr, "")}, nil
	}
	return &types.UnbindFeishuResp{
		BaseResp: common.HandleRPCError(nil, "已解除飞书绑定"),
		Data:     rpcUserToTypes(rpcResp.User),
	}, nil
}
