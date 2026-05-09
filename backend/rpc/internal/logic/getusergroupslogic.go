package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserGroupsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserGroupsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserGroupsLogic {
	return &GetUserGroupsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetUserGroupsLogic) GetUserGroups(in *super.GetUserGroupsReq) (*super.GetUserGroupsResp, error) {
	userID, err := strconv.ParseUint(in.GetUserId(), 10, 64)
	if err != nil {
		return &super.GetUserGroupsResp{
			Groups: nil,
			Total:  0,
		}, nil
	}

	page := in.GetPage()
	pageSize := in.GetPageSize()
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 10
	}

	db := l.svcCtx.DB

	var members []model.GroupMember
	var total int64

	query := db.Model(&model.GroupMember{}).Where("user_id = ?", userID)
	query.Count(&total)

	offset := (int(page) - 1) * int(pageSize)
	query.Offset(offset).Limit(int(pageSize)).Find(&members)

	groupIDs := make([]uint64, len(members))
	for i, m := range members {
		groupIDs[i] = uint64(m.GroupID)
	}

	var groups []model.Group
	if len(groupIDs) > 0 {
		db.Where("id IN ?", groupIDs).Find(&groups)
	}

	groupMap := make(map[uint]model.Group)
	for _, g := range groups {
		groupMap[g.ID] = g
	}

	groupList := make([]*super.Group, 0, len(members))
	for _, member := range members {
		if group, ok := groupMap[member.GroupID]; ok {
			var creator model.User
			db.First(&creator, group.CreatorID)

			groupList = append(groupList, &super.Group{
				Id:          uint64(group.ID),
				Name:        group.Name,
				Description: group.Description,
				Avatar:      group.Avatar,
				Cover:       group.Cover,
				CreatorId:   uint64(group.CreatorID),
				CreatorName: creator.Username,
				MemberCount: int32(group.MemberCount),
				IsPublic:    group.IsPublic,
				Status:      group.Status,
				CreatedAt:   group.CreatedAt.Format("2006-01-02 15:04:05"),
				IsJoined:    true,
				UserRole:    member.Role,
			})
		}
	}

	return &super.GetUserGroupsResp{
		Groups: groupList,
		Total:  int32(total),
	}, nil
}
