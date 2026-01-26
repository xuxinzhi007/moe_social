package chat

import (
	"context"
	"strings"

	"backend/api/internal/chathub"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type ChatOnlineBatchLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewChatOnlineBatchLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ChatOnlineBatchLogic {
	return &ChatOnlineBatchLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *ChatOnlineBatchLogic) ChatOnlineBatch(req *types.ChatOnlineBatchReq) (resp *types.ChatOnlineBatchResp, err error) {
	// Parse comma-separated user IDs
	ids := make([]string, 0)
	if req.UserIds != "" {
		for _, part := range strings.Split(req.UserIds, ",") {
			id := strings.TrimSpace(part)
			if id == "" {
				continue
			}
			ids = append(ids, id)
		}
	}

	// Query online status for each user
	online := make(map[string]bool, len(ids))
	for _, id := range ids {
		if id == "" {
			continue
		}
		online[id] = chathub.DefaultHub.IsOnline(id)
	}

	return &types.ChatOnlineBatchResp{
		BaseResp: types.BaseResp{
			Code:    200,
			Message: "success",
			Success: true,
		},
		Online: online,
	}, nil
}
