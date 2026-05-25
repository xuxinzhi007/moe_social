package logic

import (
	"context"

	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type AdminGetSchemaCatalogLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminGetSchemaCatalogLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminGetSchemaCatalogLogic {
	return &AdminGetSchemaCatalogLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminGetSchemaCatalogLogic) AdminGetSchemaCatalog(_ *super.AdminGetSchemaCatalogReq) (*super.AdminGetSchemaCatalogResp, error) {
	if l.svcCtx.DB == nil {
		return nil, errorx.Internal("数据库未就绪")
	}

	catalog := utils.AdminSchemaCatalog()
	items := make([]*super.AdminSchemaTableItem, 0, len(catalog))
	summary := &super.AdminSchemaCatalogSummary{TotalTables: int32(len(catalog))}

	for _, entry := range catalog {
		tableName := schemaTableName(l.svcCtx.DB, entry.Model)
		rowCount := countSchemaRows(l.svcCtx.DB, entry.Model)
		if rowCount >= 0 {
			summary.TotalRows += rowCount
		}
		coverage := utils.AdminSchemaCoverage(entry.Capabilities)
		switch coverage {
		case "full":
			summary.ManagedFull++
		case "partial", "readonly":
			summary.ManagedPartial++
		default:
			summary.Unmanaged++
		}
		items = append(items, &super.AdminSchemaTableItem{
			Key:          entry.Key,
			TableName:    tableName,
			Label:        entry.Label,
			Domain:       entry.Domain,
			Coverage:     coverage,
			Capabilities: entry.Capabilities,
			AdminRoute:   entry.AdminRoute,
			BootstrapKey: entry.BootstrapKey,
			RowCount:     rowCount,
			Note:         entry.Note,
		})
	}

	return &super.AdminGetSchemaCatalogResp{Summary: summary, Items: items}, nil
}

func schemaTableName(db *gorm.DB, model interface{}) string {
	if db == nil || model == nil {
		return ""
	}
	stmt := &gorm.Statement{DB: db}
	if err := stmt.Parse(model); err != nil {
		return ""
	}
	return stmt.Table
}

func countSchemaRows(db *gorm.DB, model interface{}) int64 {
	if db == nil || model == nil {
		return -1
	}
	var n int64
	if err := db.Model(model).Count(&n).Error; err != nil {
		return -1
	}
	return n
}
