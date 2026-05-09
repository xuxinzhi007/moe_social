package utils

import (
	"time"

	"backend/model"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

// StartPrivateMessageCleanup 周期性硬删除已过期的私信（模型无软删）。
func StartPrivateMessageCleanup(db *gorm.DB) {
	if db == nil {
		return
	}
	go func() {
		t := time.NewTicker(6 * time.Hour)
		defer t.Stop()
		for range t.C {
			res := db.Unscoped().Where("expires_at < ?", time.Now()).Delete(&model.PrivateMessage{})
			if res.Error != nil {
				logx.Errorf("private_message cleanup: %v", res.Error)
				continue
			}
			if res.RowsAffected > 0 {
				logx.Infof("private_message cleanup: deleted %d rows", res.RowsAffected)
			}
		}
	}()
}
