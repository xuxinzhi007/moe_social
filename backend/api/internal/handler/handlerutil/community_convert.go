package handlerutil

import (
	"strconv"

	"backend/api/internal/types"
	"backend/rpc/pb/moe"
)

// GroupFromRPC proto Group → API types。
func GroupFromRPC(g *moe.Group) types.Group {
	if g == nil {
		return types.Group{}
	}
	return types.Group{
		Id:          strconv.FormatUint(g.GetId(), 10),
		Name:        g.GetName(),
		Description: g.GetDescription(),
		Avatar:      g.GetAvatar(),
		Cover:       g.GetCover(),
		CreatorId:   strconv.FormatUint(g.GetCreatorId(), 10),
		CreatorName: g.GetCreatorName(),
		MemberCount: int(g.GetMemberCount()),
		IsPublic:    g.GetIsPublic(),
		Status:      g.GetStatus(),
		CreatedAt:   g.GetCreatedAt(),
		IsJoined:    g.GetIsJoined(),
		UserRole:    g.GetUserRole(),
	}
}

// GroupsFromRPC proto Group 列表 → API types。
func GroupsFromRPC(groups []*moe.Group) []types.Group {
	out := make([]types.Group, len(groups))
	for i, g := range groups {
		out[i] = GroupFromRPC(g)
	}
	return out
}

// GroupPostFromRPC proto GroupPost → API types。
func GroupPostFromRPC(gp *moe.GroupPost) types.GroupPost {
	if gp == nil {
		return types.GroupPost{}
	}
	return types.GroupPost{
		Id:        strconv.FormatUint(gp.GetId(), 10),
		GroupId:   strconv.FormatUint(gp.GetGroupId(), 10),
		PostId:    strconv.FormatUint(gp.GetPostId(), 10),
		Post:      PostFromRPC(gp.GetPost()),
		CreatedAt: gp.GetCreatedAt(),
	}
}

// GroupPostsFromRPC proto GroupPost 列表 → API types。
func GroupPostsFromRPC(posts []*moe.GroupPost) []types.GroupPost {
	out := make([]types.GroupPost, 0, len(posts))
	for _, gp := range posts {
		out = append(out, GroupPostFromRPC(gp))
	}
	return out
}

// GroupMemberFromRPC proto GroupMember → API types。
func GroupMemberFromRPC(m *moe.GroupMember) types.GroupMember {
	if m == nil {
		return types.GroupMember{}
	}
	return types.GroupMember{
		Id:         strconv.FormatUint(m.GetId(), 10),
		GroupId:    strconv.FormatUint(m.GetGroupId(), 10),
		UserId:     strconv.FormatUint(m.GetUserId(), 10),
		UserName:   m.GetUserName(),
		UserAvatar: m.GetUserAvatar(),
		Role:       m.GetRole(),
		JoinAt:     m.GetJoinAt(),
		CreatedAt:  m.GetCreatedAt(),
	}
}

// GroupMembersFromRPC proto GroupMember 列表 → API types。
func GroupMembersFromRPC(members []*moe.GroupMember) []types.GroupMember {
	out := make([]types.GroupMember, len(members))
	for i, m := range members {
		out[i] = GroupMemberFromRPC(m)
	}
	return out
}
