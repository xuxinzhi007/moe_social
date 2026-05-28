package communitybiz

import (
	"context"
	"errors"

	postbiz "backend/internal/biz/post"
	"backend/model"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

// ListGroups 群组列表。
func ListGroups(ctx context.Context, store CommunityStore, in *moe.GetGroupsReq) (*moe.GetGroupsResp, error) {
	if store == nil {
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
	offset := (int(page) - 1) * int(pageSize)
	groups, total, err := store.ListActiveGroups(ctx, in.GetKeyword(), in.GetIsPublic(), offset, int(pageSize))
	if err != nil {
		return nil, err
	}
	out := make([]*moe.Group, len(groups))
	for i, group := range groups {
		out[i] = groupToProto(ctx, store, group, in.GetUserId(), "2006-01-02 15:04:05")
	}
	return &moe.GetGroupsResp{Groups: out, Total: int32(total)}, nil
}

// GetGroup 群组详情。
func GetGroup(ctx context.Context, store CommunityStore, in *moe.GetGroupReq) (*moe.GetGroupResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	groupID, err := parseGroupID(in.GetGroupId())
	if err != nil {
		return &moe.GetGroupResp{Success: false, Message: "invalid group id"}, nil
	}
	group, err := store.GetGroupByID(ctx, uint(groupID))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return &moe.GetGroupResp{Success: false, Message: "group not found"}, nil
		}
		return nil, err
	}
	return &moe.GetGroupResp{
		Success: true,
		Message: "success",
		Group:   groupToProto(ctx, store, group, in.GetUserId(), "2006-01-02 15:04:05"),
	}, nil
}

// ListUserGroups 用户已加入群组。
func ListUserGroups(ctx context.Context, store CommunityStore, in *moe.GetUserGroupsReq) (*moe.GetUserGroupsResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := parseUserID(in.GetUserId())
	if err != nil {
		return &moe.GetUserGroupsResp{}, nil
	}
	page := in.GetPage()
	pageSize := in.GetPageSize()
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 10
	}
	offset := (int(page) - 1) * int(pageSize)
	total, err := store.CountUserMemberships(ctx, uint(userID))
	if err != nil {
		return nil, err
	}
	members, err := store.ListUserMemberships(ctx, uint(userID), offset, int(pageSize))
	if err != nil {
		return nil, err
	}
	groupIDs := make([]uint, len(members))
	for i, m := range members {
		groupIDs[i] = m.GroupID
	}
	groupMap := map[uint]model.Group{}
	if len(groupIDs) > 0 {
		groups, _ := store.FindGroupsByIDs(ctx, groupIDs)
		for _, g := range groups {
			groupMap[g.ID] = g
		}
	}
	out := make([]*moe.Group, 0, len(members))
	for _, member := range members {
		if group, ok := groupMap[member.GroupID]; ok {
			out = append(out, groupToProtoWithMember(ctx, store, group, member))
		}
	}
	return &moe.GetUserGroupsResp{Groups: out, Total: int32(total)}, nil
}

// ListGroupMembers 群组成员。
func ListGroupMembers(ctx context.Context, store CommunityStore, in *moe.GetGroupMembersReq) (*moe.GetGroupMembersResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	groupID, err := parseGroupID(in.GetGroupId())
	if err != nil {
		return &moe.GetGroupMembersResp{}, nil
	}
	page := in.GetPage()
	pageSize := in.GetPageSize()
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 10
	}
	offset := (int(page) - 1) * int(pageSize)
	total, err := store.CountGroupMembers(ctx, uint(groupID))
	if err != nil {
		return nil, err
	}
	members, err := store.ListGroupMembers(ctx, uint(groupID), offset, int(pageSize))
	if err != nil {
		return nil, err
	}
	out := make([]*moe.GroupMember, len(members))
	for i, member := range members {
		out[i] = memberToProto(ctx, store, member)
	}
	return &moe.GetGroupMembersResp{Members: out, Total: int32(total)}, nil
}

// ListGroupPosts 群组帖子。
func ListGroupPosts(ctx context.Context, store CommunityStore, postStore postbiz.PostStore, in *moe.GetGroupPostsReq) (*moe.GetGroupPostsResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	groupID, err := parseGroupID(in.GetGroupId())
	if err != nil || groupID == 0 {
		return &moe.GetGroupPostsResp{Posts: []*moe.GroupPost{}, Total: 0}, nil
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
	offset := int((page - 1) * pageSize)
	total, err := store.CountGroupPostLinks(ctx, uint(groupID))
	if err != nil {
		return nil, err
	}
	links, err := store.ListGroupPostLinks(ctx, uint(groupID), offset, int(pageSize))
	if err != nil {
		return nil, err
	}
	if len(links) == 0 {
		return &moe.GetGroupPostsResp{Posts: []*moe.GroupPost{}, Total: int32(total)}, nil
	}
	postIDs := make([]uint, 0, len(links))
	for _, link := range links {
		postIDs = append(postIDs, link.PostID)
	}
	posts, err := store.FindVisiblePostsByIDs(ctx, postIDs, viewerUID)
	if err != nil {
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
		users, _ := store.FindUsersByIDs(ctx, userIDs)
		for _, u := range users {
			userMap[u.ID] = u
		}
	}
	visiblePostIDs := make([]uint, 0, len(posts))
	for id := range postMap {
		visiblePostIDs = append(visiblePostIDs, id)
	}
	liked := postbiz.LikedTargetIDSet(ctx, postStore, viewerUID, "post", visiblePostIDs)
	out := make([]*moe.GroupPost, 0, len(links))
	for _, link := range links {
		post, ok := postMap[link.PostID]
		if !ok {
			continue
		}
		user := userMap[post.UserID]
		out = append(out, &moe.GroupPost{
			Id:        uint64(link.ID),
			GroupId:   uint64(link.GroupID),
			PostId:    uint64(link.PostID),
			Post:      postbiz.BuildProtoPost(post, user, liked[post.ID]),
			CreatedAt: link.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}
	return &moe.GetGroupPostsResp{Posts: out, Total: int32(total)}, nil
}
