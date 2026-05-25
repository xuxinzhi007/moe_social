package logic

import (
	"context"
	"fmt"
	"strconv"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListFriendRequestsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListFriendRequestsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListFriendRequestsLogic {
	return &AdminListFriendRequestsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListFriendRequestsLogic) AdminListFriendRequests(in *super.AdminListFriendRequestsReq) (*super.AdminListFriendRequestsResp, error) {
	page, pageSize := adminPageParams(in.GetPage(), in.GetPageSize())
	q := l.svcCtx.DB.Model(&model.FriendRequest{})
	if st := strings.TrimSpace(in.GetStatus()); st != "" {
		q = q.Where("status = ?", st)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		l.Errorf("[admin] count friend requests: %v", err)
		return nil, errorx.Internal("查询好友申请失败")
	}
	var rows []model.FriendRequest
	offset := int((page - 1) * pageSize)
	if err := q.Order("id DESC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		l.Errorf("[admin] list friend requests: %v", err)
		return nil, errorx.Internal("查询好友申请失败")
	}

	kw := strings.ToLower(strings.TrimSpace(in.GetKeyword()))
	items := make([]*super.AdminFriendRequestItem, 0, len(rows))
	for _, row := range rows {
		fromName := l.userDisplayName(row.FromUserID)
		toName := l.userDisplayName(row.ToUserID)
		if kw != "" {
			match := strings.Contains(strings.ToLower(fromName), kw) ||
				strings.Contains(strings.ToLower(toName), kw) ||
				strings.Contains(fmt.Sprint(row.FromUserID), kw) ||
				strings.Contains(fmt.Sprint(row.ToUserID), kw)
			if !match {
				continue
			}
		}
		items = append(items, &super.AdminFriendRequestItem{
			Id:           strconv.FormatUint(uint64(row.ID), 10),
			FromUserId:   fmt.Sprint(row.FromUserID),
			FromUserName: fromName,
			ToUserId:     fmt.Sprint(row.ToUserID),
			ToUserName:   toName,
			Status:       row.Status,
			CreatedAt:    row.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}
	return &super.AdminListFriendRequestsResp{Items: items, Total: int32(total)}, nil
}

func (l *AdminListFriendRequestsLogic) userDisplayName(userID uint) string {
	var user model.User
	if err := l.svcCtx.DB.First(&user, userID).Error; err != nil {
		return ""
	}
	if user.Username != "" {
		return user.Username
	}
	return user.Email
}
