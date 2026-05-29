package communitybiz

import (
	"context"
	"errors"

	communityv1 "backend/api/community/v1"
	postbiz "backend/internal/biz/post"
	"backend/model"

	"gorm.io/gorm"
)

// ListGroups 群组列表。
func ListGroups(ctx context.Context, store CommunityStore, in *communityv1.GetGroupsRequest) (*communityv1.GetGroupsReply, error) {
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
	out := make([]*communityv1.Group, len(groups))
	for i, group := range groups {
		out[i] = groupToProto(ctx, store, group, in.GetUserId(), "2006-01-02 15:04:05")
	}
	return &communityv1.GetGroupsReply{Groups: out, Total: int32(total)}, nil
}

// GetGroup 群组详情。
func GetGroup(ctx context.Context, store CommunityStore, in *communityv1.GetGroupRequest) (*communityv1.GetGroupReply, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	groupID, err := parseGroupID(in.GetGroupId())
	if err != nil {
		return &communityv1.GetGroupReply{Success: false, Message: "invalid group id"}, nil
	}
	group, err := store.GetGroupByID(ctx, uint(groupID))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return &communityv1.GetGroupReply{Success: false, Message: "group not found"}, nil
		}
		return nil, err
	}
	return &communityv1.GetGroupReply{
		Success: true,
		Message: "success",
		Group:   groupToProto(ctx, store, group, in.GetUserId(), "2006-01-02 15:04:05"),
	}, nil
}

// ListUserGroups 用户已加入群组。
func ListUserGroups(ctx context.Context, store CommunityStore, in *communityv1.GetUserGroupsRequest) (*communityv1.GetUserGroupsReply, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := parseUserID(in.GetUserId())
	if err != nil {
		return &communityv1.GetUserGroupsReply{}, nil
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
	out := make([]*communityv1.Group, 0, len(members))
	for _, member := range members {
		if group, ok := groupMap[member.GroupID]; ok {
			out = append(out, groupToProtoWithMember(ctx, store, group, member))
		}
	}
	return &communityv1.GetUserGroupsReply{Groups: out, Total: int32(total)}, nil
}

// ListGroupMembers 群组成员。
func ListGroupMembers(ctx context.Context, store CommunityStore, in *communityv1.GetGroupMembersRequest) (*communityv1.GetGroupMembersReply, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	groupID, err := parseGroupID(in.GetGroupId())
	if err != nil {
		return &communityv1.GetGroupMembersReply{}, nil
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
	out := make([]*communityv1.GroupMember, len(members))
	for i, member := range members {
		out[i] = memberToProto(ctx, store, member)
	}
	return &communityv1.GetGroupMembersReply{Members: out, Total: int32(total)}, nil
}

// ListGroupPosts 群组帖子。
func ListGroupPosts(ctx context.Context, store CommunityStore, postStore postbiz.PostStore, in *communityv1.GetGroupPostsRequest) (*communityv1.GetGroupPostsReply, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	groupID, err := parseGroupID(in.GetGroupId())
	if err != nil || groupID == 0 {
		return &communityv1.GetGroupPostsReply{Posts: []*communityv1.GroupPost{}, Total: 0}, nil
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
		return &communityv1.GetGroupPostsReply{Posts: []*communityv1.GroupPost{}, Total: int32(total)}, nil
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
	out := make([]*communityv1.GroupPost, 0, len(links))
	for _, link := range links {
		post, ok := postMap[link.PostID]
		if !ok {
			continue
		}
		user := userMap[post.UserID]
		out = append(out, &communityv1.GroupPost{
			Id:        uint64(link.ID),
			GroupId:   uint64(link.GroupID),
			PostId:    uint64(link.PostID),
			Post:      postbiz.BuildPostV1(post, user, liked[post.ID]),
			CreatedAt: link.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}
	return &communityv1.GetGroupPostsReply{Posts: out, Total: int32(total)}, nil
}
