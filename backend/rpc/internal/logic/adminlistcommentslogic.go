package logic

import (
	"context"
	"strconv"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListCommentsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListCommentsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListCommentsLogic {
	return &AdminListCommentsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminListCommentsLogic) AdminListComments(in *super.AdminListCommentsReq) (*super.AdminListCommentsResp, error) {
	page := in.GetPage()
	if page <= 0 {
		page = 1
	}
	pageSize := in.GetPageSize()
	if pageSize <= 0 {
		pageSize = 50
	}
	if pageSize > 200 {
		pageSize = 200
	}

	q := l.svcCtx.DB.Model(&model.Comment{}).Unscoped()
	if pid := strings.TrimSpace(in.GetPostId()); pid != "" {
		if n, err := strconv.ParseUint(pid, 10, 64); err == nil && n > 0 {
			q = q.Where("post_id = ?", n)
		}
	}
	if kw := strings.TrimSpace(in.GetKeyword()); kw != "" {
		q = q.Where("content LIKE ?", "%"+kw+"%")
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		l.Errorf("[admin] count comments: %v", err)
		return nil, errorx.Internal("查询评论失败")
	}

	var rows []model.Comment
	offset := int((page - 1) * pageSize)
	if err := q.Order("id DESC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		l.Errorf("[admin] list comments: %v", err)
		return nil, errorx.Internal("查询评论失败")
	}

	userMap := map[uint]model.User{}
	if len(rows) > 0 {
		userIDs := make([]uint, 0, len(rows))
		for _, c := range rows {
			userIDs = append(userIDs, c.UserID)
		}
		var users []model.User
		_ = l.svcCtx.DB.Where("id IN ?", userIDs).Find(&users).Error
		for _, u := range users {
			userMap[u.ID] = u
		}
	}

	comments := make([]*super.Comment, 0, len(rows))
	for _, c := range rows {
		username := "未知用户"
		avatar := "https://picsum.photos/150"
		if u, ok := userMap[c.UserID]; ok {
			if u.Username != "" {
				username = u.Username
			} else if u.Email != "" {
				username = u.Email
			}
			if u.Avatar != "" {
				avatar = u.Avatar
			}
		}
		comments = append(comments, &super.Comment{
			Id:         strconv.FormatUint(uint64(c.ID), 10),
			PostId:     strconv.FormatUint(uint64(c.PostID), 10),
			UserId:     strconv.FormatUint(uint64(c.UserID), 10),
			UserName:   username,
			UserAvatar: avatar,
			Content:    c.Content,
			Likes:      int32(c.Likes),
			CreatedAt:  utils.FormatAPIDateTime(c.CreatedAt),
			ParentId:   strconv.FormatUint(uint64(c.ParentID), 10),
		})
	}

	return &super.AdminListCommentsResp{
		Comments: comments,
		Total:    int32(total),
	}, nil
}
