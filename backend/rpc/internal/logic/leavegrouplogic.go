package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type LeaveGroupLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewLeaveGroupLogic(ctx context.Context, svcCtx *svc.ServiceContext) *LeaveGroupLogic {
	return &LeaveGroupLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *LeaveGroupLogic) LeaveGroup(in *super.LeaveGroupReq) (*super.LeaveGroupResp, error) {
	groupID, err := strconv.ParseUint(in.GetGroupId(), 10, 64)
	if err != nil {
		return &super.LeaveGroupResp{
			Success: false,
			Message: "invalid group id",
		}, nil
	}

	userID, err := strconv.ParseUint(in.GetUserId(), 10, 64)
	if err != nil {
		return &super.LeaveGroupResp{
			Success: false,
			Message: "invalid user id",
		}, nil
	}

	db := l.svcCtx.DB
	tx := db.Begin()

	var group model.Group
	if err := tx.First(&group, groupID).Error; err != nil {
		tx.Rollback()
		return &super.LeaveGroupResp{
			Success: false,
			Message: "group not found",
		}, nil
	}

	var member model.GroupMember
	result := tx.Where("group_id = ? AND user_id = ?", groupID, userID).First(&member)
	if result.Error != nil {
		tx.Rollback()
		return &super.LeaveGroupResp{
			Success: false,
			Message: "not a member of this group",
		}, nil
	}

	if err := tx.Delete(&member).Error; err != nil {
		tx.Rollback()
		return &super.LeaveGroupResp{
			Success: false,
			Message: "failed to leave group: " + err.Error(),
		}, nil
	}

	if err := tx.Model(&group).Update("member_count", group.MemberCount-1).Error; err != nil {
		tx.Rollback()
		return &super.LeaveGroupResp{
			Success: false,
			Message: "failed to update member count: " + err.Error(),
		}, nil
	}

	if err := tx.Commit().Error; err != nil {
		return &super.LeaveGroupResp{
			Success: false,
			Message: "failed to commit transaction: " + err.Error(),
		}, nil
	}

	return &super.LeaveGroupResp{
		Success: true,
		Message: "left successfully",
	}, nil
}
