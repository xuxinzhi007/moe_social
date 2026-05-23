package achievement

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type EnsureUserAchievementsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewEnsureUserAchievementsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *EnsureUserAchievementsLogic {
	return &EnsureUserAchievementsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *EnsureUserAchievementsLogic) EnsureUserAchievements(req *types.EnsureUserAchievementsReq) (*types.EnsureUserAchievementsResp, error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.EnsureUserAchievements(l.ctx, &super.EnsureUserAchievementsReq{
		UserId: req.UserId,
	})
	if err != nil {
		return &types.EnsureUserAchievementsResp{
			BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
		}, nil
	}

	return &types.EnsureUserAchievementsResp{
		BaseResp: types.BaseResp{Code: 0, Message: "成就初始化成功", Success: true},
		Data: types.EnsureUserAchievementsData{
			NewAchievements: unlocksFromRPC(rpcResp.NewAchievements),
		},
	}, nil
}
