package communityv1

import (
	postv1 "backend/api/post/v1"
	"backend/rpc/pb/moe"
)

func GroupFromMoe(g *moe.Group) *Group {
	if g == nil {
		return nil
	}
	return &Group{
		Id: g.GetId(), Name: g.GetName(), Description: g.GetDescription(),
		Avatar: g.GetAvatar(), Cover: g.GetCover(), CreatorId: g.GetCreatorId(),
		CreatorName: g.GetCreatorName(), MemberCount: g.GetMemberCount(),
		IsPublic: g.GetIsPublic(), Status: g.GetStatus(), CreatedAt: g.GetCreatedAt(),
		IsJoined: g.GetIsJoined(), UserRole: g.GetUserRole(),
	}
}

func GroupToMoe(g *Group) *moe.Group {
	if g == nil {
		return nil
	}
	return &moe.Group{
		Id: g.GetId(), Name: g.GetName(), Description: g.GetDescription(),
		Avatar: g.GetAvatar(), Cover: g.GetCover(), CreatorId: g.GetCreatorId(),
		CreatorName: g.GetCreatorName(), MemberCount: g.GetMemberCount(),
		IsPublic: g.GetIsPublic(), Status: g.GetStatus(), CreatedAt: g.GetCreatedAt(),
		IsJoined: g.GetIsJoined(), UserRole: g.GetUserRole(),
	}
}

func GroupsFromMoe(items []*moe.Group) []*Group {
	if len(items) == 0 {
		return nil
	}
	out := make([]*Group, 0, len(items))
	for _, g := range items {
		if g == nil {
			continue
		}
		out = append(out, GroupFromMoe(g))
	}
	return out
}

func GroupsToMoe(items []*Group) []*moe.Group {
	if len(items) == 0 {
		return nil
	}
	out := make([]*moe.Group, 0, len(items))
	for _, g := range items {
		out = append(out, GroupToMoe(g))
	}
	return out
}

func GroupMemberFromMoe(m *moe.GroupMember) *GroupMember {
	if m == nil {
		return nil
	}
	return &GroupMember{
		Id: m.GetId(), GroupId: m.GetGroupId(), UserId: m.GetUserId(),
		UserName: m.GetUserName(), UserAvatar: m.GetUserAvatar(), Role: m.GetRole(),
		JoinAt: m.GetJoinAt(), CreatedAt: m.GetCreatedAt(),
	}
}

func GroupMemberToMoe(m *GroupMember) *moe.GroupMember {
	if m == nil {
		return nil
	}
	return &moe.GroupMember{
		Id: m.GetId(), GroupId: m.GetGroupId(), UserId: m.GetUserId(),
		UserName: m.GetUserName(), UserAvatar: m.GetUserAvatar(), Role: m.GetRole(),
		JoinAt: m.GetJoinAt(), CreatedAt: m.GetCreatedAt(),
	}
}

func GroupMembersFromMoe(items []*moe.GroupMember) []*GroupMember {
	if len(items) == 0 {
		return nil
	}
	out := make([]*GroupMember, 0, len(items))
	for _, m := range items {
		if m == nil {
			continue
		}
		out = append(out, GroupMemberFromMoe(m))
	}
	return out
}

func GroupMembersToMoe(items []*GroupMember) []*moe.GroupMember {
	if len(items) == 0 {
		return nil
	}
	out := make([]*moe.GroupMember, 0, len(items))
	for _, m := range items {
		out = append(out, GroupMemberToMoe(m))
	}
	return out
}

func GroupPostFromMoe(gp *moe.GroupPost) *GroupPost {
	if gp == nil {
		return nil
	}
	return &GroupPost{
		Id: gp.GetId(), GroupId: gp.GetGroupId(), PostId: gp.GetPostId(),
		Post: postv1.PostFromMoe(gp.GetPost()), CreatedAt: gp.GetCreatedAt(),
	}
}

