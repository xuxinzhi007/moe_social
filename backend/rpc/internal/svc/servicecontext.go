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

func NewServiceContext(c config.Config, autoMigrate bool) *ServiceContext {
	// 初始化配置
	if err := utils.InitConfig(); err != nil {
		panic(err)
	}
	if err := utils.LoadJWTFromViper(); err != nil {
		panic(fmt.Sprintf("JWT 配置无效: %v", err))
	}

	// 初始化数据库连接（autoMigrate：见 rpc main 的 -migrate）
	if err := utils.InitDB(autoMigrate); err != nil {
		panic(err)
	}

	out := &ServiceContext{
		Config: c,
		DB:     utils.GetDB(),
	}
	if err := utils.EnsureAchievementSeeds(out.DB); err != nil {
		logx.Errorf("成就定义启动检查失败（若表不存在请在 VPS 执行 rpc -migrate）: %v", err)
	} else {
		logx.Info("成就定义种子检查完成")
	}
	utils.StartPrivateMessageCleanup(out.DB)
	return out
}
