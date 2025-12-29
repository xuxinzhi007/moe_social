package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpdateUserPasswordLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewUpdateUserPasswordLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpdateUserPasswordLogic {
	return &UpdateUserPasswordLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *UpdateUserPasswordLogic) UpdateUserPassword(req *types.UpdateUserPasswordReq) (resp *types.UpdateUserPasswordResp, err error) {
	// 调用RPC服务
	_, err = l.svcCtx.SuperRpcClient.UpdateUserPassword(l.ctx, &super.UpdateUserPasswordReq{
		UserId:      req.UserId,
		OldPassword: req.OldPassword,
		NewPassword: req.NewPassword,
	})
	if err != nil {
		return &types.UpdateUserPasswordResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	// 转换为API响应
	return &types.UpdateUserPasswordResp{
		BaseResp: common.HandleRPCError(nil, "更新密码成功"),
	}, nil
}
