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

type AdminListUsersLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListUsersLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListUsersLogic {
	return &AdminListUsersLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListUsersLogic) AdminListUsers(in *super.AdminListUsersReq) (*super.AdminListUsersResp, error) {
	page := in.GetPage()
	if page <= 0 {
		page = 1
	}
	pageSize := in.GetPageSize()
	if pageSize <= 0 {
		pageSize = 20
	}
	if pageSize > 100 {
		pageSize = 100
	}

	q := l.svcCtx.DB.Model(&model.User{})
	kw := strings.TrimSpace(in.GetKeyword())
	if kw != "" {
		like := "%" + kw + "%"
		q = q.Where("username LIKE ? OR email LIKE ? OR moe_no LIKE ?", like, like, like)
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		l.Errorf("[admin] count users: %v", err)
		return nil, errorx.Internal("服务器内部错误")
	}

	var users []model.User
	offset := int((page - 1) * pageSize)
	if err := q.Order("id ASC").Offset(offset).Limit(int(pageSize)).Find(&users).Error; err != nil {
		l.Errorf("[admin] list users: %v", err)
		return nil, errorx.Internal("服务器内部错误")
	}

	out := make([]*super.User, 0, len(users))
	for i := range users {
		out = append(out, modelUserToProto(&users[i]))
	}
	return &super.AdminListUsersResp{Users: out, Total: int32(total)}, nil
}
