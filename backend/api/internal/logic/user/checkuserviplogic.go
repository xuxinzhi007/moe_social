package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type CheckUserVipLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewCheckUserVipLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CheckUserVipLogic {
	return &CheckUserVipLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *CheckUserVipLogic) CheckUserVip(req *types.CheckUserVipReq) (resp *types.CheckUserVipResp, err error) {
	// 调用RPC服务检查用户VIP状态
	rpcResp, err := l.svcCtx.SuperRpcClient.CheckUserVip(l.ctx, &super.CheckUserVipReq{
		UserId: req.UserId,
	})
	if err != nil {
		return &types.CheckUserVipResp{
			BaseResp: common.HandleRPCError(err, ""),
			Data:     false,
		}, nil
	}

	return &types.CheckUserVipResp{
		BaseResp: common.HandleRPCError(nil, "检查用户VIP状态成功"),
		Data:     rpcResp.IsVip,
	}, nil
}
