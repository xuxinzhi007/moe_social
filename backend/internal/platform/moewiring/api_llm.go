package moewiring

import (
	llmapp "backend/internal/service/llm"
	"backend/internal/adapter/moeconfig"
	"backend/pkg/localmodels"
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
	v := moeViper()
	var catalog []localmodels.CatalogEntry
	_ = v.UnmarshalKey("local_models.catalog", &catalog)
	storageDir := v.GetString("local_models.storage_dir")
	return llmapp.New(db, llmapp.Deps{
		Inference:              moeconfig.InferenceFromViper(),
		MemoryModel:            firstNonEmpty(v.GetString("llm_inference.memory_model"), v.GetString("ollama.memory_model")),
		MemorySummaryPrompt:    v.GetString("llm_inference.memory_summary_prompt"),
		MemoryExtractPrompt:    v.GetString("llm_inference.memory_extract_prompt"),
		LocalModelsStorageDir:  storageDir,
		LocalModelsCatalog:     catalog,
	}), nil
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}
