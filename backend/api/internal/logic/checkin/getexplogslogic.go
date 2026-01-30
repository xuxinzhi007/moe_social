package checkin

import (
	"context"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetExpLogsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetExpLogsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetExpLogsLogic {
	return &GetExpLogsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetExpLogsLogic) GetExpLogs(req *types.GetExpLogsReq) (resp *types.GetExpLogsResp, err error) {
	// 调用RPC服务获取经验日志
	rpcResp, err := l.svcCtx.SuperRpcClient.GetExpLogs(l.ctx, &super.GetExpLogsReq{
		UserId:   req.UserId,
		Page:     int32(req.Page),
		PageSize: int32(req.PageSize),
	})
	if err != nil {
		return &types.GetExpLogsResp{
			BaseResp: types.BaseResp{
				Code:    -1,
				Message: err.Error(),
				Success: false,
			},
		}, nil
	}

	// 转换响应格式
	var logs []types.ExpLogRecord
	for _, log := range rpcResp.Logs {
		logs = append(logs, types.ExpLogRecord{
			Id:          log.Id,
			ExpChange:   int(log.ExpChange),
			Source:      log.Source,
			Description: log.Description,
			CreatedAt:   log.CreatedAt,
		})
	}

	return &types.GetExpLogsResp{
		BaseResp: types.BaseResp{
			Code:    0,
			Message: "获取经验日志成功",
			Success: true,
		},
		Data:  logs,
		Total: int(rpcResp.Total),
	}, nil
}
