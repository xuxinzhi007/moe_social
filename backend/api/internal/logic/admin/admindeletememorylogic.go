package admin

import (
	"context"
	"fmt"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDeleteMemoryLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminDeleteMemoryLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteMemoryLogic {
	return &AdminDeleteMemoryLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminDeleteMemoryLogic) AdminDeleteMemory(req *types.AdminDeleteMemoryReq) (*types.AdminDeleteMemoryResp, error) {
	_, err := l.svcCtx.AdminGW.AdminDeleteMemory(l.ctx, &super.AdminDeleteMemoryReq{
		MemoryId: req.MemoryId,
	})
	if err != nil {
		return &types.AdminDeleteMemoryResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}

	resp := &types.AdminDeleteMemoryResp{BaseResp: common.HandleRPCError(nil, "ok")}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "delete", "user_memory", fmt.Sprintf("%d", req.MemoryId), "删除用户记忆")
	}
	return resp, nil
}
