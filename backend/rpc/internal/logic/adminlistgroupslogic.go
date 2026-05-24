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

type AdminListGroupsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListGroupsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListGroupsLogic {
	return &AdminListGroupsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminListGroupsLogic) AdminListGroups(in *super.AdminListGroupsReq) (*super.AdminListGroupsResp, error) {
	page := in.GetPage()
	if page <= 0 {
		page = 1
	}
	pageSize := in.GetPageSize()
	if pageSize <= 0 {
		pageSize = 50
	}
	if pageSize > 200 {
		pageSize = 200
	}

	q := l.svcCtx.DB.Model(&model.Group{})
	if kw := strings.TrimSpace(in.GetKeyword()); kw != "" {
		like := "%" + kw + "%"
		q = q.Where("name LIKE ? OR description LIKE ?", like, like)
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		l.Errorf("[admin] count groups: %v", err)
		return nil, errorx.Internal("查询社区失败")
	}

	var rows []model.Group
	offset := int((page - 1) * pageSize)
	if err := q.Order("id DESC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		l.Errorf("[admin] list groups: %v", err)
		return nil, errorx.Internal("查询社区失败")
	}

	groups := make([]*super.Group, len(rows))
	for i, group := range rows {
		var creator model.User
		_ = l.svcCtx.DB.First(&creator, group.CreatorID).Error
		creatorName := creator.Username
		if creatorName == "" {
			creatorName = creator.Email
		}
		groups[i] = &super.Group{
			Id:          uint64(group.ID),
			Name:        group.Name,
			Description: group.Description,
			Avatar:      group.Avatar,
			Cover:       group.Cover,
			CreatorId:   uint64(group.CreatorID),
			CreatorName: creatorName,
			MemberCount: int32(group.MemberCount),
			IsPublic:    group.IsPublic,
			Status:      group.Status,
			CreatedAt:   group.CreatedAt.Format("2006-01-02 15:04:05"),
		}
	}

	return &super.AdminListGroupsResp{
		Groups: groups,
		Total:  int32(total),
	}, nil
}
