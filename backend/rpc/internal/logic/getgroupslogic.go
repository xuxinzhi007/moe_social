package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetGroupsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetGroupsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetGroupsLogic {
	return &GetGroupsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetGroupsLogic) GetGroups(in *super.GetGroupsReq) (*super.GetGroupsResp, error) {
	db := l.svcCtx.DB
	var groups []model.Group
	var total int64

	page := in.GetPage()
	pageSize := in.GetPageSize()
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 10
	}

	query := db.Model(&model.Group{}).Where("status = ?", "active")

	if in.GetIsPublic() {
		query = query.Where("is_public = ?", true)
	}

	if in.GetKeyword() != "" {
		query = query.Where("name LIKE ? OR description LIKE ?", "%"+in.GetKeyword()+"%", "%"+in.GetKeyword()+"%")
	}

	query.Count(&total)

	offset := (int(page) - 1) * int(pageSize)
	query.Offset(offset).Limit(int(pageSize)).Find(&groups)

	groupList := make([]*super.Group, len(groups))
	for i, group := range groups {
		var creator model.User
		db.First(&creator, group.CreatorID)

		isJoined := false
		userRole := ""
		if in.GetUserId() != "" {
			userID, _ := strconv.ParseUint(in.GetUserId(), 10, 64)
			var member model.GroupMember
			result := db.Where("group_id = ? AND user_id = ?", group.ID, userID).First(&member)
			isJoined = result.Error == nil
			if isJoined {
				userRole = member.Role
			}
		}

		groupList[i] = &super.Group{
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
			IsJoined:    isJoined,
			UserRole:    userRole,
		}
	}

	return &super.GetGroupsResp{
		Groups: groupList,
		Total:  int32(total),
	}, nil
}
