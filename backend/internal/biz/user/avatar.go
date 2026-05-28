package userbiz

import (
	"context"
	"encoding/json"

	"backend/model"
	"backend/rpc/pb/moe"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

func defaultUserAvatarData(userID string) *moe.UserAvatarData {
	return &moe.UserAvatarData{
		UserId: userID,
		BaseConfig: &moe.AvatarBaseConfig{
			FaceShape: "face_1",
			SkinColor: "#FDBCB4",
			EyeType:   "eyes_1",
			HairStyle: "hair_1",
			HairColor: "#8B4513",
		},
		CurrentOutfit: &moe.AvatarOutfitConfig{
			Clothes:     "clothes_1",
			Accessories: []string{},
			Background:  "default",
		},
		OwnedOutfits: []string{},
	}
}

// GetUserAvatar 获取用户虚拟形象；无记录时返回默认形象。
func GetUserAvatar(ctx context.Context, store UserStore, in *moe.GetUserAvatarReq) (*moe.GetUserAvatarResp, error) {
	if store == nil || in == nil {
		return nil, gorm.ErrInvalidDB
	}
	userAvatar, found, err := store.GetUserAvatar(ctx, in.GetUserId())
	if err != nil {
		return nil, err
	}
	if !found {
		return &moe.GetUserAvatarResp{Avatar: defaultUserAvatarData(in.GetUserId())}, nil
	}
	var baseConfig moe.AvatarBaseConfig
	if err := json.Unmarshal([]byte(userAvatar.BaseConfig), &baseConfig); err != nil {
		return nil, err
	}
	var currentOutfit moe.AvatarOutfitConfig
	if err := json.Unmarshal([]byte(userAvatar.CurrentOutfit), &currentOutfit); err != nil {
		return nil, err
	}
	var ownedOutfits []string
	if err := json.Unmarshal([]byte(userAvatar.OwnedOutfits), &ownedOutfits); err != nil {
		ownedOutfits = []string{}
	}
	return &moe.GetUserAvatarResp{
		Avatar: &moe.UserAvatarData{
			UserId:        in.GetUserId(),
			BaseConfig:    &baseConfig,
			CurrentOutfit: &currentOutfit,
			OwnedOutfits:  ownedOutfits,
		},
	}, nil
}

// UpdateUserAvatar 创建或更新用户虚拟形象。
func UpdateUserAvatar(ctx context.Context, store UserStore, in *moe.UpdateUserAvatarReq) (*moe.UpdateUserAvatarResp, error) {
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
	return &moe.UpdateUserAvatarResp{
		Avatar: &moe.UserAvatarData{
			UserId:        in.GetUserId(),
			BaseConfig:    in.GetBaseConfig(),
			CurrentOutfit: in.GetCurrentOutfit(),
			OwnedOutfits:  ownedOutfits,
		},
	}, nil
}
