package moewiring

import (
	"backend/internal/platform/apicomm"
	"backend/internal/platform/appdb"
	llmapp "backend/internal/service/llm"
	"backend/pkg/conf"
)

func LLMAPIInProcessEnabled() bool {
	return conf.DomainInProcess("llm")
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
		UserID:          apicomm.UserIDUint,
		Inference:       conf.Inference(),
		ModelManagement: conf.InferenceModelManagement(),
	}), nil
}
