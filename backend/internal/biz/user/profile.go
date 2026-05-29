package userbiz

import (
	"context"
	"errors"
	"strconv"
	"strings"
	"time"

	userv1 "backend/api/user/v1"
	"backend/utils"

	"gorm.io/gorm"
)

// UpdateUserInfo 更新用户资料字段。
func UpdateUserInfo(ctx context.Context, store ProfileStore, in *userv1.UpdateUserInfoReq) (*userv1.UpdateUserInfoResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := strconv.ParseUint(strings.TrimSpace(in.GetUserId()), 10, 32)
	if err != nil || userID == 0 {
		return nil, ErrInvalidArgument
	}

	user, err := store.GetUserByID(ctx, uint(userID))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}

	if in.GetUsername() != "" {
		user.Username = in.GetUsername()
	}
	if in.GetEmail() != "" {
		user.Email = in.GetEmail()
	}
	if in.GetAvatar() != "" {
		user.Avatar = utils.NormalizeAvatarForStorage(in.GetAvatar())
	}
	if in.GetSignature() != "" {
		if len(in.GetSignature()) > 100 {
			return nil, ErrInvalidArgument
		}
		user.Signature = in.GetSignature()
	}
	if in.GetGender() != "" {
		valid := false
		for _, g := range []string{"male", "female", "secret"} {
			if in.GetGender() == g {
				valid = true
				break
			}
		}
		if !valid {
			return nil, ErrInvalidArgument
		}
		user.Gender = in.GetGender()
	}
	if in.GetBirthday() != "" {
		birthday, err := time.Parse("2006-01-02", in.GetBirthday())
		if err != nil {
			return nil, ErrInvalidArgument
		}
		if birthday.After(time.Now()) {
			return nil, ErrInvalidArgument
		}
		user.Birthday = &birthday
	}
	if in.GetInventory() != "" {
		user.Inventory = in.GetInventory()
	}
	if in.GetClearEquippedFrame() {
		user.EquippedFrameId = ""
	} else if in.GetEquippedFrameId() != "" {
		user.EquippedFrameId = in.GetEquippedFrameId()
	}
	if mt := strings.TrimSpace(in.GetMessageRetention()); mt != "" {
		switch strings.ToLower(mt) {
		case "auto", "default", "0":
			user.MessageRetentionChoice = 0
		case "7":
			user.MessageRetentionChoice = 7
		case "30":
			user.MessageRetentionChoice = 30
		default:
			return nil, ErrInvalidArgument
		}
	}

	updates := map[string]interface{}{}
	if in.GetUsername() != "" {
		updates["username"] = user.Username
	}
	if in.GetEmail() != "" {
		updates["email"] = user.Email
	}
	if in.GetAvatar() != "" {
		updates["avatar"] = user.Avatar
	}
	if in.GetSignature() != "" {
		updates["signature"] = user.Signature
	}
	if in.GetGender() != "" {
		updates["gender"] = user.Gender
	}
	if in.GetBirthday() != "" {
		updates["birthday"] = user.Birthday
	}
	if in.GetInventory() != "" {
		updates["inventory"] = user.Inventory
	}
	if in.GetClearEquippedFrame() {
		updates["equipped_frame_id"] = ""
	} else if in.GetEquippedFrameId() != "" {
		updates["equipped_frame_id"] = user.EquippedFrameId
	}
	if strings.TrimSpace(in.GetMessageRetention()) != "" {
		updates["message_retention_choice"] = user.MessageRetentionChoice
	}

	if len(updates) == 0 {
		user, _ = store.ReloadUser(ctx, uint(userID))
		return &userv1.UpdateUserInfoResp{User: ModelToUserV1(&user)}, nil
	}
	if err := store.UpdateUserFields(ctx, uint(userID), updates); err != nil {
		return nil, err
	}
	user, _ = store.ReloadUser(ctx, uint(userID))
	return &userv1.UpdateUserInfoResp{User: ModelToUserV1(&user)}, nil
}
