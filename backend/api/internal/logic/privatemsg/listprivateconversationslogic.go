// Code scaffolded by goctl. Safe to edit.
// goctl 1.10.1

package privatemsg

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type ListPrivateConversationsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewListPrivateConversationsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListPrivateConversationsLogic {
	return &ListPrivateConversationsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *ListPrivateConversationsLogic) ListPrivateConversations(req *types.ListPrivateConversationsReq) (resp *types.ListPrivateConversationsResp, err error) {
	viewerID, err := ctxUserIDString(l.ctx)
	if err != nil {
		return nil, err
	}

	rpcResp, err := l.svcCtx.ChatGW.ListPrivateConversations(l.ctx, &super.ListPrivateConversationsReq{
		ViewerId: viewerID,
		Limit:    int32(req.Limit),
		Offset:   int32(req.Offset),
	})
	if err != nil {
		return &types.ListPrivateConversationsResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	items := make([]types.PrivateConversationItem, 0, len(rpcResp.Conversations))
	for _, c := range rpcResp.Conversations {
		if c == nil {
			continue
		}
		items = append(items, privateConversationItemFromProto(c))
	}

	return &types.ListPrivateConversationsResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     items,
		Total:    int(rpcResp.GetTotal()),
		Limit:    int(rpcResp.GetLimit()),
		Offset:   int(rpcResp.GetOffset()),
		HasMore:  rpcResp.GetHasMore(),
	}, nil
}
