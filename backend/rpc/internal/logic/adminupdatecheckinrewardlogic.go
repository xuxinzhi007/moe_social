package logic

import (
	"context"
	"errors"
	"strings"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type AdminUpdateCheckInRewardLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminUpdateCheckInRewardLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateCheckInRewardLogic {
	return &AdminUpdateCheckInRewardLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminUpdateCheckInRewardLogic) AdminUpdateCheckInReward(in *super.AdminUpdateCheckInRewardReq) (*super.AdminUpdateCheckInRewardResp, error) {
	id := uint(in.GetId())
	if id == 0 {
		return nil, errors.New("invalid reward_id")
	}
	var row model.CheckInReward
	if err := l.svcCtx.DB.First(&row, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("check-in reward not found")
		}
		return nil, err
	}
	updates := map[string]interface{}{}
	if in.GetUpdateConsecutiveDays() {
		updates["consecutive_days"] = int(in.GetConsecutiveDays())
	}
	if in.GetUpdateExpReward() {
		updates["exp_reward"] = int(in.GetExpReward())
	}
	if in.GetUpdateExtraReward() {
		updates["extra_reward"] = strings.TrimSpace(in.GetExtraReward())
	}
	if len(updates) == 0 {
		return &super.AdminUpdateCheckInRewardResp{Item: checkInRewardToProto(row)}, nil
	}
	if err := l.svcCtx.DB.Model(&row).Updates(updates).Error; err != nil {
		return nil, err
	}
	if err := l.svcCtx.DB.First(&row, id).Error; err != nil {
		return nil, err
	}
	return &super.AdminUpdateCheckInRewardResp{Item: checkInRewardToProto(row)}, nil
}
