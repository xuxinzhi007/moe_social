package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListPostsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminListPostsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListPostsLogic {
	return &AdminListPostsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminListPostsLogic) AdminListPosts(req *types.AdminListPostsReq) (resp *types.AdminListPostsResp, err error) {
	page := req.Page
	if page <= 0 {
		page = 1
	}
	pageSize := req.PageSize
	if pageSize <= 0 {
		pageSize = 20
	}

	rpcResp, err := l.svcCtx.AdminGW.AdminListPosts(l.ctx, &super.AdminListPostsReq{
		Page:             int32(page),
		PageSize:         int32(pageSize),
		Keyword:          req.Keyword,
		ModerationStatus: req.ModerationStatus,
		IncludeDeleted:   req.IncludeDeleted,
	})
	if err != nil {
		return &types.AdminListPostsResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}

	items := make([]types.Post, 0, len(rpcResp.GetPosts()))
	for _, p := range rpcResp.GetPosts() {
		items = append(items, common.RpcPostToTypes(p))
	}

	return &types.AdminListPostsResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data: types.AdminListPostsData{
			Items: items,
			Total: int(rpcResp.GetTotal()),
		},
	}, nil
}
