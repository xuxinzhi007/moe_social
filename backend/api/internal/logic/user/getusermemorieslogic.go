package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

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
	rpcResp, err := l.svcCtx.LLMGW.GetUserMemories(l.ctx, &moe.GetUserMemoriesReq{
		UserId: req.UserId,
		Limit:  int32(req.Limit),
		Offset: int32(req.Offset),
	})
	if err != nil {
		return &types.GetUserMemoriesResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	memories := make([]types.UserMemory, 0, len(rpcResp.Memories))
	for _, m := range rpcResp.Memories {
		memories = append(memories, types.UserMemory{
			Id:          m.Id,
			UserId:      m.UserId,
			Key:         m.Key,
			Value:       m.Value,
			MemoryType:  m.MemoryType,
			Confidence:  m.Confidence,
			Source:      m.Source,
			SourceMsgId: m.SourceMsgId,
			SessionId:   m.SessionId,
			CreatedAt:   m.CreatedAt,
			UpdatedAt:   m.UpdatedAt,
		})
	}

	return &types.GetUserMemoriesResp{
		BaseResp: common.HandleRPCError(nil, "获取用户记忆成功"),
		Data:     memories,
		Total:    rpcResp.Total,
		Limit:    int(rpcResp.Limit),
		Offset:   int(rpcResp.Offset),
		HasMore:  rpcResp.HasMore,
	}, nil
}
