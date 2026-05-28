package achievement

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserUnlockedAchievementsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetUserUnlockedAchievementsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserUnlockedAchievementsLogic {
	return &GetUserUnlockedAchievementsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetUserUnlockedAchievementsLogic) GetUserUnlockedAchievements(req *types.GetUserUnlockedAchievementsReq) (*types.GetUserUnlockedAchievementsResp, error) {
	rpcResp, err := l.svcCtx.AchievementGW.GetUserUnlockedAchievements(l.ctx, &moe.GetUserUnlockedAchievementsReq{
		UserId: req.UserId,
	})
	if err != nil {
		return &types.GetUserUnlockedAchievementsResp{
			BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
		}, nil
	}

	return &types.GetUserUnlockedAchievementsResp{
		BaseResp: types.BaseResp{Code: 0, Message: "获取已解锁成就成功", Success: true},
		Data:     badgesFromRPC(rpcResp.Badges),
	}, nil
}
