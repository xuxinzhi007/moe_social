package moewiring

import (
	"backend/internal/platform/appdb"
	chatapp "backend/internal/service/chat"
)

// ChatAPIInProcessEnabled config.yaml: moe.chat_api_in_process
func ChatAPIInProcessEnabled() bool {
	return domainInProcessEnabled("moe.chat_api_in_process")
}

// NewAPIChatService API 进程内 Chat 应用服务。
func NewAPIChatService() (*chatapp.AppService, error) {
	if !ChatAPIInProcessEnabled() {
		return nil, nil
	}
	db, err := appdb.Open()
	if err != nil {
		return nil, err
	}
	return chatapp.New(db), nil
}
