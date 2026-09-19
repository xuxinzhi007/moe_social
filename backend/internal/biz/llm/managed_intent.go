package llmbiz

import (
	"encoding/json"

	"backend/model"
)

// rememberRequest keeps older request IDs durable across later synchronizations.
// Replaying an old request returns current state, never reinstates an old prompt.
func rememberRequest(row *model.LLMManagedModel, requestID, intent, hash string) error {
	history := map[string]string{}
	if row.RequestHashes != "" {
		if err := json.Unmarshal([]byte(row.RequestHashes), &history); err != nil {
			return llmError(503, "模型请求记录不可读取")
		}
	}
	if history == nil {
		history = map[string]string{}
	}
	if row.RequestID != "" {
		history[row.RequestID] = row.Intent + ":" + row.IntentHash
	}
	value := intent + ":" + hash
	if previous, ok := history[requestID]; ok {
		if previous == value {
			return errReplay
		}
		return llmError(409, "request_id 已用于不同意图")
	}
	history[requestID] = value
	encoded, err := json.Marshal(history)
	if err != nil {
		return err
	}
	row.RequestHashes = string(encoded)
	return nil
}
