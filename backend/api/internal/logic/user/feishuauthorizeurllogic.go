// Code scaffolded by goctl. Safe to edit.
// goctl 1.10.1

package user

import (
	"context"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type FeishuAuthorizeURLLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewFeishuAuthorizeURLLogic(ctx context.Context, svcCtx *svc.ServiceContext) *FeishuAuthorizeURLLogic {
	return &FeishuAuthorizeURLLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *FeishuAuthorizeURLLogic) FeishuAuthorizeURL(req *types.FeishuAuthorizeURLReq) (resp *types.FeishuAuthorizeURLResp, err error) {
	rpcResp, rpcErr := l.svcCtx.UserGW.FeishuAuthorizeURL(l.ctx, &moe.FeishuAuthorizeURLReq{
		State: strings.TrimSpace(req.State),
	})
	if rpcErr != nil {
		return &types.FeishuAuthorizeURLResp{BaseResp: common.HandleRPCError(rpcErr, "")}, nil
	}
	return &types.FeishuAuthorizeURLResp{
		BaseResp: common.HandleRPCError(nil, ""),
		Data: types.FeishuAuthorizeURLData{
			AuthorizeURL: rpcResp.GetAuthorizeUrl(),
		},
	}, nil
}
