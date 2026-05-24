package logic

import (
	"context"
	"time"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/spf13/viper"
	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDashboardLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminDashboardLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDashboardLogic {
	return &AdminDashboardLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminDashboardLogic) AdminDashboard(_ *super.AdminDashboardReq) (*super.AdminDashboardResp, error) {
	var feedbackTotal int64
	if err := l.svcCtx.DB.Model(&model.LandingFeedback{}).Count(&feedbackTotal).Error; err != nil {
		l.Errorf("[admin] count landing feedback: %v", err)
		return nil, errorx.Internal("服务器内部错误")
	}

	var userTotal int64
	if err := l.svcCtx.DB.Model(&model.User{}).Count(&userTotal).Error; err != nil {
		l.Errorf("[admin] count users: %v", err)
		return nil, errorx.Internal("服务器内部错误")
	}

	return &super.AdminDashboardResp{
		LandingFeedbackTotal: int32(feedbackTotal),
		UserTotal:            int32(userTotal),
		ServerTime:           time.Now().Format(time.RFC3339),
		FeishuEnabled:        viper.GetBool("feishu.enabled"),
	}, nil
}
