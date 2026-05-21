// Code scaffolded by goctl. Safe to edit.
// goctl 1.10.1

package user

import (
	"context"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type FeishuLoginLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewFeishuLoginLogic(ctx context.Context, svcCtx *svc.ServiceContext) *FeishuLoginLogic {
	return &FeishuLoginLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *FeishuLoginLogic) FeishuLogin(req *types.FeishuLoginReq) (resp *types.FeishuLoginResp, err error) {
	rpcResp, rpcErr := l.svcCtx.SuperRpcClient.FeishuLogin(l.ctx, &super.FeishuLoginReq{
		Code: strings.TrimSpace(req.Code),
	})
	if rpcErr != nil {
		return &types.FeishuLoginResp{BaseResp: common.HandleRPCError(rpcErr, "")}, nil
	}
	resp = &types.FeishuLoginResp{
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
