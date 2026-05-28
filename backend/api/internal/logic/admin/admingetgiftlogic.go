package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminGetGiftLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminGetGiftLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetGiftLogic {
	return &AdminGetGiftLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminGetGiftLogic) AdminGetGift(req *types.AdminGetGiftReq) (resp *types.AdminGetGiftResp, err error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminGetGift(l.ctx, &moe.AdminGetGiftReq{
		GiftId: req.GiftId,
	})
	if err != nil {
		return &types.AdminGetGiftResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	return &types.AdminGetGiftResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     common.RpcGiftToTypes(rpcResp.GetGift()),
	}, nil
}
