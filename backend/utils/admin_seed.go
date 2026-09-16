package utils

import (
	"errors"
	"fmt"
	"log"
	"strings"

	"backend/model"
	"backend/pkg/conf"

	"gorm.io/gorm"
)

// ErrAdminBootstrapPasswordUnset 表示 admin.bootstrap.password 未配置，此时拒绝创建默认超管。
var ErrAdminBootstrapPasswordUnset = errors.New("admin.bootstrap.password 未配置")

// SeedAdminAccount 在从未存在过管理员时创建超管，由 RunAutoMigrate 在迁移末尾调用。
//
// 口令类配置不允许有兜底默认值：password 缺失时返回 ErrAdminBootstrapPasswordUnset 且不写库。
// 旧实现在这里回落到 "admin123"，而它当时唯一的调用方是免鉴权的
// POST /api/admin/bootstrap/account（internal/server/auth.go 的白名单），于是任何人在空库
// 部署上都能造出一个口令众所周知的 super_admin 再登录拿全权 token。该端点已连同 RPC 一起
// 删除，种账号现在只发生在运维手动执行的迁移里，不再有任何网络入口。
//
// Count 带 Unscoped 是必须的：AdminAccount 有软删除，只数未删行的话「把管理员全部软删」
// 就会让表看起来是空的而重新触发种账号；同时 username 上有 uniqueIndex，软删行仍占着索引，
// 再次 Create 必然撞唯一键。Unscoped 把这两个问题一并关掉。
func SeedAdminAccount(db *gorm.DB) error {
	if db == nil {
		return nil
	}
	var count int64
	if err := db.Unscoped().Model(&model.AdminAccount{}).Count(&count).Error; err != nil {
		return fmt.Errorf("count admin accounts: %w", err)
	}
	if count > 0 {
		return nil
	}
	bootstrap := conf.Get().Admin.Bootstrap
	if strings.TrimSpace(bootstrap.Password) == "" {
		return ErrAdminBootstrapPasswordUnset
	}
	username := strings.TrimSpace(bootstrap.Username)
	if username == "" {
		username = "admin"
	}
	row := model.AdminAccount{
		Username: username,
		// 明文只活在这一行；model.AdminAccount.BeforeSave 钩子会 bcrypt 后再落库。
		Password: bootstrap.Password,
		Role:     "super_admin",
	}
	if err := db.Create(&row).Error; err != nil {
		return fmt.Errorf("seed admin account: %w", err)
	}
	log.Printf("[admin] 已创建默认超管账号: %s", username)
	return nil
}
