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

func NewServiceContext(c config.Config) *ServiceContext {
	// 初始化配置
	if err := utils.InitConfig(); err != nil {
		panic(err)
	}
	
	// 初始化数据库连接
	if err := utils.InitDB(); err != nil {
		panic(err)
	}

	return &ServiceContext{
		Config: c,
		DB:     utils.GetDB(),
	}
}
