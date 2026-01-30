package checkin

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserLevelLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetUserLevelLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserLevelLogic {
	return &GetUserLevelLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetUserLevelLogic) GetUserLevel(req *types.GetUserLevelReq) (resp *types.GetUserLevelResp, err error) {
	// 调用RPC服务获取用户等级
	rpcResp, err := l.svcCtx.SuperRpcClient.GetUserLevel(l.ctx, &super.GetUserLevelReq{
		UserId: req.UserId,
	})
	if err != nil {
		return &types.GetUserLevelResp{
			BaseResp: types.BaseResp{
				Code:    -1,
				Message: err.Error(),
				Success: false,
			},
		}, nil
	}

	// 转换响应格式
	return &types.GetUserLevelResp{
		BaseResp: types.BaseResp{
			Code:    0,
			Message: "获取用户等级成功",
			Success: true,
		},
		Data: types.UserLevelInfo{
			Level:        int(rpcResp.LevelInfo.Level),
			Experience:   int(rpcResp.LevelInfo.Experience),
			TotalExp:     int(rpcResp.LevelInfo.TotalExp),
			NextLevelExp: int(rpcResp.LevelInfo.NextLevelExp),
			LevelTitle:   rpcResp.LevelInfo.LevelTitle,
			BadgeUrl:     rpcResp.LevelInfo.BadgeUrl,
			Progress:     rpcResp.LevelInfo.Progress,
		},
	}, nil
}
