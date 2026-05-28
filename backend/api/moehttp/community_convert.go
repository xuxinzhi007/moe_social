package moehttp

import (
	"strconv"

	"backend/api/internal/types"
	"backend/rpc/pb/moe"
)

func groupFromRPC(g *moe.Group) types.Group {
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

func groupPostFromRPC(gp *moe.GroupPost) types.GroupPost {
	if gp == nil {
		return types.GroupPost{}
	}
	return types.GroupPost{
		Id:        strconv.FormatUint(gp.GetId(), 10),
		GroupId:   strconv.FormatUint(gp.GetGroupId(), 10),
		PostId:    strconv.FormatUint(gp.GetPostId(), 10),
		Post:      postFromRPC(gp.GetPost()),
		CreatedAt: gp.GetCreatedAt(),
	}
}
