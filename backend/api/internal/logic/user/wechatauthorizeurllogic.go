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

type WechatAuthorizeURLLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewWechatAuthorizeURLLogic(ctx context.Context, svcCtx *svc.ServiceContext) *WechatAuthorizeURLLogic {
	return &WechatAuthorizeURLLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *WechatAuthorizeURLLogic) WechatAuthorizeURL(req *types.WechatAuthorizeURLReq) (resp *types.WechatAuthorizeURLResp, err error) {
	rpcResp, rpcErr := l.svcCtx.UserGW.WechatAuthorizeURL(l.ctx, &super.WechatAuthorizeURLReq{
		State: strings.TrimSpace(req.State),
		Flow:  strings.TrimSpace(req.Flow),
	})
	if rpcErr != nil {
		return &types.WechatAuthorizeURLResp{BaseResp: common.HandleRPCError(rpcErr, "")}, nil
	}
	return &types.WechatAuthorizeURLResp{
		BaseResp: common.HandleRPCError(nil, ""),
		Data: types.WechatAuthorizeURLData{
			AuthorizeURL: rpcResp.GetAuthorizeUrl(),
		},
	}, nil
}
