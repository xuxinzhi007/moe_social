package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetGroupMembersLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetGroupMembersLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetGroupMembersLogic {
	return &GetGroupMembersLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetGroupMembersLogic) GetGroupMembers(in *super.GetGroupMembersReq) (*super.GetGroupMembersResp, error) {
	groupID, err := strconv.ParseUint(in.GetGroupId(), 10, 64)
	if err != nil {
		return &super.GetGroupMembersResp{
			Members: nil,
			Total:   0,
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

	query := db.Model(&model.GroupMember{}).Where("group_id = ?", groupID)
	query.Count(&total)

	offset := (int(page) - 1) * int(pageSize)
	query.Offset(offset).Limit(int(pageSize)).Find(&members)

	memberList := make([]*super.GroupMember, len(members))
	for i, member := range members {
		var user model.User
		db.First(&user, member.UserID)

		memberList[i] = &super.GroupMember{
			Id:         uint64(member.ID),
			GroupId:    uint64(member.GroupID),
			UserId:     uint64(member.UserID),
			UserName:   user.Username,
			UserAvatar: user.Avatar,
			Role:       member.Role,
			JoinAt:     member.JoinAt.Format("2006-01-02 15:04:05"),
			CreatedAt:  member.CreatedAt.Format("2006-01-02 15:04:05"),
		}
	}

	return &super.GetGroupMembersResp{
		Members: memberList,
		Total:   int32(total),
	}, nil
}
