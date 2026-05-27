package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListMemoriesLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminListMemoriesLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListMemoriesLogic {
	return &AdminListMemoriesLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminListMemoriesLogic) AdminListMemories(req *types.AdminListMemoriesReq) (*types.AdminListMemoriesResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminListMemories(l.ctx, &super.AdminListMemoriesReq{
		Page:       int32(req.Page),
		PageSize:   int32(req.PageSize),
		UserId:     req.UserId,
		Keyword:    req.Keyword,
		MemoryType: req.MemoryType,
	})
	if err != nil {
		return &types.AdminListMemoriesResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	items := make([]types.AdminMemoryItem, len(rpcResp.GetItems()))
	for i, item := range rpcResp.GetItems() {
		items[i] = common.RpcAdminMemoryToTypes(item)
	}
	return &types.AdminListMemoriesResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     types.AdminListMemoriesData{Items: items, Total: int(rpcResp.GetTotal())},
	}, nil
}