func GroupPostToMoe(gp *GroupPost) *moe.GroupPost {
	if gp == nil {
		return nil
	}
	return &moe.GroupPost{
		Id: gp.GetId(), GroupId: gp.GetGroupId(), PostId: gp.GetPostId(),
		Post: postv1.PostToMoe(gp.GetPost()), CreatedAt: gp.GetCreatedAt(),
	}
}

func GroupPostsFromMoe(items []*moe.GroupPost) []*GroupPost {
	if len(items) == 0 {
		return nil
	}
	out := make([]*GroupPost, 0, len(items))
	for _, gp := range items {
		if gp == nil {
			continue
		}
		out = append(out, GroupPostFromMoe(gp))
	}
	return out
}

func GroupPostsToMoe(items []*GroupPost) []*moe.GroupPost {
	if len(items) == 0 {
		return nil
	}
	out := make([]*moe.GroupPost, 0, len(items))
	for _, gp := range items {
		out = append(out, GroupPostToMoe(gp))
	}
	return out
}

func GetGroupsRequestFromMoe(in *moe.GetGroupsReq) *GetGroupsRequest {
	if in == nil {
		return &GetGroupsRequest{}
	}
	return &GetGroupsRequest{
		Page: in.GetPage(), PageSize: in.GetPageSize(), Keyword: in.GetKeyword(),
		IsPublic: in.GetIsPublic(), UserId: in.GetUserId(),
	}
}

func GetGroupsRequestToMoe(in *GetGroupsRequest) *moe.GetGroupsReq {
	if in == nil {
		return &moe.GetGroupsReq{}
	}
	return &moe.GetGroupsReq{
		Page: in.GetPage(), PageSize: in.GetPageSize(), Keyword: in.GetKeyword(),
		IsPublic: in.GetIsPublic(), UserId: in.GetUserId(),
	}
}

func GetGroupsReplyFromMoe(out *moe.GetGroupsResp) *GetGroupsReply {
	if out == nil {
		return &GetGroupsReply{}
	}
	return &GetGroupsReply{Groups: GroupsFromMoe(out.GetGroups()), Total: out.GetTotal()}
}

func GetGroupsReplyToMoe(out *GetGroupsReply) *moe.GetGroupsResp {
	if out == nil {
		return &moe.GetGroupsResp{}
	}
	return &moe.GetGroupsResp{Groups: GroupsToMoe(out.GetGroups()), Total: out.GetTotal()}
}

func GetGroupRequestFromMoe(in *moe.GetGroupReq) *GetGroupRequest {
	if in == nil {
		return &GetGroupRequest{}
	}
	return &GetGroupRequest{GroupId: in.GetGroupId(), UserId: in.GetUserId()}
}

func GetGroupRequestToMoe(in *GetGroupRequest) *moe.GetGroupReq {
	if in == nil {
		return &moe.GetGroupReq{}
	}
	return &moe.GetGroupReq{GroupId: in.GetGroupId(), UserId: in.GetUserId()}
}

func GetGroupReplyFromMoe(out *moe.GetGroupResp) *GetGroupReply {
	if out == nil {
		return &GetGroupReply{}
	}
	return &GetGroupReply{
		Success: out.GetSuccess(), Message: out.GetMessage(), Group: GroupFromMoe(out.GetGroup()),
	}
}

func GetGroupReplyToMoe(out *GetGroupReply) *moe.GetGroupResp {
	if out == nil {
		return &moe.GetGroupResp{}
	}
	return &moe.GetGroupResp{
		Success: out.GetSuccess(), Message: out.GetMessage(), Group: GroupToMoe(out.GetGroup()),
	}
}

func CreateGroupRequestFromMoe(in *moe.CreateGroupReq) *CreateGroupRequest {
	if in == nil {
		return &CreateGroupRequest{}
	}
	return &CreateGroupRequest{
		Name: in.GetName(), Description: in.GetDescription(), Avatar: in.GetAvatar(),
		Cover: in.GetCover(), UserId: in.GetUserId(), IsPublic: in.GetIsPublic(),
	}
}

