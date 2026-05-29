package userbiz

import (
	"context"
	"encoding/json"

	userv1 "backend/api/user/v1"
	"backend/model"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

func defaultUserAvatarData(userID string) *userv1.UserAvatarData {
	return &userv1.UserAvatarData{
		UserId: userID,
		BaseConfig: &userv1.AvatarBaseConfig{
			FaceShape: "face_1",
			SkinColor: "#FDBCB4",
			EyeType:   "eyes_1",
			HairStyle: "hair_1",
			HairColor: "#8B4513",
		},
		CurrentOutfit: &userv1.AvatarOutfitConfig{
			Clothes:     "clothes_1",
			Accessories: []string{},
			Background:  "default",
		},
		OwnedOutfits: []string{},
	}
}

// GetUserAvatar 获取用户虚拟形象；无记录时返回默认形象。
func GetUserAvatar(ctx context.Context, store UserStore, in *userv1.GetUserAvatarReq) (*userv1.GetUserAvatarResp, error) {
	if store == nil || in == nil {
		return nil, gorm.ErrInvalidDB
	}
	userAvatar, found, err := store.GetUserAvatar(ctx, in.GetUserId())
	if err != nil {
		return nil, err
	}
	if !found {
		return &userv1.GetUserAvatarResp{Avatar: defaultUserAvatarData(in.GetUserId())}, nil
	}
	var baseConfig userv1.AvatarBaseConfig
	if err := json.Unmarshal([]byte(userAvatar.BaseConfig), &baseConfig); err != nil {
		return nil, err
	}
	var currentOutfit userv1.AvatarOutfitConfig
	if err := json.Unmarshal([]byte(userAvatar.CurrentOutfit), &currentOutfit); err != nil {
		return nil, err
	}
	var ownedOutfits []string
	if err := json.Unmarshal([]byte(userAvatar.OwnedOutfits), &ownedOutfits); err != nil {
		ownedOutfits = []string{}
	}
	return &userv1.GetUserAvatarResp{
		Avatar: &userv1.UserAvatarData{
			UserId:        in.GetUserId(),
			BaseConfig:    &baseConfig,
			CurrentOutfit: &currentOutfit,
			OwnedOutfits:  ownedOutfits,
		},
	}, nil
}

// UpdateUserAvatar 创建或更新用户虚拟形象。
func UpdateUserAvatar(ctx context.Context, store UserStore, in *userv1.UpdateUserAvatarReq) (*userv1.UpdateUserAvatarResp, error) {
	if store == nil || in == nil {
		return nil, gorm.ErrInvalidDB
	}
	baseConfigJSON, err := json.Marshal(in.GetBaseConfig())
	if err != nil {
		return nil, err
	}
	currentOutfitJSON, err := json.Marshal(in.GetCurrentOutfit())
	if err != nil {
		return nil, err
	}
	existingAvatar, found, err := store.GetUserAvatar(ctx, in.GetUserId())
	if err != nil {
		return nil, err
	}
	avatarData := model.UserAvatar{
		UserID:        in.GetUserId(),
		BaseConfig:    string(baseConfigJSON),
		CurrentOutfit: string(currentOutfitJSON),
		OwnedOutfits:  "[]",
	}
	if !found {
		avatarData.ID = uuid.New().String()
		if err := store.CreateUserAvatar(ctx, &avatarData); err != nil {
			return nil, err
		}
	} else {
		avatarData.ID = existingAvatar.ID
		if err := store.UpdateUserAvatarFields(ctx, &existingAvatar, map[string]interface{}{
			"base_config":    string(baseConfigJSON),
			"current_outfit": string(currentOutfitJSON),
		}); err != nil {
			return nil, err
		}
	}
	var ownedOutfits []string
	_ = json.Unmarshal([]byte(avatarData.OwnedOutfits), &ownedOutfits)
	return &userv1.UpdateUserAvatarResp{
		Avatar: &userv1.UserAvatarData{
			UserId:        in.GetUserId(),
			BaseConfig:    in.GetBaseConfig(),
			CurrentOutfit: in.GetCurrentOutfit(),
			OwnedOutfits:  ownedOutfits,
		},
	}, nil
}
