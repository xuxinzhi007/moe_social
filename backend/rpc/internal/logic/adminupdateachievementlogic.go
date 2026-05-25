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

type AdminUpdateAchievementLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminUpdateAchievementLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateAchievementLogic {
	return &AdminUpdateAchievementLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminUpdateAchievementLogic) AdminUpdateAchievement(in *super.AdminUpdateAchievementReq) (*super.AdminUpdateAchievementResp, error) {
	id := strings.TrimSpace(in.GetId())
	if id == "" {
		return nil, errors.New("invalid achievement_id")
	}
	var row model.AchievementDefinition
	if err := l.svcCtx.DB.First(&row, "id = ?", id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("achievement not found")
		}
		return nil, err
	}
	updates := map[string]interface{}{}
	if in.GetUpdateName() {
		updates["name"] = strings.TrimSpace(in.GetName())
	}
	if in.GetUpdateDescription() {
		updates["description"] = strings.TrimSpace(in.GetDescription())
	}
	if in.GetUpdateEnabled() {
		updates["enabled"] = in.GetEnabled()
	}
	if in.GetUpdateExpReward() {
		updates["exp_reward"] = int(in.GetExpReward())
	}
	if in.GetUpdateSortOrder() {
		updates["sort_order"] = int(in.GetSortOrder())
	}
	if len(updates) == 0 {
		return &super.AdminUpdateAchievementResp{Item: achievementToProto(row)}, nil
	}
	if err := l.svcCtx.DB.Model(&row).Updates(updates).Error; err != nil {
		return nil, err
	}
	if err := l.svcCtx.DB.First(&row, "id = ?", id).Error; err != nil {
		return nil, err
	}
	return &super.AdminUpdateAchievementResp{Item: achievementToProto(row)}, nil
}
