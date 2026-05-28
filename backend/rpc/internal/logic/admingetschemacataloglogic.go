package logic

import (
	"context"

	adminbiz "backend/internal/biz/admin"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminGetSchemaCatalogLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminGetSchemaCatalogLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetSchemaCatalogLogic {
	return &AdminGetSchemaCatalogLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminGetSchemaCatalogLogic) AdminGetSchemaCatalog(_ *moe.AdminGetSchemaCatalogReq) (*moe.AdminGetSchemaCatalogResp, error) {
	if l.svcCtx.DB == nil {
		return nil, errorx.Internal("数据库未就绪")
	}
	return adminbiz.SchemaCatalog(l.ctx, l.svcCtx.AdminStore())
}
