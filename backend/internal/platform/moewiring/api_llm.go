package moewiring

import (
	llmapp "backend/internal/service/llm"
	"backend/internal/adapter/moeconfig"
	"backend/utils"
)

func LLMAPIInProcessEnabled() bool {
	if SingleProcessEnabled() || APIInProcessEnabled() {
		return boolOr(moeViper(), []string{"moe.llm_api_in_process"}, true)
	}
	return boolOr(moeViper(), []string{"moe.llm_api_in_process"}, false)
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
