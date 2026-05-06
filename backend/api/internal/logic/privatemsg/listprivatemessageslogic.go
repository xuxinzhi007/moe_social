// Code scaffolded by goctl. Safe to edit.

package privatemsg

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type ListPrivateMessagesLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewListPrivateMessagesLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListPrivateMessagesLogic {
	return &ListPrivateMessagesLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *ListPrivateMessagesLogic) ListPrivateMessages(req *types.ListPrivateMessagesReq) (resp *types.ListPrivateMessagesResp, err error) {
	viewerID, err := ctxUserIDString(l.ctx)
	if err != nil {
		return nil, err
	}

	rpcResp, err := l.svcCtx.SuperRpcClient.ListPrivateMessages(l.ctx, &super.ListPrivateMessagesReq{
		ViewerId: viewerID,
		PeerId:   req.PeerUserId,
		BeforeId: req.BeforeId,
		Limit:    int32(req.Limit),
	})
	if err != nil {
		return &types.ListPrivateMessagesResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	items := make([]types.PrivateMessageItem, 0, len(rpcResp.Messages))
	for _, m := range rpcResp.Messages {
		if m == nil {
			continue
		}
		items = append(items, privateMessageItemFromProto(m))
	}

	return &types.ListPrivateMessagesResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     items,
		HasMore:  rpcResp.HasMore,
	}, nil
}
