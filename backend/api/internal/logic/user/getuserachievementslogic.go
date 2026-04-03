package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

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

func (l *GetUserAchievementsLogic) GetUserAchievements(req *types.GetUserAchievementsReq) (resp *types.GetUserAchievementsResp, err error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.GetUserAchievements(l.ctx, &super.GetUserAchievementsReq{
		UserId: req.UserId,
	})
	if err != nil {
		return &types.GetUserAchievementsResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	data := make([]types.UserBadgeProgressEntry, 0, len(rpcResp.Entries))
	for _, e := range rpcResp.Entries {
		data = append(data, types.UserBadgeProgressEntry{
			BadgeId:      e.BadgeId,
			CurrentCount: int(e.CurrentCount),
			IsUnlocked:   e.IsUnlocked,
			UnlockedAt:   e.UnlockedAt,
		})
	}

	return &types.GetUserAchievementsResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     data,
	}, nil
}
