package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListGroupsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminListGroupsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListGroupsLogic {
	return &AdminListGroupsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminListGroupsLogic) AdminListGroups(req *types.AdminListGroupsReq) (resp *types.AdminListGroupsResp, err error) {
	page := req.Page
	if page <= 0 {
		page = 1
	}
	pageSize := req.PageSize
	if pageSize <= 0 {
		pageSize = 50
	}

	rpcResp, err := l.svcCtx.AdminGW.AdminListGroups(l.ctx, &super.AdminListGroupsReq{
		Page:     int32(page),
		PageSize: int32(pageSize),
		Keyword:  req.Keyword,
	})
	if err != nil {
		return &types.AdminListGroupsResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}

	items := make([]types.Group, 0, len(rpcResp.GetGroups()))
	for _, g := range rpcResp.GetGroups() {
		items = append(items, common.RpcGroupToTypes(g))
	}

	return &types.AdminListGroupsResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data: types.AdminListGroupsData{
			Items: items,
			Total: int(rpcResp.GetTotal()),
		},
	}, nil
}
