package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpdateUserInfoLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewUpdateUserInfoLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpdateUserInfoLogic {
	return &UpdateUserInfoLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *UpdateUserInfoLogic) UpdateUserInfo(req *types.UpdateUserInfoReq) (resp *types.UpdateUserInfoResp, err error) {
	// 调用RPC服务
	rpcResp, err := l.svcCtx.SuperRpcClient.UpdateUserInfo(l.ctx, &super.UpdateUserInfoReq{
		UserId:             req.UserId,
		Username:           req.Username,
		Email:              req.Email,
		Avatar:             req.Avatar,
		Signature:          req.Signature,
		Gender:             req.Gender,
		Birthday:           req.Birthday,
		Inventory:          req.Inventory,
		EquippedFrameId:    req.EquippedFrameId,
		ClearEquippedFrame: req.ClearEquippedFrame,
		MessageRetention:   req.MessageRetention,
	})
	if err != nil {
		return &types.UpdateUserInfoResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	return &types.UpdateUserInfoResp{
		BaseResp: common.HandleRPCError(nil, "更新用户信息成功"),
		Data:     rpcUserToTypes(rpcResp.User),
	}, nil
}
