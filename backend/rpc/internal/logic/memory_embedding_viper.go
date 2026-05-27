package logic

import (
	"sync"

	"github.com/spf13/viper"
)

var viperOnce sync.Once

func ensureViperConfig() {
	viperOnce.Do(func() {
		if viper.ConfigFileUsed() != "" {
			return
		}
		viper.SetConfigName("config")
		viper.SetConfigType("yaml")
		viper.AddConfigPath("./config")
		viper.AddConfigPath("../config")
		viper.AddConfigPath("../../config")
		_ = viper.ReadInConfig()
	})
}

func viperInferenceBaseURL() string {
	ensureViperConfig()
	if base := viper.GetString("llm_inference.base_url"); base != "" {
		return base
	}
	return viper.GetString("ollama.base_url")
}
