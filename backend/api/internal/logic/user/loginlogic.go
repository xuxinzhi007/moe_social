package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type LoginLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewLoginLogic(ctx context.Context, svcCtx *svc.ServiceContext) *LoginLogic {
	return &LoginLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *LoginLogic) Login(req *types.LoginReq) (resp *types.LoginResp, err error) {
	// 调用RPC服务
	rpcResp, err := l.svcCtx.SuperRpcClient.Login(l.ctx, &super.LoginReq{
		Username: req.Username,
		Password: req.Password,
		Email:    req.Email,
	})
	if err != nil {
		l.Errorf("调用RPC服务失败: %v", err)
		return &types.LoginResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	// 转换为API响应
	resp = &types.LoginResp{
		BaseResp: common.HandleRPCError(nil, "登录成功"),
	}

	// 设置用户数据
	if rpcResp.User != nil {
		resp.Data = types.LoginData{
			User: types.User{
				Id:           rpcResp.User.Id,
				Username:     rpcResp.User.Username,
				Email:        rpcResp.User.Email,
				Avatar:       rpcResp.User.Avatar,
				CreatedAt:    rpcResp.User.CreatedAt,
				UpdatedAt:    rpcResp.User.UpdatedAt,
				IsVip:        rpcResp.User.IsVip,
				VipExpiresAt: rpcResp.User.VipExpiresAt,
				AutoRenew:    rpcResp.User.AutoRenew,
			},
			Token: rpcResp.Token,
		}
	}

	return resp, nil
}
