package llmbiz

import (
	"context"

	"backend/pkg/llminference"
	"backend/rpc/pb/moe"

	"google.golang.org/grpc"
)

// PlatformChatMessage LLM 对话消息。
type PlatformChatMessage struct {
	Role    string
	Content string
}

// PlatformChatInput POST /api/llm/chat 业务入参。
type PlatformChatInput struct {
	Model               string
	Messages            []PlatformChatMessage
	SessionId           string
	SourceMsgId         string
	ClientMemoryApplied bool
	Stream              bool
	Temperature         float64
	TopP                float64
	MaxTokens           int
	RepeatPenalty       float64
}

// PlatformChatOutcome compat chat 响应字段。
type PlatformChatOutcome struct {
	Content        string
	RemainingRatio float64
	Summarized     bool
	Code           int
	Message        string
	Success        bool
}

// PlatformChatGateway 平台 chat 记忆与会话持久化 RPC。
type PlatformChatGateway interface {
	GetUserMemories(ctx context.Context, in *moe.GetUserMemoriesReq, opts ...grpc.CallOption) (*moe.GetUserMemoriesResp, error)
	GetUserMemoryProfiles(ctx context.Context, in *moe.GetUserMemoryProfilesReq, opts ...grpc.CallOption) (*moe.GetUserMemoryProfilesResp, error)
	UpsertUserMemory(ctx context.Context, in *moe.UpsertUserMemoryReq, opts ...grpc.CallOption) (*moe.UpsertUserMemoryResp, error)
	GetAiUserConfig(ctx context.Context, in *moe.GetAiUserConfigReq, opts ...grpc.CallOption) (*moe.GetAiUserConfigResp, error)
	RecordLlmChatTurn(ctx context.Context, in *moe.RecordLlmChatTurnReq, opts ...grpc.CallOption) (*moe.RecordLlmChatTurnResp, error)
}

// ChatCompleter 非流式推理补全（nil 时 ExecutePlatformChat 使用 PostChatCompletion）。
type ChatCompleter func(ctx context.Context, model string, messages []ChatMessage, opts ChatOptions) (string, error)

// PlatformChatDeps 平台 chat 执行依赖。
type PlatformChatDeps struct {
	Inference           llminference.Config
	MemoryModel         string
	MemorySummaryPrompt string
	MemoryExtractPrompt string
	MemoryBudget        MemoryBudgetConfig
	Gateway             PlatformChatGateway
	ChatComplete        ChatCompleter
}
