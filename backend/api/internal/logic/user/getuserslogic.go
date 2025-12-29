package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUsersLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetUsersLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUsersLogic {
	return &GetUsersLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetUsersLogic) GetUsers(req *types.GetUsersReq) (resp *types.GetUsersResp, err error) {
	// 调用RPC服务获取用户列表
	rpcResp, err := l.svcCtx.SuperRpcClient.GetUsers(l.ctx, &super.GetUsersReq{
		Page:     int32(req.Page),
		PageSize: int32(req.PageSize),
	})
	if err != nil {
		return &types.GetUsersResp{
			BaseResp: common.HandleRPCError(err, ""),
			Data:     nil,
			Total:    0,
		}, nil
	}

	// 转换为API响应格式
	respUsers := make([]types.User, 0, len(rpcResp.Users))
	for _, user := range rpcResp.Users {
		respUsers = append(respUsers, types.User{
			Id:           user.Id,
			Username:     user.Username,
			Email:        user.Email,
			Avatar:       user.Avatar,
			CreatedAt:    user.CreatedAt,
			UpdatedAt:    user.UpdatedAt,
			IsVip:        user.IsVip,
			VipExpiresAt: user.VipExpiresAt,
			AutoRenew:    user.AutoRenew,
		})
	}

	return &types.GetUsersResp{
		BaseResp: common.HandleRPCError(nil, "获取用户列表成功"),
		Data:     respUsers,
		Total:    int(rpcResp.Total),
	}, nil
}
