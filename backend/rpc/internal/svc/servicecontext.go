package svc

import (
	"backend/rpc/internal/config"
	"backend/utils"

	"gorm.io/gorm"
)

type ServiceContext struct {
	Config config.Config
	DB     *gorm.DB
}

func NewServiceContext(c config.Config, autoMigrate bool) *ServiceContext {
	// 初始化配置
	if err := utils.InitConfig(); err != nil {
		panic(err)
	}

	// 初始化数据库连接（autoMigrate：见 rpc main 的 -migrate）
	if err := utils.InitDB(autoMigrate); err != nil {
		panic(err)
	}

	return &ServiceContext{
		Config: c,
		DB:     utils.GetDB(),
	}
}
