package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetFollowersLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetFollowersLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetFollowersLogic {
	return &GetFollowersLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetFollowersLogic) GetFollowers(req *types.GetFollowersReq) (resp *types.GetFollowersResp, err error) {
	l.Debug("获取粉丝列表请求:", req)
	
	// 调用RPC服务
	rpcResp, err := l.svcCtx.SuperRpcClient.GetFollowers(l.ctx, &super.GetFollowersReq{
		UserId:   req.UserId,
		Page:     int32(req.Page),
		PageSize: int32(req.PageSize),
	})
	
	if err != nil {
		l.Error("调用获取粉丝列表RPC服务失败:", err)
		return &types.GetFollowersResp{
			BaseResp: common.HandleError(err),
			Data:     nil,
			Total:    0,
		}, nil
	}
	
	// 转换为API响应格式
	respUsers := make([]types.User, 0, len(rpcResp.Users))
	for _, user := range rpcResp.Users {
		respUser := types.User{
			Id:           user.Id,
			Username:     user.Username,
			Email:        user.Email,
			Avatar:       user.Avatar,
			CreatedAt:    user.CreatedAt,
			UpdatedAt:    user.UpdatedAt,
			IsVip:        user.IsVip,
			VipExpiresAt: user.VipExpiresAt,
			AutoRenew:    user.AutoRenew,
			Balance:      float64(user.Balance),
		}
		respUsers = append(respUsers, respUser)
	}
	
	l.Debug("获取粉丝列表成功:", len(respUsers), "个粉丝，总数:", rpcResp.Total)
	
	return &types.GetFollowersResp{
		BaseResp: common.HandleError(nil),
		Data:     respUsers,
		Total:    int(rpcResp.Total),
	}, nil
}
