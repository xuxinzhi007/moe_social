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
func DeleteUser(ctx context.Context, db *gorm.DB, in *moe.DeleteUserReq) (*moe.DeleteUserResp, error) {
	var user model.User
	if err := db.WithContext(ctx).First(&user, in.GetUserId()).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if err := scrubUserBeforeDelete(&user); err != nil {
		return nil, err
	}
	if err := db.WithContext(ctx).Save(&user).Error; err != nil {
		return nil, err
	}
	if err := db.WithContext(ctx).Delete(&user).Error; err != nil {
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
