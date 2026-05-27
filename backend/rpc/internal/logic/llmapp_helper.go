package logic

import (
	"backend/internal/adapter/moeconfig"
	llmapp "backend/internal/service/llm"

	"gorm.io/gorm"
)

func newLLMApp(db *gorm.DB) *llmapp.AppService {
	return llmapp.New(db, llmapp.Deps{Inference: moeconfig.InferenceFromViper()})
}
