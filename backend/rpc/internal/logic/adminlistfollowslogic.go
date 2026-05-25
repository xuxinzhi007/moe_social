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

type AdminListFollowsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListFollowsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListFollowsLogic {
	return &AdminListFollowsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListFollowsLogic) AdminListFollows(in *super.AdminListFollowsReq) (*super.AdminListFollowsResp, error) {
	page, pageSize := adminPageParams(in.GetPage(), in.GetPageSize())
	q := l.svcCtx.DB.Model(&model.Follow{})
	if uid := strings.TrimSpace(in.GetUserId()); uid != "" {
		id, err := strconv.ParseUint(uid, 10, 64)
		if err != nil {
			return nil, errorx.InvalidArgument("用户 ID 无效")
		}
		q = q.Where("follower_id = ? OR following_id = ?", id, id)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		l.Errorf("[admin] count follows: %v", err)
		return nil, errorx.Internal("查询关注失败")
	}
	var rows []model.Follow
	offset := int((page - 1) * pageSize)
	if err := q.Order("id DESC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		l.Errorf("[admin] list follows: %v", err)
		return nil, errorx.Internal("查询关注失败")
	}

	kw := strings.ToLower(strings.TrimSpace(in.GetKeyword()))
	items := make([]*super.AdminFollowItem, 0, len(rows))
	for _, row := range rows {
		followerName := l.userDisplayName(row.FollowerID)
		followingName := l.userDisplayName(row.FollowingID)
		if kw != "" {
			match := strings.Contains(strings.ToLower(followerName), kw) ||
				strings.Contains(strings.ToLower(followingName), kw) ||
				strings.Contains(fmt.Sprint(row.FollowerID), kw) ||
				strings.Contains(fmt.Sprint(row.FollowingID), kw)
			if !match {
				continue
			}
		}
		items = append(items, &super.AdminFollowItem{
			Id:            strconv.FormatUint(uint64(row.ID), 10),
			FollowerId:    fmt.Sprint(row.FollowerID),
			FollowerName:  followerName,
			FollowingId:   fmt.Sprint(row.FollowingID),
			FollowingName: followingName,
			CreatedAt:     row.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}
	return &super.AdminListFollowsResp{Items: items, Total: int32(total)}, nil
}

func (l *AdminListFollowsLogic) userDisplayName(userID uint) string {
	var user model.User
	if err := l.svcCtx.DB.First(&user, userID).Error; err != nil {
		return ""
	}
	if user.Username != "" {
		return user.Username
	}
	return user.Email
}
