package logic

import (
	"context"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListCheckInRewardsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListCheckInRewardsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListCheckInRewardsLogic {
	return &AdminListCheckInRewardsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminListCheckInRewardsLogic) AdminListCheckInRewards(in *super.AdminListCheckInRewardsReq) (*super.AdminListCheckInRewardsResp, error) {
	var rows []model.CheckInReward
	if err := l.svcCtx.DB.Order("consecutive_days ASC").Find(&rows).Error; err != nil {
		return nil, err
	}
	items := make([]*super.AdminCheckInRewardItem, 0, len(rows))
	for _, row := range rows {
		items = append(items, checkInRewardToProto(row))
	}
	return &super.AdminListCheckInRewardsResp{Items: items}, nil
}
