package logic

import (
	"context"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUsersLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUsersLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUsersLogic {
	return &GetUsersLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}
// 用户相关服务
func (l *GetUsersLogic) GetUsers(in *super.GetUsersReq) (*super.GetUsersResp, error) {
	// 确保page和page_size有默认值
	page := in.Page
	if page <= 0 {
		page = 1
	}
	pageSize := in.PageSize
	if pageSize <= 0 {
		pageSize = 10
	}

	// 计算偏移量
	offset := (page - 1) * pageSize

	// 查询用户列表
	var users []model.User
	var total int64

	// 获取总数
	l.svcCtx.DB.Model(&model.User{}).Count(&total)

	// 分页查询
	result := l.svcCtx.DB.Offset(int(offset)).Limit(int(pageSize)).Find(&users)
	if result.Error != nil {
		return nil, result.Error
	}

	respUsers := make([]*super.User, len(users))
	for i := range users {
		u := users[i]
		respUsers[i] = modelUserToProto(&u)
	}

	return &super.GetUsersResp{
		Users: respUsers,
		Total: int32(total),
	}, nil
}
