// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

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

type WechatLoginLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewWechatLoginLogic(ctx context.Context, svcCtx *svc.ServiceContext) *WechatLoginLogic {
	return &WechatLoginLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *WechatLoginLogic) WechatLogin(req *types.WechatLoginReq) (resp *types.WechatLoginResp, err error) {
	rpcResp, rpcErr := l.svcCtx.SuperRpcClient.WechatLogin(l.ctx, &super.WechatLoginReq{
		Code: strings.TrimSpace(req.Code),
		Flow: strings.TrimSpace(req.Flow),
	})
	if rpcErr != nil {
		return &types.WechatLoginResp{BaseResp: common.HandleRPCError(rpcErr, "")}, nil
	}
	resp = &types.WechatLoginResp{
		BaseResp: common.HandleRPCError(nil, "登录成功"),
	}
	if rpcResp.GetUser() != nil {
		resp.Data = types.WechatLoginData{
			User:      rpcUserToTypes(rpcResp.GetUser()),
			Token:     rpcResp.GetToken(),
			IsNewUser: rpcResp.GetIsNewUser(),
		}
	}
	return resp, nil
}
