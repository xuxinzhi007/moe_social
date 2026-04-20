package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type UpdateGroupLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewUpdateGroupLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpdateGroupLogic {
	return &UpdateGroupLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *UpdateGroupLogic) UpdateGroup(in *super.UpdateGroupReq) (*super.UpdateGroupResp, error) {
	groupID, err := strconv.ParseUint(in.GetGroupId(), 10, 64)
	if err != nil {
		return &super.UpdateGroupResp{
			Success: false,
			Message: "invalid group id",
		}, nil
	}

	db := l.svcCtx.DB
	var group model.Group
	if err := db.First(&group, groupID).Error; err != nil {
		return &super.UpdateGroupResp{
			Success: false,
			Message: "group not found",
		}, nil
	}

	updates := map[string]interface{}{}
	if in.GetName() != "" {
		updates["name"] = in.GetName()
	}
	if in.GetDescription() != "" {
		updates["description"] = in.GetDescription()
	}
	if in.GetAvatar() != "" {
		updates["avatar"] = in.GetAvatar()
	}
	if in.GetCover() != "" {
		updates["cover"] = in.GetCover()
	}

	if err := db.Model(&group).Updates(updates).Error; err != nil {
		return &super.UpdateGroupResp{
			Success: false,
			Message: "failed to update group: " + err.Error(),
		}, nil
	}

	db.First(&group, groupID)

	var creator model.User
	db.First(&creator, group.CreatorID)

	return &super.UpdateGroupResp{
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
		},
	}, nil
}
