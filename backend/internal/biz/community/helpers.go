package communitybiz

import (
	"context"
	"strconv"
	"strings"
	"time"

	"backend/model"
	"backend/rpc/pb/moe"
)

func parseGroupID(raw string) (uint64, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return 0, ErrInvalidGroupID
	}
	id, err := strconv.ParseUint(raw, 10, 64)
	if err != nil || id == 0 {
		return 0, ErrInvalidGroupID
	}
	return id, nil
}

func parseUserID(raw string) (uint64, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return 0, ErrInvalidUserID
	}
	id, err := strconv.ParseUint(raw, 10, 64)
	if err != nil || id == 0 {
		return 0, ErrInvalidUserID
	}
	return id, nil
}

func parsePostID(raw string) (uint64, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return 0, ErrInvalidPostID
	}
	id, err := strconv.ParseUint(raw, 10, 64)
	if err != nil || id == 0 {
		return 0, ErrInvalidPostID
	}
	return id, nil
}

func optionalUserID(raw string) uint {
	if raw == "" {
		return 0
	}
	id, err := strconv.ParseUint(raw, 10, 64)
	if err != nil {
		return 0
	}
	return uint(id)
}

func memberStatus(ctx context.Context, store CommunityStore, groupID uint, viewerUserID string) (bool, string) {
	if viewerUserID == "" {
		return false, ""
	}
	userID, err := strconv.ParseUint(viewerUserID, 10, 64)
	if err != nil {
		return false, ""
	}
	member, ok, err := store.FindGroupMemberOptional(ctx, groupID, uint(userID))
	if err != nil || !ok {
		return false, ""
	}
	return true, member.Role
}

func groupToProto(ctx context.Context, store CommunityStore, group model.Group, viewerUserID string, createdAtLayout string) *moe.Group {
	if createdAtLayout == "" {
		createdAtLayout = "2006-01-02 15:04:05"
	}
	creator, _ := store.GetUser(ctx, group.CreatorID)
	isJoined, userRole := memberStatus(ctx, store, group.ID, viewerUserID)
	return &moe.Group{
		Id:          uint64(group.ID),
		Name:        group.Name,
		Description: group.Description,
		Avatar:      group.Avatar,
		Cover:       group.Cover,
		CreatorId:   uint64(group.CreatorID),
		CreatorName: creator.Username,
		MemberCount: int32(group.MemberCount),
		IsPublic:    group.IsPublic,
		Status:      group.Status,
		CreatedAt:   group.CreatedAt.Format(createdAtLayout),
		IsJoined:    isJoined,
		UserRole:    userRole,
	}
}

func memberToProto(ctx context.Context, store CommunityStore, member model.GroupMember) *moe.GroupMember {
	user, _ := store.GetUser(ctx, member.UserID)
	return &moe.GroupMember{
		Id:         uint64(member.ID),
		GroupId:    uint64(member.GroupID),
		UserId:     uint64(member.UserID),
		UserName:   user.Username,
		UserAvatar: user.Avatar,
		Role:       member.Role,
		JoinAt:     member.JoinAt.Format("2006-01-02 15:04:05"),
		CreatedAt:  member.CreatedAt.Format("2006-01-02 15:04:05"),
	}
}

func groupToProtoWithMember(ctx context.Context, store CommunityStore, group model.Group, member model.GroupMember) *moe.Group {
	g := groupToProto(ctx, store, group, strconv.FormatUint(uint64(member.UserID), 10), "2006-01-02 15:04:05")
	g.IsJoined = true
	g.UserRole = member.Role
	return g
}

func nowJoinAt() time.Time {
	return time.Now()
}
