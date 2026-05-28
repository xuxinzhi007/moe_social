package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminUpdateGiftLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminUpdateGiftLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateGiftLogic {
	return &AdminUpdateGiftLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminUpdateGiftLogic) AdminUpdateGift(req *types.AdminUpdateGiftReq) (resp *types.AdminUpdateGiftResp, err error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminUpdateGift(l.ctx, &moe.AdminUpdateGiftReq{
		GiftId:            req.GiftId,
		Name:              req.Name,
		Price:             int32(req.Price),
		Icon:              req.Icon,
		Description:       req.Description,
		Category:          req.Category,
		SortOrder:         int32(req.SortOrder),
		UpdateName:        req.UpdateName,
		UpdatePrice:       req.UpdatePrice,
		UpdateIcon:        req.UpdateIcon,
		UpdateDescription: req.UpdateDescription,
		UpdateCategory:    req.UpdateCategory,
		UpdateSortOrder:   req.UpdateSortOrder,
	})
	if err != nil {
		return &types.AdminUpdateGiftResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}

	resp = &types.AdminUpdateGiftResp{
		BaseResp: common.HandleRPCError(nil, "保存成功"),
		Data:     common.RpcGiftToTypes(rpcResp.GetGift()),
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "update", "gift", req.GiftId, "更新礼物")
	}
	return resp, nil
}