func CreateGroupRequestToMoe(in *CreateGroupRequest) *moe.CreateGroupReq {
	if in == nil {
		return &moe.CreateGroupReq{}
	}
	return &moe.CreateGroupReq{
		Name: in.GetName(), Description: in.GetDescription(), Avatar: in.GetAvatar(),
		Cover: in.GetCover(), UserId: in.GetUserId(), IsPublic: in.GetIsPublic(),
	}
}

func CreateGroupReplyFromMoe(out *moe.CreateGroupResp) *CreateGroupReply {
	if out == nil {
		return &CreateGroupReply{}
	}
	return &CreateGroupReply{
		Success: out.GetSuccess(), Message: out.GetMessage(), Group: GroupFromMoe(out.GetGroup()),
	}
}

func CreateGroupReplyToMoe(out *CreateGroupReply) *moe.CreateGroupResp {
	if out == nil {
		return &moe.CreateGroupResp{}
	}
	return &moe.CreateGroupResp{
		Success: out.GetSuccess(), Message: out.GetMessage(), Group: GroupToMoe(out.GetGroup()),
	}
}

func UpdateGroupRequestFromMoe(in *moe.UpdateGroupReq) *UpdateGroupRequest {
	if in == nil {
		return &UpdateGroupRequest{}
	}
	return &UpdateGroupRequest{
		GroupId: in.GetGroupId(), Name: in.GetName(), Description: in.GetDescription(),
		Avatar: in.GetAvatar(), Cover: in.GetCover(), IsPublic: in.GetIsPublic(),
	}
}

func UpdateGroupRequestToMoe(in *UpdateGroupRequest) *moe.UpdateGroupReq {
	if in == nil {
		return &moe.UpdateGroupReq{}
	}
	return &moe.UpdateGroupReq{
		GroupId: in.GetGroupId(), Name: in.GetName(), Description: in.GetDescription(),
		Avatar: in.GetAvatar(), Cover: in.GetCover(), IsPublic: in.GetIsPublic(),
	}
}

func UpdateGroupReplyFromMoe(out *moe.UpdateGroupResp) *UpdateGroupReply {
	if out == nil {
		return &UpdateGroupReply{}
	}
	return &UpdateGroupReply{
		Success: out.GetSuccess(), Message: out.GetMessage(), Group: GroupFromMoe(out.GetGroup()),
	}
}

func UpdateGroupReplyToMoe(out *UpdateGroupReply) *moe.UpdateGroupResp {
	if out == nil {
		return &moe.UpdateGroupResp{}
	}
	return &moe.UpdateGroupResp{
		Success: out.GetSuccess(), Message: out.GetMessage(), Group: GroupToMoe(out.GetGroup()),
	}
}

func DeleteGroupRequestFromMoe(in *moe.DeleteGroupReq) *DeleteGroupRequest {
	if in == nil {
		return &DeleteGroupRequest{}
	}
	return &DeleteGroupRequest{GroupId: in.GetGroupId(), UserId: in.GetUserId()}
}

func DeleteGroupRequestToMoe(in *DeleteGroupRequest) *moe.DeleteGroupReq {
	if in == nil {
		return &moe.DeleteGroupReq{}
	}
	return &moe.DeleteGroupReq{GroupId: in.GetGroupId(), UserId: in.GetUserId()}
}

func DeleteGroupReplyFromMoe(out *moe.DeleteGroupResp) *DeleteGroupReply {
	if out == nil {
		return &DeleteGroupReply{}
	}
	return &DeleteGroupReply{Success: out.GetSuccess(), Message: out.GetMessage()}
}

func DeleteGroupReplyToMoe(out *DeleteGroupReply) *moe.DeleteGroupResp {
	if out == nil {
		return &moe.DeleteGroupResp{}
	}
	return &moe.DeleteGroupResp{Success: out.GetSuccess(), Message: out.GetMessage()}
}

