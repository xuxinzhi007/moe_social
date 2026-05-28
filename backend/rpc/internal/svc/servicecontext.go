package svc

import (
	"fmt"

	"backend/internal/adapter/moeconfig"
	achievementapp "backend/internal/service/achievement"
	chatapp "backend/internal/service/chat"
	checkinapp "backend/internal/service/checkin"
	commentapp "backend/internal/service/comment"
	communityapp "backend/internal/service/community"
	giftapp "backend/internal/service/gift"
	landingapp "backend/internal/service/landing"
	llmapp "backend/internal/service/llm"
	moeadmin "backend/internal/service/moe"
	notifyapp "backend/internal/service/notify"
	postapp "backend/internal/service/post"
	userapp "backend/internal/service/user"
	"backend/rpc/internal/config"
	"backend/utils"

	"backend/internal/platform/moelog"
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
	LLMApp         *llmapp.AppService
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
		moelog.Error("Admin JWT 未配置（管理后台登录不可用）", "err", err)
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
		LLMApp:         llmapp.New(db, llmapp.Deps{Inference: moeconfig.InferenceFromViper()}),
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
