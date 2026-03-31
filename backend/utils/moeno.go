package utils

import (
	"crypto/rand"
	"fmt"

	"backend/model"

	"gorm.io/gorm"
)

// RandomMoeNo returns a 10-digit string (first digit 1–9).
func RandomMoeNo() (string, error) {
	buf := make([]byte, 10)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	out := make([]byte, 10)
	out[0] = byte('1' + int(buf[0])%9)
	for i := 1; i < 10; i++ {
		out[i] = byte('0' + int(buf[i])%10)
	}
	return string(out), nil
}

// EnsureUserMoeNo assigns a unique Moe number if the user does not have a valid one.
func EnsureUserMoeNo(db *gorm.DB, userID uint) (string, error) {
	var u model.User
	if err := db.Select("id", "moe_no").Where("id = ?", userID).First(&u).Error; err != nil {
		return "", err
	}
	if len(u.MoeNo) == 10 {
		return u.MoeNo, nil
	}
	for i := 0; i < 64; i++ {
		no, err := RandomMoeNo()
		if err != nil {
			continue
		}
		var n int64
		db.Model(&model.User{}).Where("moe_no = ?", no).Count(&n)
		if n > 0 {
			continue
		}
		if err := db.Model(&model.User{}).Where("id = ?", userID).Update("moe_no", no).Error; err != nil {
			continue
		}
		return no, nil
	}
	return "", fmt.Errorf("could not assign moe_no")
}

// BackfillAllUserMoeNos fills moe_no for users missing or invalid values (startup migration helper).
func BackfillAllUserMoeNos(db *gorm.DB) {
	if db == nil {
		return
	}
	var ids []uint
	_ = db.Model(&model.User{}).
		Where("moe_no = '' OR moe_no IS NULL OR CHAR_LENGTH(moe_no) <> ?", 10).
		Pluck("id", &ids).Error
	for _, id := range ids {
		_, _ = EnsureUserMoeNo(db, id)
	}
}
