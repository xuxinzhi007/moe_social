package moewiring

import (
	chatapp "backend/internal/service/chat"
	"backend/utils"
)

// ChatAPIInProcessEnabled config.yaml: moe.chat_api_in_process
func ChatAPIInProcessEnabled() bool {
	if SingleProcessEnabled() || APIInProcessEnabled() {
		return boolOr(moeViper(), []string{"moe.chat_api_in_process"}, true)
	}
	return boolOr(moeViper(), []string{"moe.chat_api_in_process"}, false)
}

// NewAPIChatService API 进程内 Chat 应用服务。
func NewAPIChatService() (*chatapp.AppService, error) {
	if !ChatAPIInProcessEnabled() {
		return nil, nil
	}
	if err := utils.EnsureDB(); err != nil {
		return nil, err
	}
	db := utils.GetDB()
	if db == nil {
		return nil, nil
	}
	return chatapp.New(db), nil
}
