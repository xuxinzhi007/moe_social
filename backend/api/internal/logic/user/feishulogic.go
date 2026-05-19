package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type FeishuLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewFeishuLogic(ctx context.Context, svcCtx *svc.ServiceContext) *FeishuLogic {
	return &FeishuLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *FeishuLogic) Bind(userID string, feishuEmail string) (*types.BindFeishuResp, error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.BindFeishu(l.ctx, &super.BindFeishuReq{
		UserId:      userID,
		FeishuEmail: feishuEmail,
	})
	if err != nil {
		return &types.BindFeishuResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	return &types.BindFeishuResp{
		BaseResp: common.HandleRPCError(nil, "飞书绑定成功"),
		Data:     rpcUserToTypes(rpcResp.User),
	}, nil
}

func (l *FeishuLogic) Unbind(userID string) (*types.UnbindFeishuResp, error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.UnbindFeishu(l.ctx, &super.UnbindFeishuReq{
		UserId: userID,
	})
	if err != nil {
		return &types.UnbindFeishuResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	return &types.UnbindFeishuResp{
		BaseResp: common.HandleRPCError(nil, "已解除飞书绑定"),
		Data:     rpcUserToTypes(rpcResp.User),
	}, nil
}

func (l *FeishuLogic) SendTestCard(userID string) (*types.SendFeishuTestCardResp, error) {
	_, err := l.svcCtx.SuperRpcClient.SendFeishuTestCard(l.ctx, &super.SendFeishuTestCardReq{
		UserId: userID,
	})
	if err != nil {
		return &types.SendFeishuTestCardResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	return &types.SendFeishuTestCardResp{
		BaseResp: common.HandleRPCError(nil, "测试卡片已发送，请在飞书客户端查看"),
	}, nil
}
