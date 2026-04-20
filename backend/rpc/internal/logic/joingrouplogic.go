package logic

import (
	"context"
	"strconv"
	"time"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type JoinGroupLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewJoinGroupLogic(ctx context.Context, svcCtx *svc.ServiceContext) *JoinGroupLogic {
	return &JoinGroupLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *JoinGroupLogic) JoinGroup(in *super.JoinGroupReq) (*super.JoinGroupResp, error) {
	groupID, err := strconv.ParseUint(in.GetGroupId(), 10, 64)
	if err != nil {
		return &super.JoinGroupResp{
			Success: false,
			Message: "invalid group id",
		}, nil
	}

	userID, err := strconv.ParseUint(in.GetUserId(), 10, 64)
	if err != nil {
		return &super.JoinGroupResp{
			Success: false,
			Message: "invalid user id",
		}, nil
	}

	db := l.svcCtx.DB
	tx := db.Begin()

	var group model.Group
	if err := tx.First(&group, groupID).Error; err != nil {
		tx.Rollback()
		return &super.JoinGroupResp{
			Success: false,
			Message: "group not found",
		}, nil
	}

	var existingMember model.GroupMember
	result := tx.Where("group_id = ? AND user_id = ?", groupID, userID).First(&existingMember)
	if result.Error == nil {
		tx.Rollback()
		return &super.JoinGroupResp{
			Success: true,
			Message: "already joined",
		}, nil
	}

	if !group.IsPublic {
		tx.Rollback()
		return &super.JoinGroupResp{
			Success: false,
			Message: "this group is private",
		}, nil
	}

	member := model.GroupMember{
		GroupID: uint(groupID),
		UserID:  uint(userID),
		Role:    "member",
		JoinAt:  time.Now(),
	}

	if err := tx.Create(&member).Error; err != nil {
		tx.Rollback()
		return &super.JoinGroupResp{
			Success: false,
			Message: "failed to join group: " + err.Error(),
		}, nil
	}

	if err := tx.Model(&group).Update("member_count", group.MemberCount+1).Error; err != nil {
		tx.Rollback()
		return &super.JoinGroupResp{
			Success: false,
			Message: "failed to update member count: " + err.Error(),
		}, nil
	}

	if err := tx.Commit().Error; err != nil {
		return &super.JoinGroupResp{
			Success: false,
			Message: "failed to commit transaction: " + err.Error(),
		}, nil
	}

	return &super.JoinGroupResp{
		Success: true,
		Message: "joined successfully",
	}, nil
}
