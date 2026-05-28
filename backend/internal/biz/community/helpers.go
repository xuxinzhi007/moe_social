package communitybiz

import (
	"strconv"
	"strings"
	"time"

	"backend/model"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
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

func memberStatus(db *gorm.DB, groupID uint, viewerUserID string) (bool, string) {
	if viewerUserID == "" {
		return false, ""
	}
	userID, err := strconv.ParseUint(viewerUserID, 10, 64)
	if err != nil {
		return false, ""
	}
	var member model.GroupMember
	if err := db.Where("group_id = ? AND user_id = ?", groupID, userID).First(&member).Error; err != nil {
		return false, ""
	}
	return true, member.Role
}

func groupToProto(db *gorm.DB, group model.Group, viewerUserID string, createdAtLayout string) *moe.Group {
	if createdAtLayout == "" {
		createdAtLayout = "2006-01-02 15:04:05"
	}
	var creator model.User
	_ = db.First(&creator, group.CreatorID).Error
	isJoined, userRole := memberStatus(db, group.ID, viewerUserID)
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

func memberToProto(db *gorm.DB, member model.GroupMember) *moe.GroupMember {
	var user model.User
	_ = db.First(&user, member.UserID).Error
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

func groupToProtoWithMember(db *gorm.DB, group model.Group, member model.GroupMember) *moe.Group {
	g := groupToProto(db, group, strconv.FormatUint(uint64(member.UserID), 10), "2006-01-02 15:04:05")
	g.IsJoined = true
	g.UserRole = member.Role
	return g
}

func nowJoinAt() time.Time {
	return time.Now()
}
