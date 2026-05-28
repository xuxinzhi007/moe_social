package logic

import (
	"context"
	"errors"

	postapp "backend/internal/service/post"
	postbiz "backend/internal/biz/post"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type ReportPostLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewReportPostLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ReportPostLogic {
	return &ReportPostLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *ReportPostLogic) ReportPost(in *moe.ReportPostReq) (*moe.ReportPostResp, error) {
	app := postapp.New(l.svcCtx.DB, l.svcCtx.Config.HandDrawRequireModeration)
	resp, err := app.ReportPost(l.ctx, in)
	if err != nil {
		switch {
		case errors.Is(err, postbiz.ErrInvalidPostID):
			return nil, errorx.New(400, "无效的帖子ID")
		case errors.Is(err, postbiz.ErrInvalidUserID):
			return nil, errorx.New(400, "无效的用户ID")
		case errors.Is(err, postbiz.ErrEmptyReporterID):
			return nil, errorx.New(400, "举报人不能为空")
		case errors.Is(err, postbiz.ErrEmptyReason):
			return nil, errorx.New(400, "举报原因不能为空")
		case errors.Is(err, postbiz.ErrPostNotFound):
			return nil, errorx.New(404, "帖子不存在")
		default:
			l.Error("写入举报记录失败: ", err)
			return nil, errorx.New(500, "提交举报失败")
		}
	}
	return resp, nil
}
