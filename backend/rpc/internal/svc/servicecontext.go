package svc

import (
	"fmt"

	"backend/rpc/internal/config"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type ServiceContext struct {
	Config config.Config
	DB     *gorm.DB
}

func NewServiceContext(c config.Config, migrateOpts utils.MigrateOptions) *ServiceContext {
	// 初始化配置
	if err := utils.InitConfig(); err != nil {
		panic(err)
	}
	if err := utils.LoadJWTFromViper(); err != nil {
		panic(fmt.Sprintf("JWT 配置无效: %v", err))
	}
	if err := utils.LoadAdminJWTFromViper(); err != nil {
		logx.Errorf("Admin JWT 未配置: %v（管理后台登录不可用）", err)
	}

	// 初始化数据库连接（-migrate / -migrate-models：见 rpc/super.go）
	if err := utils.InitDBWithMigrate(migrateOpts); err != nil {
		panic(err)
	}

	out := &ServiceContext{
		Config: c,
		DB:     utils.GetDB(),
	}
	utils.StartPrivateMessageCleanup(out.DB)
	return out
}
