package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListCommentsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminListCommentsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListCommentsLogic {
	return &AdminListCommentsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminListCommentsLogic) AdminListComments(req *types.AdminListCommentsReq) (resp *types.AdminListCommentsResp, err error) {
	page := req.Page
	if page <= 0 {
		page = 1
	}
	pageSize := req.PageSize
	if pageSize <= 0 {
		pageSize = 50
	}

	rpcResp, err := l.svcCtx.SuperRpcClient.AdminListComments(l.ctx, &super.AdminListCommentsReq{
		Page:     int32(page),
		PageSize: int32(pageSize),
		Keyword:  req.Keyword,
		PostId:   req.PostId,
	})
	if err != nil {
		return &types.AdminListCommentsResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}

	items := make([]types.Comment, 0, len(rpcResp.GetComments()))
	for _, c := range rpcResp.GetComments() {
		items = append(items, common.RpcCommentToTypes(c))
	}

	return &types.AdminListCommentsResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data: types.AdminListCommentsData{
			Items: items,
			Total: int(rpcResp.GetTotal()),
		},
	}, nil
}
