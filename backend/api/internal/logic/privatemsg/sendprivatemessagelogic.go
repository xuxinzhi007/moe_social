// Code scaffolded by goctl. Safe to edit.

package privatemsg

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/logic/chat"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type SendPrivateMessageLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewSendPrivateMessageLogic(ctx context.Context, svcCtx *svc.ServiceContext) *SendPrivateMessageLogic {
	return &SendPrivateMessageLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *SendPrivateMessageLogic) SendPrivateMessage(req *types.SendPrivateMessageReq) (resp *types.SendPrivateMessageResp, err error) {
	senderID, err := ctxUserIDString(l.ctx)
	if err != nil {
		return nil, err
	}

	rpcResp, err := l.svcCtx.SuperRpcClient.SendPrivateMessage(l.ctx, &super.SendPrivateMessageReq{
		SenderId:    senderID,
		ReceiverId:  req.ReceiverId,
		Body:        req.Body,
		ImagePaths:  req.ImagePaths,
	})
	if err != nil {
		return &types.SendPrivateMessageResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}
	if rpcResp.Message == nil {
		return &types.SendPrivateMessageResp{
			BaseResp: common.HandleRPCError(nil, "发送失败"),
		}, nil
	}

	senderName, senderAvatar := chat.ResolvePrivateMessageSenderProfile(
		l.ctx, l.svcCtx, senderID, rpcResp.Message, "",
	)
	chat.DeliverPrivateMessageRealTime(l.ctx, l.svcCtx, senderID, req.ReceiverId, req.Body, senderName, senderAvatar, rpcResp.Message)

	return &types.SendPrivateMessageResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     privateMessageItemFromProto(rpcResp.Message),
	}, nil
}
