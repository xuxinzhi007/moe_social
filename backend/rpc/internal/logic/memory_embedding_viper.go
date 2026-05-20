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

func viperOllamaBaseURL() string {
	ensureViperConfig()
	return viper.GetString("ollama.base_url")
}
