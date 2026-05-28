package achievement

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserAchievementsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetUserAchievementsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserAchievementsLogic {
	return &GetUserAchievementsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetUserAchievementsLogic) GetUserAchievements(req *types.GetUserAchievementsReq) (*types.GetUserAchievementsResp, error) {
	rpcResp, err := l.svcCtx.AchievementGW.GetUserAchievements(l.ctx, &moe.GetUserAchievementsReq{
		UserId: req.UserId,
	})
	if err != nil {
		return &types.GetUserAchievementsResp{
			BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
		}, nil
	}

	return &types.GetUserAchievementsResp{
		BaseResp: types.BaseResp{Code: 0, Message: "获取成就列表成功", Success: true},
		Data:     BadgesFromRPC(rpcResp.Badges),
	}, nil
}
