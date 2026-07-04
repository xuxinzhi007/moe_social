package moewiring

import (
	"backend/internal/adapter/moeconfig"
	llmapp "backend/internal/service/llm"
	"backend/utils"
)

func LLMAPIInProcessEnabled() bool {
	return domainInProcessEnabled("moe.llm_api_in_process")
}

func NewAPILLMService() (*llmapp.AppService, error) {
	if !LLMAPIInProcessEnabled() {
		return nil, nil
	}
	if err := utils.EnsureDB(); err != nil {
		return nil, err
	}
	db := utils.GetDB()
	if db == nil {
		return nil, nil
	}
	return llmapp.New(db, llmapp.Deps{
		Inference: moeconfig.InferenceFromViper(),
	}), nil
}
