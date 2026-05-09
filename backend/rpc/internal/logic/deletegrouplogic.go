package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type DeleteGroupLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewDeleteGroupLogic(ctx context.Context, svcCtx *svc.ServiceContext) *DeleteGroupLogic {
	return &DeleteGroupLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *DeleteGroupLogic) DeleteGroup(in *super.DeleteGroupReq) (*super.DeleteGroupResp, error) {
	groupID, err := strconv.ParseUint(in.GetGroupId(), 10, 64)
	if err != nil {
		return &super.DeleteGroupResp{
			Success: false,
			Message: "invalid group id",
		}, nil
	}

	db := l.svcCtx.DB
	tx := db.Begin()

	var group model.Group
	if err := tx.First(&group, groupID).Error; err != nil {
		tx.Rollback()
		return &super.DeleteGroupResp{
			Success: false,
			Message: "group not found",
		}, nil
	}

	if err := tx.Where("group_id = ?", groupID).Delete(&model.GroupMember{}).Error; err != nil {
		tx.Rollback()
		return &super.DeleteGroupResp{
			Success: false,
			Message: "failed to delete group members: " + err.Error(),
		}, nil
	}

	if err := tx.Delete(&group).Error; err != nil {
		tx.Rollback()
		return &super.DeleteGroupResp{
			Success: false,
			Message: "failed to delete group: " + err.Error(),
		}, nil
	}

	if err := tx.Commit().Error; err != nil {
		return &super.DeleteGroupResp{
			Success: false,
			Message: "failed to commit transaction: " + err.Error(),
		}, nil
	}

	return &super.DeleteGroupResp{
		Success: true,
		Message: "deleted successfully",
	}, nil
}