func JoinGroupRequestFromMoe(in *moe.JoinGroupReq) *JoinGroupRequest {
	if in == nil {
		return &JoinGroupRequest{}
	}
	return &JoinGroupRequest{GroupId: in.GetGroupId(), UserId: in.GetUserId()}
}

func JoinGroupRequestToMoe(in *JoinGroupRequest) *moe.JoinGroupReq {
	if in == nil {
		return &moe.JoinGroupReq{}
	}
	return &moe.JoinGroupReq{GroupId: in.GetGroupId(), UserId: in.GetUserId()}
}

func JoinGroupReplyFromMoe(out *moe.JoinGroupResp) *JoinGroupReply {
	if out == nil {
		return &JoinGroupReply{}
	}
	return &JoinGroupReply{Success: out.GetSuccess(), Message: out.GetMessage()}
}

func JoinGroupReplyToMoe(out *JoinGroupReply) *moe.JoinGroupResp {
	if out == nil {
		return &moe.JoinGroupResp{}
	}
	return &moe.JoinGroupResp{Success: out.GetSuccess(), Message: out.GetMessage()}
}

func LeaveGroupRequestFromMoe(in *moe.LeaveGroupReq) *LeaveGroupRequest {
	if in == nil {
		return &LeaveGroupRequest{}
	}
	return &LeaveGroupRequest{GroupId: in.GetGroupId(), UserId: in.GetUserId()}
}

func LeaveGroupRequestToMoe(in *LeaveGroupRequest) *moe.LeaveGroupReq {
	if in == nil {
		return &moe.LeaveGroupReq{}
	}
	return &moe.LeaveGroupReq{GroupId: in.GetGroupId(), UserId: in.GetUserId()}
}

func LeaveGroupReplyFromMoe(out *moe.LeaveGroupResp) *LeaveGroupReply {
	if out == nil {
		return &LeaveGroupReply{}
	}
	return &LeaveGroupReply{Success: out.GetSuccess(), Message: out.GetMessage()}
}

func LeaveGroupReplyToMoe(out *LeaveGroupReply) *moe.LeaveGroupResp {
	if out == nil {
		return &moe.LeaveGroupResp{}
	}
	return &moe.LeaveGroupResp{Success: out.GetSuccess(), Message: out.GetMessage()}
}

func GetGroupMembersRequestFromMoe(in *moe.GetGroupMembersReq) *GetGroupMembersRequest {
	if in == nil {
		return &GetGroupMembersRequest{}
	}
	return &GetGroupMembersRequest{
		GroupId: in.GetGroupId(), Page: in.GetPage(), PageSize: in.GetPageSize(),
	}
}

func GetGroupMembersRequestToMoe(in *GetGroupMembersRequest) *moe.GetGroupMembersReq {
	if in == nil {
		return &moe.GetGroupMembersReq{}
	}
	return &moe.GetGroupMembersReq{
		GroupId: in.GetGroupId(), Page: in.GetPage(), PageSize: in.GetPageSize(),
	}
}

func GetGroupMembersReplyFromMoe(out *moe.GetGroupMembersResp) *GetGroupMembersReply {
	if out == nil {
		return &GetGroupMembersReply{}
	}
	return &GetGroupMembersReply{Members: GroupMembersFromMoe(out.GetMembers()), Total: out.GetTotal()}
}

func GetGroupMembersReplyToMoe(out *GetGroupMembersReply) *moe.GetGroupMembersResp {
	if out == nil {
		return &moe.GetGroupMembersResp{}
	}
	return &moe.GetGroupMembersResp{Members: GroupMembersToMoe(out.GetMembers()), Total: out.GetTotal()}
}

func GetUserGroupsRequestFromMoe(in *moe.GetUserGroupsReq) *GetUserGroupsRequest {
	if in == nil {
		return &GetUserGroupsRequest{}
	}
	return &GetUserGroupsRequest{
		UserId: in.GetUserId(), Page: in.GetPage(), PageSize: in.GetPageSize(),
	}
}

