// Code scaffolded by goctl. Safe to edit.
// goctl 1.10.1

package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type SendFeishuTestCardLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewSendFeishuTestCardLogic(ctx context.Context, svcCtx *svc.ServiceContext) *SendFeishuTestCardLogic {
	return &SendFeishuTestCardLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *SendFeishuTestCardLogic) SendFeishuTestCard(req *types.EmptyReq) (resp *types.SendFeishuTestCardResp, err error) {
	userID, err := common.UserIDString(l.ctx)
	if err != nil {
		return nil, err
	}
	_, rpcErr := l.svcCtx.SuperRpcClient.SendFeishuTestCard(l.ctx, &super.SendFeishuTestCardReq{
		UserId: userID,
	})
	if rpcErr != nil {
		return &types.SendFeishuTestCardResp{BaseResp: common.HandleRPCError(rpcErr, "")}, nil
	}
	return &types.SendFeishuTestCardResp{
		BaseResp: common.HandleRPCError(nil, "测试卡片已发送，请在飞书客户端查看"),
	}, nil
}
