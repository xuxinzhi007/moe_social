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

type CreateGroupLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewCreateGroupLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CreateGroupLogic {
	return &CreateGroupLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *CreateGroupLogic) CreateGroup(in *super.CreateGroupReq) (*super.CreateGroupResp, error) {
	userID, err := strconv.ParseUint(in.GetUserId(), 10, 64)
	if err != nil {
		return &super.CreateGroupResp{
			Success: false,
			Message: "invalid user id",
		}, nil
	}

	db := l.svcCtx.DB
	tx := db.Begin()

	group := model.Group{
		Name:        in.GetName(),
		Description: in.GetDescription(),
		Avatar:      in.GetAvatar(),
		Cover:       in.GetCover(),
		CreatorID:   uint(userID),
		MemberCount: 1,
		IsPublic:    in.GetIsPublic(),
		Status:      "active",
	}

	if err := tx.Create(&group).Error; err != nil {
		tx.Rollback()
		return &super.CreateGroupResp{
			Success: false,
			Message: "failed to create group: " + err.Error(),
		}, nil
	}

	member := model.GroupMember{
		GroupID: group.ID,
		UserID:  uint(userID),
		Role:    "admin",
		JoinAt:  time.Now(),
	}

	if err := tx.Create(&member).Error; err != nil {
		tx.Rollback()
		return &super.CreateGroupResp{
			Success: false,
			Message: "failed to add member: " + err.Error(),
		}, nil
	}

	if err := tx.Commit().Error; err != nil {
		return &super.CreateGroupResp{
			Success: false,
			Message: "failed to commit transaction: " + err.Error(),
		}, nil
	}

	var creator model.User
	db.First(&creator, userID)

	return &super.CreateGroupResp{
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
			CreatedAt:   group.CreatedAt.Format(time.RFC3339),
			IsJoined:    true,
			UserRole:    "admin",
		},
	}, nil
}
