package userbiz

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"backend/model"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

// DeleteUser 注销账号（脱敏后软删）。
func DeleteUser(ctx context.Context, store UserStore, in *moe.DeleteUserReq) (*moe.DeleteUserResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := parseUserIDString(in.GetUserId())
	if err != nil {
		return nil, err
	}
	user, err := store.GetUserByID(ctx, userID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if err := scrubUserBeforeDelete(&user); err != nil {
		return nil, err
	}
	if err := store.SaveUser(ctx, &user); err != nil {
		return nil, err
	}
	if err := store.DeleteUserHard(ctx, user.ID); err != nil {
		return nil, err
	}
	return &moe.DeleteUserResp{}, nil
}

func scrubUserBeforeDelete(user *model.User) error {
	if user == nil {
		return fmt.Errorf("user is nil")
	}
	ts := time.Now().Unix()
	user.Username = fmt.Sprintf("deleted_%d", user.ID)
	user.Email = fmt.Sprintf("deleted_%d_%d@deleted.local", user.ID, ts)
	user.WechatOpenID = nil
	user.WechatUnionID = ""
	user.WechatNickname = ""
	user.FeishuOpenID = nil
	user.FeishuEmail = ""
	user.FeishuName = ""
	user.Password = randomAccountPassword()
	return nil
}

func randomAccountPassword() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}
