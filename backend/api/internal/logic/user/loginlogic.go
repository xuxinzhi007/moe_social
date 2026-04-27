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
		l.Errorf("[认证] 登录：调用用户服务失败 错误=%v", err)
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
			User:  rpcUserToTypes(rpcResp.User),
			Token: rpcResp.Token,
		}
	}

	return resp, nil
}
