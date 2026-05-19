package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type FeishuAuthLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewFeishuAuthLogic(ctx context.Context, svcCtx *svc.ServiceContext) *FeishuAuthLogic {
	return &FeishuAuthLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *FeishuAuthLogic) AuthorizeURL(state string) (*types.FeishuAuthorizeURLResp, error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.FeishuAuthorizeURL(l.ctx, &super.FeishuAuthorizeURLReq{
		State: state,
	})
	if err != nil {
		return &types.FeishuAuthorizeURLResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	return &types.FeishuAuthorizeURLResp{
		BaseResp: common.HandleRPCError(nil, ""),
		Data: types.FeishuAuthorizeURLData{
			AuthorizeURL: rpcResp.GetAuthorizeUrl(),
		},
	}, nil
}

func (l *FeishuAuthLogic) Login(code string) (*types.FeishuLoginResp, error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.FeishuLogin(l.ctx, &super.FeishuLoginReq{
		Code: code,
	})
	if err != nil {
		return &types.FeishuLoginResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	resp := &types.FeishuLoginResp{
		BaseResp: common.HandleRPCError(nil, "登录成功"),
	}
	if rpcResp.GetUser() != nil {
		resp.Data = types.FeishuLoginData{
			User:      rpcUserToTypes(rpcResp.GetUser()),
			Token:     rpcResp.GetToken(),
			IsNewUser: rpcResp.GetIsNewUser(),
		}
	}
	return resp, nil
}
