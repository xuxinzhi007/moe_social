package user

import (
	"context"
	"errors"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
)

type CheckUserByEmailLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewCheckUserByEmailLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CheckUserByEmailLogic {
	return &CheckUserByEmailLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *CheckUserByEmailLogic) CheckUserByEmail(req *types.GetUserByEmailReq) (resp *types.GetUserByEmailResp, err error) {
	if req.Email == "" {
		return &types.GetUserByEmailResp{
			BaseResp: common.HandleError(errors.New("邮箱不能为空")),
		}, nil
	}

	// 调用 RPC 服务查找用户
	rpcResp, err := l.svcCtx.SuperRpcClient.GetUserByEmail(l.ctx, &rpc.GetUserByEmailReq{
		Email: req.Email,
	})

	if err != nil {
		// RPC 错误处理
		return &types.GetUserByEmailResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	return &types.GetUserByEmailResp{
		BaseResp: common.HandleRPCError(nil, "查询成功"),
		Data: types.User{
			Id:           rpcResp.User.Id,
			Username:     rpcResp.User.Username,
			Email:        rpcResp.User.Email,
			Avatar:       rpcResp.User.Avatar,
			CreatedAt:    rpcResp.User.CreatedAt,
			UpdatedAt:    rpcResp.User.UpdatedAt,
			IsVip:        rpcResp.User.IsVip,
			VipExpiresAt: rpcResp.User.VipExpiresAt,
			AutoRenew:    rpcResp.User.AutoRenew,
			Balance:      float64(rpcResp.User.Balance),
		},
	}, nil
}
