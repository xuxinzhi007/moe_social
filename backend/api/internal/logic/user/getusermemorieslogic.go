package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserMemoriesLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetUserMemoriesLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserMemoriesLogic {
	return &GetUserMemoriesLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetUserMemoriesLogic) GetUserMemories(req *types.GetUserMemoriesReq) (resp *types.GetUserMemoriesResp, err error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.GetUserMemories(l.ctx, &super.GetUserMemoriesReq{
		UserId: req.UserId,
	})
	if err != nil {
		return &types.GetUserMemoriesResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	memories := make([]types.UserMemory, 0, len(rpcResp.Memories))
	for _, m := range rpcResp.Memories {
		memories = append(memories, types.UserMemory{
			Id:        m.Id,
			UserId:    m.UserId,
			Key:       m.Key,
			Value:     m.Value,
			CreatedAt: m.CreatedAt,
			UpdatedAt: m.UpdatedAt,
		})
	}

	return &types.GetUserMemoriesResp{
		BaseResp: common.HandleRPCError(nil, "获取用户记忆成功"),
		Data:     memories,
	}, nil
}

