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

type BindFeishuLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewBindFeishuLogic(ctx context.Context, svcCtx *svc.ServiceContext) *BindFeishuLogic {
	return &BindFeishuLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *BindFeishuLogic) BindFeishu(req *types.BindFeishuReq) (resp *types.BindFeishuResp, err error) {
	userID, err := common.UserIDString(l.ctx)
	if err != nil {
		return nil, err
	}
	rpcResp, rpcErr := l.svcCtx.UserGW.BindFeishu(l.ctx, &moe.BindFeishuReq{
		UserId:      userID,
		FeishuEmail: req.FeishuEmail,
	})
	if rpcErr != nil {
		return &types.BindFeishuResp{BaseResp: common.HandleRPCError(rpcErr, "")}, nil
	}
	return &types.BindFeishuResp{
		BaseResp: common.HandleRPCError(nil, "飞书绑定成功"),
		Data:     rpcUserToTypes(rpcResp.User),
	}, nil
}
