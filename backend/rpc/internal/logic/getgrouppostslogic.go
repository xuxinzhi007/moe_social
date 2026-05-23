package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetGroupPostsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetGroupPostsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetGroupPostsLogic {
	return &GetGroupPostsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetGroupPostsLogic) GetGroupPosts(in *super.GetGroupPostsReq) (*super.GetGroupPostsResp, error) {
	groupID, err := strconv.ParseUint(in.GetGroupId(), 10, 64)
	if err != nil || groupID == 0 {
		return &super.GetGroupPostsResp{Posts: []*super.GroupPost{}, Total: 0}, nil
	}

	page := in.GetPage()
	pageSize := in.GetPageSize()
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 10
	}
	if pageSize > 100 {
		pageSize = 100
	}
	offset := (page - 1) * pageSize

	var viewerUID uint
	if in.GetUserId() != "" {
		if v, e := strconv.ParseUint(in.GetUserId(), 10, 32); e == nil {
			viewerUID = uint(v)
		}
	}

	db := l.svcCtx.DB
	base := db.Model(&model.GroupPost{}).Where("group_id = ?", groupID)

	var total int64
	if err := base.Count(&total).Error; err != nil {
		return nil, err
	}

	var links []model.GroupPost
	if err := base.Order("created_at DESC").Offset(int(offset)).Limit(int(pageSize)).Find(&links).Error; err != nil {
		return nil, err
	}
	if len(links) == 0 {
		return &super.GetGroupPostsResp{Posts: []*super.GroupPost{}, Total: int32(total)}, nil
	}

	postIDs := make([]uint, 0, len(links))
	for _, link := range links {
		postIDs = append(postIDs, link.PostID)
	}

	var posts []model.Post
	if err := db.Preload("TopicTags").
		Model(&model.Post{}).
		Scopes(moderationVisibleScope(viewerUID)).
		Where("id IN ?", postIDs).
		Find(&posts).Error; err != nil {
		return nil, err
	}

	postMap := make(map[uint]model.Post, len(posts))
	userIDs := make([]uint, 0, len(posts))
	for _, p := range posts {
		postMap[p.ID] = p
		userIDs = append(userIDs, p.UserID)
	}

	userMap := make(map[uint]model.User)
	if len(userIDs) > 0 {
		var users []model.User
		db.Where("id IN ?", userIDs).Find(&users)
		for _, u := range users {
			userMap[u.ID] = u
		}
	}

	visiblePostIDs := make([]uint, 0, len(posts))
	for id := range postMap {
		visiblePostIDs = append(visiblePostIDs, id)
	}
	likedPosts := LikedTargetIDSet(db, viewerUID, "post", visiblePostIDs)

	out := make([]*super.GroupPost, 0, len(links))
	for _, link := range links {
		post, ok := postMap[link.PostID]
		if !ok {
			continue
		}
		user := userMap[post.UserID]
		out = append(out, &super.GroupPost{
			Id:        uint64(link.ID),
			GroupId:   uint64(link.GroupID),
			PostId:    uint64(link.PostID),
			Post:      buildSuperPost(post, user, likedPosts[post.ID]),
			CreatedAt: link.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}

	return &super.GetGroupPostsResp{
		Posts: out,
		Total: int32(total),
	}, nil
}
