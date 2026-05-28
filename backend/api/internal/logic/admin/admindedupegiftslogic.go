package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminDedupeGiftsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminDedupeGiftsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDedupeGiftsLogic {
	return &AdminDedupeGiftsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminDedupeGiftsLogic) AdminDedupeGifts(_ *types.EmptyReq) (resp *types.AdminDedupeGiftsResp, err error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminDedupeGifts(l.ctx, &moe.AdminDedupeGiftsReq{})
	if err != nil {
		return &types.AdminDedupeGiftsResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	msg := "未发现重复礼物"
	if rpcResp.GetRemoved() > 0 {
		msg = "已合并重复礼物"
	}
	resp = &types.AdminDedupeGiftsResp{
		BaseResp: common.HandleRPCError(nil, msg),
		Data:     types.AdminDedupeGiftsData{Removed: int(rpcResp.GetRemoved())},
	}
	if resp.BaseResp.Success && rpcResp.GetRemoved() > 0 {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "dedupe", "gift", "", "合并同名礼物")
	}
	return resp, nil
}
