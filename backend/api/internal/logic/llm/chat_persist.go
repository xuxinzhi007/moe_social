package llm

import (
	"context"
	"strconv"
	"strings"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"
)

// persistChatTurnsAfterReply 将本轮 user/assistant 写入 RPC 会话表（需 session_id）。
func persistChatTurnsAfterReply(
	svcCtx *svc.ServiceContext,
	userID, sessionID, sourceMsgID, model string,
	reqMessages []types.LlmMessage,
	assistantContent string,
) {
	if strings.TrimSpace(sessionID) == "" || strings.TrimSpace(userID) == "" {
		return
	}
	lastUser := ""
	for i := len(reqMessages) - 1; i >= 0; i-- {
		if reqMessages[i].Role == "user" && strings.TrimSpace(reqMessages[i].Content) != "" {
			lastUser = reqMessages[i].Content
			break
		}
	}
	if lastUser != "" {
		recordChatTurnAsync(svcCtx, userID, sessionID, sourceMsgID, model, "user", lastUser)
	}
	if strings.TrimSpace(assistantContent) != "" {
		recordChatTurnAsync(svcCtx, userID, sessionID, sourceMsgID, model, "assistant", assistantContent)
	}
}

func recordChatTurnAsync(svcCtx *svc.ServiceContext, userID, sessionID, sourceMsgID, model, role, content string) {
	if svcCtx == nil || svcCtx.SuperRpcClient == nil {
		return
	}
	uid, err := strconv.ParseUint(strings.TrimSpace(userID), 10, 64)
	if err != nil || uid == 0 || strings.TrimSpace(sessionID) == "" {
		return
	}
	go func() {
		ctx := context.Background()
		_, _ = svcCtx.SuperRpcClient.RecordLlmChatTurn(ctx, &super.RecordLlmChatTurnReq{
			UserId:      uid,
			SessionId:   sessionID,
			SourceMsgId: sourceMsgID,
			Model:       model,
			Role:        role,
			Content:     content,
		})
	}()
}
