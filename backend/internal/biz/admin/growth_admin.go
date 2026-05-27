package adminbiz

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"backend/model"
	"backend/rpc/pb/super"
	"backend/utils"

	"gorm.io/gorm"
)

// ListLevelConfigs Admin 等级配置列表。
func ListLevelConfigs(ctx context.Context, db *gorm.DB, _ *super.AdminListLevelConfigsReq) (*super.AdminListLevelConfigsResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	var rows []model.LevelConfig
	if err := db.WithContext(ctx).Order("level ASC").Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrListLevelConfigs, err)
	}
	items := make([]*super.AdminLevelConfigItem, 0, len(rows))
	for _, row := range rows {
		items = append(items, levelConfigToProto(row))
	}
	return &super.AdminListLevelConfigsResp{Items: items}, nil
}

// UpdateLevelConfig Admin 更新等级配置。
func UpdateLevelConfig(ctx context.Context, db *gorm.DB, in *super.AdminUpdateLevelConfigReq) (*super.AdminUpdateLevelConfigResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	id := uint(in.GetId())
	if id == 0 {
		return nil, ErrInvalidLevelID
	}
	var row model.LevelConfig
	if err := db.WithContext(ctx).First(&row, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrLevelConfigNotFound
		}
		return nil, fmt.Errorf("%w: %v", ErrUpdateLevelConfig, err)
	}
	updates := map[string]interface{}{}
	if in.GetUpdateTitle() {
		updates["title"] = strings.TrimSpace(in.GetTitle())
	}
	if in.GetUpdateMinExp() {
		updates["min_exp"] = int(in.GetMinExp())
	}
	if in.GetUpdateMaxExp() {
		updates["max_exp"] = int(in.GetMaxExp())
	}
	if in.GetUpdatePrivileges() {
		updates["privileges"] = strings.TrimSpace(in.GetPrivileges())
	}
	if in.GetUpdateBadgeUrl() {
		updates["badge_url"] = strings.TrimSpace(in.GetBadgeUrl())
	}
	if len(updates) == 0 {
		return &super.AdminUpdateLevelConfigResp{Item: levelConfigToProto(row)}, nil
	}
	if err := db.WithContext(ctx).Model(&row).Updates(updates).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrUpdateLevelConfig, err)
	}
	if err := db.WithContext(ctx).First(&row, id).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrUpdateLevelConfig, err)
	}
	return &super.AdminUpdateLevelConfigResp{Item: levelConfigToProto(row)}, nil
}

// BootstrapLevels Admin 初始化等级与签到奖励。
func BootstrapLevels(ctx context.Context, db *gorm.DB, _ *super.AdminBootstrapLevelsReq) (*super.AdminBootstrapLevelsResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	levelCreated, rewardCreated, err := utils.BootstrapLevelData(db.WithContext(ctx))
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrBootstrapLevels, err)
	}
	return &super.AdminBootstrapLevelsResp{
		LevelConfigsCreated:   levelCreated,
		CheckInRewardsCreated: rewardCreated,
	}, nil
}

// ListCheckInRewards Admin 签到奖励列表。
func ListCheckInRewards(ctx context.Context, db *gorm.DB, _ *super.AdminListCheckInRewardsReq) (*super.AdminListCheckInRewardsResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	var rows []model.CheckInReward
	if err := db.WithContext(ctx).Order("consecutive_days ASC").Find(&rows).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrListCheckInRewards, err)
	}
	items := make([]*super.AdminCheckInRewardItem, 0, len(rows))
	for _, row := range rows {
		items = append(items, checkInRewardToProto(row))
	}
	return &super.AdminListCheckInRewardsResp{Items: items}, nil
}

// UpdateCheckInReward Admin 更新签到奖励。
func UpdateCheckInReward(ctx context.Context, db *gorm.DB, in *super.AdminUpdateCheckInRewardReq) (*super.AdminUpdateCheckInRewardResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	id := uint(in.GetId())
	if id == 0 {
		return nil, ErrInvalidCheckInRewardID
	}
	var row model.CheckInReward
	if err := db.WithContext(ctx).First(&row, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrCheckInRewardNotFound
		}
		return nil, fmt.Errorf("%w: %v", ErrUpdateCheckInReward, err)
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
	if err := db.WithContext(ctx).Model(&row).Updates(updates).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrUpdateCheckInReward, err)
	}
	if err := db.WithContext(ctx).First(&row, id).Error; err != nil {
		return nil, fmt.Errorf("%w: %v", ErrUpdateCheckInReward, err)
	}
	return &super.AdminUpdateCheckInRewardResp{Item: checkInRewardToProto(row)}, nil
}
