package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListGiftsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminListGiftsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListGiftsLogic {
	return &AdminListGiftsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminListGiftsLogic) AdminListGifts(req *types.AdminListGiftsReq) (resp *types.AdminListGiftsResp, err error) {
	page := req.Page
	if page <= 0 {
		page = 1
	}
	pageSize := req.PageSize
	if pageSize <= 0 {
		pageSize = 50
	}

	rpcResp, err := l.svcCtx.SuperRpcClient.AdminListGifts(l.ctx, &super.AdminListGiftsReq{
		Page:     int32(page),
		PageSize: int32(pageSize),
		Keyword:  req.Keyword,
		Category: req.Category,
	})
	if err != nil {
		return &types.AdminListGiftsResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}

	items := make([]types.Gift, 0, len(rpcResp.GetGifts()))
	for _, g := range rpcResp.GetGifts() {
		items = append(items, common.RpcGiftToTypes(g))
	}

	return &types.AdminListGiftsResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data: types.AdminListGiftsData{
			Items: items,
			Total: int(rpcResp.GetTotal()),
		},
	}, nil
}
