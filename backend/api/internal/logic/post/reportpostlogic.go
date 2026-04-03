// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

package post

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type ReportPostLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewReportPostLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ReportPostLogic {
	return &ReportPostLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *ReportPostLogic) ReportPost(req *types.ReportPostReq) (resp *types.ReportPostResp, err error) {
	_, err = l.svcCtx.SuperRpcClient.ReportPost(l.ctx, &super.ReportPostReq{
		PostId:         req.PostId,
		ReporterUserId: req.ReporterUserId,
		Reason:         req.Reason,
	})
	if err != nil {
		return &types.ReportPostResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}
	return &types.ReportPostResp{
		BaseResp: common.HandleRPCError(nil, "举报已提交"),
	}, nil
}
