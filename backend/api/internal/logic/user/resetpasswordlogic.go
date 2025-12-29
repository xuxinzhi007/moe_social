package user

import (
	"context"
	"errors"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type ResetPasswordLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewResetPasswordLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ResetPasswordLogic {
	return &ResetPasswordLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *ResetPasswordLogic) ResetPassword(req *types.ResetPasswordReq) (resp *types.ResetPasswordResp, err error) {
	// 1. 验证参数
	if req.Email == "" {
		return &types.ResetPasswordResp{
			BaseResp: common.HandleError(errors.New("邮箱不能为空")),
		}, nil
	}
	if req.NewPassword == "" {
		return &types.ResetPasswordResp{
			BaseResp: common.HandleError(errors.New("新密码不能为空")),
		}, nil
	}

	// 2. 调用 RPC 服务重置密码
	_, err = l.svcCtx.SuperRpcClient.ResetPassword(l.ctx, &super.ResetPasswordReq{
		Email:       req.Email,
		NewPassword: req.NewPassword,
	})

	if err != nil {
		// RPC 调用失败，处理错误
		// 这里可以根据具体错误类型（如用户不存在）返回更友好的提示，
		// 但为了安全，有时候也可以模糊处理。这里简单透传错误信息。
		return &types.ResetPasswordResp{
			BaseResp: common.HandleRPCError(err, "重置密码失败"),
		}, nil
	}

	return &types.ResetPasswordResp{
		BaseResp: common.HandleRPCError(nil, "重置密码成功"),
	}, nil
}
