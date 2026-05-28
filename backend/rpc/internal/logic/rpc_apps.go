package logic

import (
	"backend/internal/adapter/moeconfig"
	adminapp "backend/internal/service/admin"
	llmapp "backend/internal/service/llm"
	vipadmin "backend/internal/service/vip"

	"gorm.io/gorm"
)

func newAdminApp(db *gorm.DB) *adminapp.AppService {
	return adminapp.New(db)
}

func newVipAdminApp(db *gorm.DB) *vipadmin.AdminService {
	return vipadmin.NewAdmin(db)
}

func newLLMApp(db *gorm.DB) *llmapp.AppService {
	return llmapp.New(db, llmapp.Deps{Inference: moeconfig.InferenceFromViper()})
}
