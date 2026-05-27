// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListUsersLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminListUsersLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListUsersLogic {
	return &AdminListUsersLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminListUsersLogic) AdminListUsers(req *types.AdminListUsersReq) (resp *types.AdminListUsersResp, err error) {
	page := req.Page
	if page <= 0 {
		page = 1
	}
	pageSize := req.PageSize
	if pageSize <= 0 {
		pageSize = 20
	}

	rpcResp, err := l.svcCtx.AdminGW.AdminListUsers(l.ctx, &super.AdminListUsersReq{
		Page:     int32(page),
		PageSize: int32(pageSize),
		Keyword:  req.Keyword,
	})
	if err != nil {
		return &types.AdminListUsersResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	items := make([]types.User, 0, len(rpcResp.Users))
	for _, u := range rpcResp.Users {
		items = append(items, common.RpcUserToTypes(u))
	}

	return &types.AdminListUsersResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data: types.AdminListUsersData{
			Items: items,
			Total: int(rpcResp.Total),
		},
	}, nil
}
