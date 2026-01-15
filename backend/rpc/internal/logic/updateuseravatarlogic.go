package logic

import (
	"context"
	"encoding/json"
	"errors"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/google/uuid"
	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type UpdateUserAvatarLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewUpdateUserAvatarLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpdateUserAvatarLogic {
	return &UpdateUserAvatarLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *UpdateUserAvatarLogic) UpdateUserAvatar(in *super.UpdateUserAvatarReq) (*super.UpdateUserAvatarResp, error) {
	logx.Infof("RPC: 更新用户虚拟形象 UserID=%s", in.UserId)

	// 序列化配置数据为JSON
	baseConfigJSON, err := json.Marshal(in.BaseConfig)
	if err != nil {
		logx.Errorf("序列化基础配置失败: %v", err)
		return nil, err
	}

	currentOutfitJSON, err := json.Marshal(in.CurrentOutfit)
	if err != nil {
		logx.Errorf("序列化服装配置失败: %v", err)
		return nil, err
	}

	// 查找是否已存在用户虚拟形象记录
	var existingAvatar model.UserAvatar
	result := l.svcCtx.DB.Where("user_id = ?", in.UserId).First(&existingAvatar)

	if result.Error != nil && !errors.Is(result.Error, gorm.ErrRecordNotFound) {
		logx.Errorf("查询用户虚拟形象失败: %v", result.Error)
		return nil, result.Error
	}

	// 准备虚拟形象数据
	avatarData := model.UserAvatar{
		UserID:        in.UserId,
		BaseConfig:    string(baseConfigJSON),
		CurrentOutfit: string(currentOutfitJSON),
		OwnedOutfits:  "[]", // 默认空数组
	}

	if errors.Is(result.Error, gorm.ErrRecordNotFound) {
		// 新增虚拟形象记录
		avatarData.ID = uuid.New().String()
		if err := l.svcCtx.DB.Create(&avatarData).Error; err != nil {
			logx.Errorf("创建用户虚拟形象失败: %v", err)
			return nil, err
		}
		logx.Infof("创建新的虚拟形象记录: ID=%s", avatarData.ID)
	} else {
		// 更新现有记录
		avatarData.ID = existingAvatar.ID
		if err := l.svcCtx.DB.Model(&existingAvatar).Updates(map[string]interface{}{
			"base_config":    string(baseConfigJSON),
			"current_outfit": string(currentOutfitJSON),
		}).Error; err != nil {
			logx.Errorf("更新用户虚拟形象失败: %v", err)
			return nil, err
		}
		logx.Infof("更新虚拟形象记录: ID=%s", avatarData.ID)
	}

	// 解析owned_outfits (目前为空数组)
	var ownedOutfits []string
	json.Unmarshal([]byte(avatarData.OwnedOutfits), &ownedOutfits)

	// 返回更新后的虚拟形象数据
	return &super.UpdateUserAvatarResp{
		Avatar: &super.UserAvatarData{
			UserId:        in.UserId,
			BaseConfig:    in.BaseConfig,
			CurrentOutfit: in.CurrentOutfit,
			OwnedOutfits:  ownedOutfits,
		},
	}, nil
}
