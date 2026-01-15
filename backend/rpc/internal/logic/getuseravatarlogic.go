package logic

import (
	"context"
	"encoding/json"
	"errors"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type GetUserAvatarLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserAvatarLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserAvatarLogic {
	return &GetUserAvatarLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

// 虚拟形象相关服务
func (l *GetUserAvatarLogic) GetUserAvatar(in *super.GetUserAvatarReq) (*super.GetUserAvatarResp, error) {
	logx.Infof("RPC: 获取用户虚拟形象 UserID=%s", in.UserId)

	// 从数据库查询用户虚拟形象
	var userAvatar model.UserAvatar
	result := l.svcCtx.DB.Where("user_id = ?", in.UserId).First(&userAvatar)

	if result.Error != nil {
		if errors.Is(result.Error, gorm.ErrRecordNotFound) {
			// 用户没有设置虚拟形象，返回默认形象数据
			logx.Infof("用户 %s 没有设置虚拟形象，返回默认数据", in.UserId)
			return &super.GetUserAvatarResp{
				Avatar: &super.UserAvatarData{
					UserId: in.UserId,
					BaseConfig: &super.AvatarBaseConfig{
						FaceShape: "face_1",
						SkinColor: "#FDBCB4",
						EyeType:   "eyes_1",
						HairStyle: "hair_1",
						HairColor: "#8B4513",
					},
					CurrentOutfit: &super.AvatarOutfitConfig{
						Clothes:     "clothes_1",
						Accessories: []string{},
						Background:  "default",
					},
					OwnedOutfits: []string{},
				},
			}, nil
		} else {
			logx.Errorf("查询用户虚拟形象失败: %v", result.Error)
			return nil, result.Error
		}
	}

	// 解析JSON数据
	var baseConfig super.AvatarBaseConfig
	if err := json.Unmarshal([]byte(userAvatar.BaseConfig), &baseConfig); err != nil {
		logx.Errorf("解析基础配置失败: %v", err)
		return nil, err
	}

	var currentOutfit super.AvatarOutfitConfig
	if err := json.Unmarshal([]byte(userAvatar.CurrentOutfit), &currentOutfit); err != nil {
		logx.Errorf("解析服装配置失败: %v", err)
		return nil, err
	}

	var ownedOutfits []string
	if err := json.Unmarshal([]byte(userAvatar.OwnedOutfits), &ownedOutfits); err != nil {
		logx.Errorf("解析拥有装扮失败: %v", err)
		// 如果解析失败，使用空数组
		ownedOutfits = []string{}
	}

	// 构建返回数据
	avatarData := &super.UserAvatarData{
		UserId:        in.UserId,
		BaseConfig:    &baseConfig,
		CurrentOutfit: &currentOutfit,
		OwnedOutfits:  ownedOutfits,
	}

	logx.Infof("成功获取用户虚拟形象: %+v", avatarData)

	return &super.GetUserAvatarResp{
		Avatar: avatarData,
	}, nil
}
