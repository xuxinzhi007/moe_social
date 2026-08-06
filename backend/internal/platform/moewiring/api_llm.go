package moewiring

import (
	"backend/internal/adapter/moeconfig"
	"backend/internal/platform/appdb"
	llmapp "backend/internal/service/llm"
)

func LLMAPIInProcessEnabled() bool {
	return domainInProcessEnabled("moe.llm_api_in_process")
}

func NewAPILLMService() (*llmapp.AppService, error) {
	if !LLMAPIInProcessEnabled() {
		return nil, nil
	}
	db, err := appdb.Open()
	if err != nil {
		return nil, err
	}
	return llmapp.New(db, llmapp.Deps{
		Inference: moeconfig.InferenceFromViper(),
	}), nil
}
