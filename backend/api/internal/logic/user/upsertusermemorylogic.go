package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpsertUserMemoryLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewUpsertUserMemoryLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpsertUserMemoryLogic {
	return &UpsertUserMemoryLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *UpsertUserMemoryLogic) UpsertUserMemory(req *types.UpsertUserMemoryReq) (resp *types.UpsertUserMemoryResp, err error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.UpsertUserMemory(l.ctx, &super.UpsertUserMemoryReq{
		UserId: req.UserId,
		Key:    req.Key,
		Value:  req.Value,
	})
	if err != nil {
		return &types.UpsertUserMemoryResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}

	m := rpcResp.Memory
	return &types.UpsertUserMemoryResp{
		BaseResp: common.HandleRPCError(nil, "更新用户记忆成功"),
		Data: types.UserMemory{
			Id:        m.Id,
			UserId:    m.UserId,
			Key:       m.Key,
			Value:     m.Value,
			CreatedAt: m.CreatedAt,
			UpdatedAt: m.UpdatedAt,
		},
	}, nil
}

