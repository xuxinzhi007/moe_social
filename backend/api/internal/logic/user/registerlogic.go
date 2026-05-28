package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type RegisterLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewRegisterLogic(ctx context.Context, svcCtx *svc.ServiceContext) *RegisterLogic {
	return &RegisterLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *RegisterLogic) Register(req *types.RegisterReq) (resp *types.RegisterResp, err error) {
	// 调用RPC服务
	rpcResp, err := l.svcCtx.UserGW.Register(l.ctx, &moe.RegisterReq{
		Username: req.Username,
		Password: req.Password,
		Email:    req.Email,
	})
	if err != nil {
		return &types.RegisterResp{
			BaseResp: common.HandleUserGWError(err, ""),
		}, nil
	}

	resp = &types.RegisterResp{
		BaseResp: common.HandleRPCError(nil, "注册成功"),
	}
	if rpcResp.User != nil {
		resp.Data = types.RegisterData{
			User:  rpcUserToTypes(rpcResp.User),
			Token: rpcResp.Token,
		}
	}
	return resp, nil
}
