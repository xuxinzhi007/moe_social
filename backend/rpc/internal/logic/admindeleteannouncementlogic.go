package logic

import (
	"context"
	"strconv"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDeleteAnnouncementLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminDeleteAnnouncementLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteAnnouncementLogic {
	return &AdminDeleteAnnouncementLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminDeleteAnnouncementLogic) AdminDeleteAnnouncement(in *super.AdminDeleteAnnouncementReq) (*super.AdminDeleteAnnouncementResp, error) {
	id, err := strconv.ParseUint(strings.TrimSpace(in.GetAnnouncementId()), 10, 64)
	if err != nil || id == 0 {
		return nil, errorx.InvalidArgument("公告 ID 无效")
	}
	if err := l.svcCtx.DB.Delete(&model.AdminAnnouncement{}, id).Error; err != nil {
		l.Errorf("[admin] delete announcement: %v", err)
		return nil, errorx.Internal("删除公告失败")
	}
	return &super.AdminDeleteAnnouncementResp{}, nil
}
