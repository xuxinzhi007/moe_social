package svc

import (
	"fmt"

	achievementapp "backend/internal/service/achievement"
	chatapp "backend/internal/service/chat"
	checkinapp "backend/internal/service/checkin"
	commentapp "backend/internal/service/comment"
	communityapp "backend/internal/service/community"
	giftapp "backend/internal/service/gift"
	landingapp "backend/internal/service/landing"
	moeadmin "backend/internal/service/moe"
	notifyapp "backend/internal/service/notify"
	postapp "backend/internal/service/post"
	userapp "backend/internal/service/user"
	"backend/rpc/internal/config"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type ServiceContext struct {
	Config         config.Config
	DB             *gorm.DB
	MoeAdmin       *moeadmin.AdminService
	LandingApp     *landingapp.AppService
	CheckinApp     *checkinapp.AppService
	AchievementApp *achievementapp.AppService
	PostApp        *postapp.AppService
	GiftApp        *giftapp.AppService
	UserApp        *userapp.AppService
	CommentApp     *commentapp.AppService
	CommunityApp   *communityapp.AppService
	ChatApp        *chatapp.AppService
	NotifyApp      *notifyapp.AppService
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

	db := utils.GetDB()
	out := &ServiceContext{
		Config:         c,
		DB:             db,
		MoeAdmin:       moeadmin.NewAdmin(db),
		LandingApp:     landingapp.New(db),
		CheckinApp:     checkinapp.New(db),
		AchievementApp: achievementapp.New(db),
		PostApp:        postapp.New(db, c.HandDrawRequireModeration),
		GiftApp:        giftapp.New(db),
		UserApp:        userapp.New(db),
		CommentApp:     commentapp.New(db),
		CommunityApp:   communityapp.New(db),
		ChatApp:        chatapp.New(db),
		NotifyApp:      notifyapp.New(db),
	}
	utils.StartPrivateMessageCleanup(out.DB)
	return out
}
