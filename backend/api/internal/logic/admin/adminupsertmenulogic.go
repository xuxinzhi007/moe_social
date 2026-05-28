package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminUpsertMenuLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminUpsertMenuLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpsertMenuLogic {
	return &AdminUpsertMenuLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminUpsertMenuLogic) AdminUpsertMenu(req *types.AdminUpsertMenuReq) (*types.AdminUpsertMenuResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminUpsertMenu(l.ctx, &moe.AdminUpsertMenuReq{
		Key:          req.Key,
		Kind:         req.Kind,
		ParentKey:    req.ParentKey,
		Path:         req.Path,
		Label:        req.Label,
		Icon:         req.Icon,
		Caption:      req.Caption,
		Status:       req.Status,
		AppDomain:    req.AppDomain,
		SortOrder:    int32(req.SortOrder),
		DefaultOpen:  req.DefaultOpen,
		End:          req.End,
		ExternalHref: req.ExternalHref,
		Enabled:      req.Enabled,
	})
	if err != nil {
		return &types.AdminUpsertMenuResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	resp := &types.AdminUpsertMenuResp{
		BaseResp: common.HandleRPCError(nil, "保存成功"),
		Data:     common.RpcAdminMenuToTypes(rpcResp.GetMenu()),
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "upsert", "admin_menu", req.Key, "保存侧栏菜单")
	}
	return resp, nil
}
