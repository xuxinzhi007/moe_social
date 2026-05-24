package logic

import (
	"context"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListPostsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListPostsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListPostsLogic {
	return &AdminListPostsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AdminListPostsLogic) AdminListPosts(in *super.AdminListPostsReq) (*super.AdminListPostsResp, error) {
	page := in.GetPage()
	if page <= 0 {
		page = 1
	}
	pageSize := in.GetPageSize()
	if pageSize <= 0 {
		pageSize = 20
	}
	if pageSize > 100 {
		pageSize = 100
	}

	q := l.svcCtx.DB.Model(&model.Post{})
	if in.GetIncludeDeleted() {
		q = q.Unscoped()
	}
	if st := strings.TrimSpace(in.GetModerationStatus()); st != "" {
		q = q.Where("moderation_status = ?", st)
	}
	if kw := strings.TrimSpace(in.GetKeyword()); kw != "" {
		like := "%" + kw + "%"
		q = q.Where("content LIKE ?", like)
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		l.Errorf("[admin] count posts: %v", err)
		return nil, errorx.Internal("查询动态失败")
	}

	var rows []model.Post
	offset := int((page - 1) * pageSize)
	if err := q.Preload("TopicTags").Order("id DESC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		l.Errorf("[admin] list posts: %v", err)
		return nil, errorx.Internal("查询动态失败")
	}

	userIDs := make([]uint, 0, len(rows))
	for _, p := range rows {
		userIDs = append(userIDs, p.UserID)
	}
	userMap := map[uint]model.User{}
	if len(userIDs) > 0 {
		var users []model.User
		_ = l.svcCtx.DB.Where("id IN ?", userIDs).Find(&users).Error
		for _, u := range users {
			userMap[u.ID] = u
		}
	}

	posts := make([]*super.Post, len(rows))
	for i, post := range rows {
		user := userMap[post.UserID]
		posts[i] = buildSuperPost(post, user, false)
	}

	return &super.AdminListPostsResp{
		Posts: posts,
		Total: int32(total),
	}, nil
}
