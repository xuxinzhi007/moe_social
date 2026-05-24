package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListPostReportsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminListPostReportsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListPostReportsLogic {
	return &AdminListPostReportsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminListPostReportsLogic) AdminListPostReports(req *types.AdminListPostReportsReq) (resp *types.AdminListPostReportsResp, err error) {
	page := req.Page
	if page <= 0 {
		page = 1
	}
	pageSize := req.PageSize
	if pageSize <= 0 {
		pageSize = 50
	}

	rpcResp, err := l.svcCtx.SuperRpcClient.AdminListPostReports(l.ctx, &super.AdminListPostReportsReq{
		Page:     int32(page),
		PageSize: int32(pageSize),
	})
	if err != nil {
		return &types.AdminListPostReportsResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}

	items := make([]types.AdminPostReportItem, 0, len(rpcResp.GetReports()))
	for _, r := range rpcResp.GetReports() {
		items = append(items, types.AdminPostReportItem{
			Id:                 r.GetId(),
			PostId:             r.GetPostId(),
			ReporterUserId:     r.GetReporterUserId(),
			Reason:             r.GetReason(),
			CreatedAt:          r.GetCreatedAt(),
			PostContentPreview: r.GetPostContentPreview(),
		})
	}

	return &types.AdminListPostReportsResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data: types.AdminListPostReportsData{
			Items: items,
			Total: int(rpcResp.GetTotal()),
		},
	}, nil
}
