package communitybiz

import (
	"context"
	"errors"

	postbiz "backend/internal/biz/post"
	"backend/model"
	"backend/rpc/pb/super"

	"gorm.io/gorm"
)

// ListGroups 群组列表。
func ListGroups(ctx context.Context, db *gorm.DB, in *super.GetGroupsReq) (*super.GetGroupsResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	page := in.GetPage()
	pageSize := in.GetPageSize()
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 10
	}
	q := db.WithContext(ctx).Model(&model.Group{}).Where("status = ?", "active")
	if in.GetIsPublic() {
		q = q.Where("is_public = ?", true)
	}
	if kw := in.GetKeyword(); kw != "" {
		like := "%" + kw + "%"
		q = q.Where("name LIKE ? OR description LIKE ?", like, like)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, err
	}
	var groups []model.Group
	offset := (int(page) - 1) * int(pageSize)
	if err := q.Offset(offset).Limit(int(pageSize)).Find(&groups).Error; err != nil {
		return nil, err
	}
	out := make([]*super.Group, len(groups))
	for i, group := range groups {
		out[i] = groupToProto(db.WithContext(ctx), group, in.GetUserId(), "2006-01-02 15:04:05")
	}
	return &super.GetGroupsResp{Groups: out, Total: int32(total)}, nil
}

// GetGroup 群组详情。
func GetGroup(ctx context.Context, db *gorm.DB, in *super.GetGroupReq) (*super.GetGroupResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	groupID, err := parseGroupID(in.GetGroupId())
	if err != nil {
		return &super.GetGroupResp{Success: false, Message: "invalid group id"}, nil
	}
	var group model.Group
	if err := db.WithContext(ctx).First(&group, groupID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return &super.GetGroupResp{Success: false, Message: "group not found"}, nil
		}
		return nil, err
	}
	return &super.GetGroupResp{
		Success: true,
		Message: "success",
		Group:   groupToProto(db.WithContext(ctx), group, in.GetUserId(), "2006-01-02 15:04:05"),
	}, nil
}

// ListUserGroups 用户已加入群组。
func ListUserGroups(ctx context.Context, db *gorm.DB, in *super.GetUserGroupsReq) (*super.GetUserGroupsResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := parseUserID(in.GetUserId())
	if err != nil {
		return &super.GetUserGroupsResp{}, nil
	}
	page := in.GetPage()
	pageSize := in.GetPageSize()
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 10
	}
	q := db.WithContext(ctx).Model(&model.GroupMember{}).Where("user_id = ?", userID)
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, err
	}
	var members []model.GroupMember
	offset := (int(page) - 1) * int(pageSize)
	if err := q.Offset(offset).Limit(int(pageSize)).Find(&members).Error; err != nil {
		return nil, err
	}
	groupIDs := make([]uint, len(members))
	for i, m := range members {
		groupIDs[i] = m.GroupID
	}
	groupMap := map[uint]model.Group{}
	if len(groupIDs) > 0 {
		var groups []model.Group
		_ = db.WithContext(ctx).Where("id IN ?", groupIDs).Find(&groups).Error
		for _, g := range groups {
			groupMap[g.ID] = g
		}
	}
	out := make([]*super.Group, 0, len(members))
	for _, member := range members {
		if group, ok := groupMap[member.GroupID]; ok {
			out = append(out, groupToProtoWithMember(db.WithContext(ctx), group, member))
		}
	}
	return &super.GetUserGroupsResp{Groups: out, Total: int32(total)}, nil
}

// ListGroupMembers 群组成员。
func ListGroupMembers(ctx context.Context, db *gorm.DB, in *super.GetGroupMembersReq) (*super.GetGroupMembersResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	groupID, err := parseGroupID(in.GetGroupId())
	if err != nil {
		return &super.GetGroupMembersResp{}, nil
	}
	page := in.GetPage()
	pageSize := in.GetPageSize()
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 10
	}
	q := db.WithContext(ctx).Model(&model.GroupMember{}).Where("group_id = ?", groupID)
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, err
	}
	var members []model.GroupMember
	offset := (int(page) - 1) * int(pageSize)
	if err := q.Offset(offset).Limit(int(pageSize)).Find(&members).Error; err != nil {
		return nil, err
	}
	out := make([]*super.GroupMember, len(members))
	for i, member := range members {
		out[i] = memberToProto(db.WithContext(ctx), member)
	}
	return &super.GetGroupMembersResp{Members: out, Total: int32(total)}, nil
}

// ListGroupPosts 群组帖子。
func ListGroupPosts(ctx context.Context, db *gorm.DB, in *super.GetGroupPostsReq) (*super.GetGroupPostsResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	groupID, err := parseGroupID(in.GetGroupId())
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
	viewerUID := optionalUserID(in.GetUserId())
	base := db.WithContext(ctx).Model(&model.GroupPost{}).Where("group_id = ?", groupID)
	var total int64
	if err := base.Count(&total).Error; err != nil {
		return nil, err
	}
	var links []model.GroupPost
	offset := (page - 1) * pageSize
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
	if err := db.WithContext(ctx).Preload("TopicTags").
		Model(&model.Post{}).
		Scopes(postbiz.ModerationVisibleScope(viewerUID)).
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
	userMap := map[uint]model.User{}
	if len(userIDs) > 0 {
		var users []model.User
		_ = db.WithContext(ctx).Where("id IN ?", userIDs).Find(&users).Error
		for _, u := range users {
			userMap[u.ID] = u
		}
	}
	visiblePostIDs := make([]uint, 0, len(posts))
	for id := range postMap {
		visiblePostIDs = append(visiblePostIDs, id)
	}
	liked := postbiz.LikedTargetIDSet(db.WithContext(ctx), viewerUID, "post", visiblePostIDs)
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
			Post:      postbiz.BuildProtoPost(post, user, liked[post.ID]),
			CreatedAt: link.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}
	return &super.GetGroupPostsResp{Posts: out, Total: int32(total)}, nil
}
