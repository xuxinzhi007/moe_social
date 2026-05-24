package utils

import (
	"log"
	"strings"

	"backend/model"

	"github.com/spf13/viper"
	"gorm.io/gorm"
)

// SeedAdminAccount 首次迁移时创建默认超管（仅当表为空）。
func SeedAdminAccount(db *gorm.DB) {
	if db == nil {
		return
	}
	var count int64
	if err := db.Model(&model.AdminAccount{}).Count(&count).Error; err != nil {
		log.Printf("[admin] count accounts: %v", err)
		return
	}
	if count > 0 {
		return
	}
	username := strings.TrimSpace(viper.GetString("admin.bootstrap.username"))
	if username == "" {
		username = "admin"
	}
	password := viper.GetString("admin.bootstrap.password")
	if strings.TrimSpace(password) == "" {
		password = "admin123"
		log.Printf("[admin] 使用默认超管密码 admin123，请尽快在配置中修改 admin.bootstrap.password 并登录后改密")
	}
	row := model.AdminAccount{
		Username: username,
		Password: password,
		Role:     "super_admin",
	}
	if err := db.Create(&row).Error; err != nil {
		log.Printf("[admin] seed account failed: %v", err)
		return
	}
	log.Printf("[admin] 已创建默认超管账号: %s", username)
}
