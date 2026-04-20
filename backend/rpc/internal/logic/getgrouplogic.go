package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetGroupLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetGroupLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetGroupLogic {
	return &GetGroupLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetGroupLogic) GetGroup(in *super.GetGroupReq) (*super.GetGroupResp, error) {
	groupID, err := strconv.ParseUint(in.GetGroupId(), 10, 64)
	if err != nil {
		return &super.GetGroupResp{
			Success: false,
			Message: "invalid group id",
		}, nil
	}

	db := l.svcCtx.DB
	var group model.Group
	if err := db.First(&group, groupID).Error; err != nil {
		return &super.GetGroupResp{
			Success: false,
			Message: "group not found",
		}, nil
	}

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

	return &super.GetGroupResp{
		Success: true,
		Message: "success",
		Group: &super.Group{
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
		},
	}, nil
}
