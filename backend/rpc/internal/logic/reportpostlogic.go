package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type ReportPostLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewReportPostLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ReportPostLogic {
	return &ReportPostLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *ReportPostLogic) ReportPost(in *super.ReportPostReq) (*super.ReportPostResp, error) {
	if in.PostId == "" {
		return nil, errorx.New(400, "帖子ID不能为空")
	}
	if in.ReporterUserId == "" {
		return nil, errorx.New(400, "举报人不能为空")
	}
	if in.Reason == "" {
		return nil, errorx.New(400, "举报原因不能为空")
	}

	postID, err := strconv.ParseUint(in.PostId, 10, 32)
	if err != nil {
		return nil, errorx.New(400, "无效的帖子ID")
	}
	reporterID, err := strconv.ParseUint(in.ReporterUserId, 10, 32)
	if err != nil {
		return nil, errorx.New(400, "无效的用户ID")
	}

	var post model.Post
	if err := l.svcCtx.DB.Where("id = ?", postID).First(&post).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, errorx.New(404, "帖子不存在")
		}
		l.Error("查询帖子失败: ", err)
		return nil, errorx.New(500, "服务器内部错误")
	}

	rep := model.PostReport{
		PostID:         uint(postID),
		ReporterUserID: uint(reporterID),
		Reason:         in.Reason,
	}
	if err := l.svcCtx.DB.Create(&rep).Error; err != nil {
		l.Error("写入举报记录失败: ", err)
		return nil, errorx.New(500, "提交举报失败")
	}

	return &super.ReportPostResp{}, nil
}
