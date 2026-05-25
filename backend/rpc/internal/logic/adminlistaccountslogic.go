package logic

import (
	"context"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListAccountsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListAccountsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListAccountsLogic {
	return &AdminListAccountsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListAccountsLogic) AdminListAccounts(in *super.AdminListAccountsReq) (*super.AdminListAccountsResp, error) {
	page, pageSize := adminPageParams(in.GetPage(), in.GetPageSize())
	q := l.svcCtx.DB.Model(&model.AdminAccount{})
	if kw := strings.TrimSpace(in.GetKeyword()); kw != "" {
		like := "%" + kw + "%"
		q = q.Where("username LIKE ? OR role LIKE ?", like, like)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		l.Errorf("[admin] count accounts: %v", err)
		return nil, errorx.Internal("查询管理员失败")
	}
	var rows []model.AdminAccount
	offset := int((page - 1) * pageSize)
	if err := q.Order("id ASC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		l.Errorf("[admin] list accounts: %v", err)
		return nil, errorx.Internal("查询管理员失败")
	}
	items := make([]*super.AdminAccountItem, len(rows))
	for i, row := range rows {
		items[i] = adminAccountToProto(row)
	}
	return &super.AdminListAccountsResp{Items: items, Total: int32(total)}, nil
}
