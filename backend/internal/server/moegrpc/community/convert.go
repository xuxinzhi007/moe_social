package communitygrpc

import (
	communityv1 "backend/api/community/v1"
	moerpc "backend/rpc/pb/moe"
)

func groupToProto(in *moerpc.Group) *communityv1.Group {
	if in == nil {
		return nil
	}
	return &communityv1.Group{
		Id: in.GetId(), Name: in.GetName(), Description: in.GetDescription(),
		Avatar: in.GetAvatar(), Cover: in.GetCover(), CreatorId: in.GetCreatorId(),
		CreatorName: in.GetCreatorName(), MemberCount: in.GetMemberCount(),
		IsPublic: in.GetIsPublic(), Status: in.GetStatus(), CreatedAt: in.GetCreatedAt(),
		IsJoined: in.GetIsJoined(), UserRole: in.GetUserRole(),
	}
}

func groupsToProto(rows []*moerpc.Group) []*communityv1.Group {
	out := make([]*communityv1.Group, 0, len(rows))
	for _, row := range rows {
		out = append(out, groupToProto(row))
	}
	return out
}