func GetUserGroupsRequestToMoe(in *GetUserGroupsRequest) *moe.GetUserGroupsReq {
	if in == nil {
		return &moe.GetUserGroupsReq{}
	}
	return &moe.GetUserGroupsReq{
		UserId: in.GetUserId(), Page: in.GetPage(), PageSize: in.GetPageSize(),
	}
}

func GetUserGroupsReplyFromMoe(out *moe.GetUserGroupsResp) *GetUserGroupsReply {
	if out == nil {
		return &GetUserGroupsReply{}
	}
	return &GetUserGroupsReply{Groups: GroupsFromMoe(out.GetGroups()), Total: out.GetTotal()}
}

func GetUserGroupsReplyToMoe(out *GetUserGroupsReply) *moe.GetUserGroupsResp {
	if out == nil {
		return &moe.GetUserGroupsResp{}
	}
	return &moe.GetUserGroupsResp{Groups: GroupsToMoe(out.GetGroups()), Total: out.GetTotal()}
}

func CreateGroupPostRequestFromMoe(in *moe.CreateGroupPostReq) *CreateGroupPostRequest {
	if in == nil {
		return &CreateGroupPostRequest{}
	}
	return &CreateGroupPostRequest{
		GroupId: in.GetGroupId(), PostId: in.GetPostId(), UserId: in.GetUserId(),
	}
}

func CreateGroupPostRequestToMoe(in *CreateGroupPostRequest) *moe.CreateGroupPostReq {
	if in == nil {
		return &moe.CreateGroupPostReq{}
	}
	return &moe.CreateGroupPostReq{
		GroupId: in.GetGroupId(), PostId: in.GetPostId(), UserId: in.GetUserId(),
	}
}

func CreateGroupPostReplyFromMoe(out *moe.CreateGroupPostResp) *CreateGroupPostReply {
	if out == nil {
		return &CreateGroupPostReply{}
	}
	return &CreateGroupPostReply{
		Success: out.GetSuccess(), Message: out.GetMessage(), GroupPost: GroupPostFromMoe(out.GetGroupPost()),
	}
}

func CreateGroupPostReplyToMoe(out *CreateGroupPostReply) *moe.CreateGroupPostResp {
	if out == nil {
		return &moe.CreateGroupPostResp{}
	}
	return &moe.CreateGroupPostResp{
		Success: out.GetSuccess(), Message: out.GetMessage(), GroupPost: GroupPostToMoe(out.GetGroupPost()),
	}
}

func GetGroupPostsRequestFromMoe(in *moe.GetGroupPostsReq) *GetGroupPostsRequest {
	if in == nil {
		return &GetGroupPostsRequest{}
	}
	return &GetGroupPostsRequest{
		GroupId: in.GetGroupId(), Page: in.GetPage(), PageSize: in.GetPageSize(), UserId: in.GetUserId(),
	}
}

func GetGroupPostsRequestToMoe(in *GetGroupPostsRequest) *moe.GetGroupPostsReq {
	if in == nil {
		return &moe.GetGroupPostsReq{}
	}
	return &moe.GetGroupPostsReq{
		GroupId: in.GetGroupId(), Page: in.GetPage(), PageSize: in.GetPageSize(), UserId: in.GetUserId(),
	}
}

func GetGroupPostsReplyFromMoe(out *moe.GetGroupPostsResp) *GetGroupPostsReply {
	if out == nil {
		return &GetGroupPostsReply{}
	}
	return &GetGroupPostsReply{Posts: GroupPostsFromMoe(out.GetPosts()), Total: out.GetTotal()}
}

func GetGroupPostsReplyToMoe(out *GetGroupPostsReply) *moe.GetGroupPostsResp {
	if out == nil {
		return &moe.GetGroupPostsResp{}
	}
	return &moe.GetGroupPostsResp{Posts: GroupPostsToMoe(out.GetPosts()), Total: out.GetTotal()}
}
