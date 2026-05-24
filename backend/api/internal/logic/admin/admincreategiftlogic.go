package admin

import (
	"context"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminCreateGiftLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminCreateGiftLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminCreateGiftLogic {
	return &AdminCreateGiftLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminCreateGiftLogic) AdminCreateGift(req *types.AdminCreateGiftReq) (resp *types.AdminCreateGiftResp, err error) {
	if strings.TrimSpace(req.Name) == "" {
		return &types.AdminCreateGiftResp{
			BaseResp: types.BaseResp{Success: false, Message: "礼物名称不能为空"},
		}, nil
	}
	if req.Price < 0 {
		return &types.AdminCreateGiftResp{
			BaseResp: types.BaseResp{Success: false, Message: "价格不能为负数"},
		}, nil
	}

	rpcResp, err := l.svcCtx.SuperRpcClient.AdminCreateGift(l.ctx, &super.AdminCreateGiftReq{
		Name:        strings.TrimSpace(req.Name),
		Price:       int32(req.Price),
		Icon:        req.Icon,
		Description: req.Description,
		Category:    req.Category,
		SortOrder:   int32(req.SortOrder),
	})
	if err != nil {
		return &types.AdminCreateGiftResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}

	return &types.AdminCreateGiftResp{
		BaseResp: common.HandleRPCError(nil, "创建成功"),
		Data:     common.RpcGiftToTypes(rpcResp.GetGift()),
	}, nil
}
