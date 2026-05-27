package communitybiz

import (
	"context"
	"errors"
	"time"

	postbiz "backend/internal/biz/post"
	"backend/model"
	"backend/rpc/pb/super"

	"gorm.io/gorm"
)

// CreateGroup 创建群组。
func CreateGroup(ctx context.Context, db *gorm.DB, in *super.CreateGroupReq) (*super.CreateGroupResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := parseUserID(in.GetUserId())
	if err != nil {
		return &super.CreateGroupResp{Success: false, Message: "invalid user id"}, nil
	}
	tx := db.WithContext(ctx).Begin()
	group := model.Group{
		Name:        in.GetName(),
		Description: in.GetDescription(),
		Avatar:      in.GetAvatar(),
		Cover:       in.GetCover(),
		CreatorID:   uint(userID),
		MemberCount: 1,
		IsPublic:    in.GetIsPublic(),
		Status:      "active",
	}
	if err := tx.Create(&group).Error; err != nil {
		tx.Rollback()
		return &super.CreateGroupResp{Success: false, Message: "failed to create group: " + err.Error()}, nil
	}
	member := model.GroupMember{
		GroupID: group.ID,
		UserID:  uint(userID),
		Role:    "admin",
		JoinAt:  nowJoinAt(),
	}
	if err := tx.Create(&member).Error; err != nil {
		tx.Rollback()
		return &super.CreateGroupResp{Success: false, Message: "failed to add member: " + err.Error()}, nil
	}
	if err := tx.Commit().Error; err != nil {
		return &super.CreateGroupResp{Success: false, Message: "failed to commit transaction: " + err.Error()}, nil
	}
	g := groupToProto(db, group, in.GetUserId(), time.RFC3339)
	g.IsJoined = true
	g.UserRole = "admin"
	return &super.CreateGroupResp{Success: true, Message: "success", Group: g}, nil
}

// JoinGroup 加入群组。
func JoinGroup(ctx context.Context, db *gorm.DB, in *super.JoinGroupReq) (*super.JoinGroupResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	groupID, err := parseGroupID(in.GetGroupId())
	if err != nil {
		return &super.JoinGroupResp{Success: false, Message: "invalid group id"}, nil
	}
	userID, err := parseUserID(in.GetUserId())
	if err != nil {
		return &super.JoinGroupResp{Success: false, Message: "invalid user id"}, nil
	}
	tx := db.WithContext(ctx).Begin()
	var group model.Group
	if err := tx.First(&group, groupID).Error; err != nil {
		tx.Rollback()
		return &super.JoinGroupResp{Success: false, Message: "group not found"}, nil
	}
	var existing model.GroupMember
	if err := tx.Where("group_id = ? AND user_id = ?", groupID, userID).First(&existing).Error; err == nil {
		tx.Rollback()
		return &super.JoinGroupResp{Success: true, Message: "already joined"}, nil
	}
	if !group.IsPublic {
		tx.Rollback()
		return &super.JoinGroupResp{Success: false, Message: "this group is private"}, nil
	}
	member := model.GroupMember{
		GroupID: uint(groupID),
		UserID:  uint(userID),
		Role:    "member",
		JoinAt:  nowJoinAt(),
	}
	if err := tx.Create(&member).Error; err != nil {
		tx.Rollback()
		return &super.JoinGroupResp{Success: false, Message: "failed to join group: " + err.Error()}, nil
	}
	if err := tx.Model(&group).Update("member_count", group.MemberCount+1).Error; err != nil {
		tx.Rollback()
		return &super.JoinGroupResp{Success: false, Message: "failed to update member count: " + err.Error()}, nil
	}
	if err := tx.Commit().Error; err != nil {
		return &super.JoinGroupResp{Success: false, Message: "failed to commit transaction: " + err.Error()}, nil
	}
	return &super.JoinGroupResp{Success: true, Message: "joined successfully"}, nil
}

// LeaveGroup 退出群组。
func LeaveGroup(ctx context.Context, db *gorm.DB, in *super.LeaveGroupReq) (*super.LeaveGroupResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	groupID, err := parseGroupID(in.GetGroupId())
	if err != nil {
		return &super.LeaveGroupResp{Success: false, Message: "invalid group id"}, nil
	}
	userID, err := parseUserID(in.GetUserId())
	if err != nil {
		return &super.LeaveGroupResp{Success: false, Message: "invalid user id"}, nil
	}
	tx := db.WithContext(ctx).Begin()
	var group model.Group
	if err := tx.First(&group, groupID).Error; err != nil {
		tx.Rollback()
		return &super.LeaveGroupResp{Success: false, Message: "group not found"}, nil
	}
	var member model.GroupMember
	if err := tx.Where("group_id = ? AND user_id = ?", groupID, userID).First(&member).Error; err != nil {
		tx.Rollback()
		return &super.LeaveGroupResp{Success: false, Message: "not a member of this group"}, nil
	}
	if err := tx.Delete(&member).Error; err != nil {
		tx.Rollback()
		return &super.LeaveGroupResp{Success: false, Message: "failed to leave group: " + err.Error()}, nil
	}
	if err := tx.Model(&group).Update("member_count", group.MemberCount-1).Error; err != nil {
		tx.Rollback()
		return &super.LeaveGroupResp{Success: false, Message: "failed to update member count: " + err.Error()}, nil
	}
	if err := tx.Commit().Error; err != nil {
		return &super.LeaveGroupResp{Success: false, Message: "failed to commit transaction: " + err.Error()}, nil
	}
	return &super.LeaveGroupResp{Success: true, Message: "left successfully"}, nil
}

// DeleteGroup 删除群组。
func DeleteGroup(ctx context.Context, db *gorm.DB, in *super.DeleteGroupReq) (*super.DeleteGroupResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	groupID, err := parseGroupID(in.GetGroupId())
	if err != nil {
		return &super.DeleteGroupResp{Success: false, Message: "invalid group id"}, nil
	}
	tx := db.WithContext(ctx).Begin()
	var group model.Group
	if err := tx.First(&group, groupID).Error; err != nil {
		tx.Rollback()
		return &super.DeleteGroupResp{Success: false, Message: "group not found"}, nil
	}
	if err := tx.Where("group_id = ?", groupID).Delete(&model.GroupMember{}).Error; err != nil {
		tx.Rollback()
		return &super.DeleteGroupResp{Success: false, Message: "failed to delete group members: " + err.Error()}, nil
	}
	if err := tx.Delete(&group).Error; err != nil {
		tx.Rollback()
		return &super.DeleteGroupResp{Success: false, Message: "failed to delete group: " + err.Error()}, nil
	}
	if err := tx.Commit().Error; err != nil {
		return &super.DeleteGroupResp{Success: false, Message: "failed to commit transaction: " + err.Error()}, nil
	}
	return &super.DeleteGroupResp{Success: true, Message: "deleted successfully"}, nil
}

// UpdateGroup 更新群组资料。
func UpdateGroup(ctx context.Context, db *gorm.DB, in *super.UpdateGroupReq) (*super.UpdateGroupResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	groupID, err := parseGroupID(in.GetGroupId())
	if err != nil {
		return &super.UpdateGroupResp{Success: false, Message: "invalid group id"}, nil
	}
	var group model.Group
	if err := db.WithContext(ctx).First(&group, groupID).Error; err != nil {
		return &super.UpdateGroupResp{Success: false, Message: "group not found"}, nil
	}
	updates := map[string]interface{}{}
	if in.GetName() != "" {
		updates["name"] = in.GetName()
	}
	if in.GetDescription() != "" {
		updates["description"] = in.GetDescription()
	}
	if in.GetAvatar() != "" {
		updates["avatar"] = in.GetAvatar()
	}
	if in.GetCover() != "" {
		updates["cover"] = in.GetCover()
	}
	if err := db.WithContext(ctx).Model(&group).Updates(updates).Error; err != nil {
		return &super.UpdateGroupResp{Success: false, Message: "failed to update group: " + err.Error()}, nil
	}
	_ = db.WithContext(ctx).First(&group, groupID).Error
	return &super.UpdateGroupResp{
		Success: true,
		Message: "success",
		Group:   groupToProto(db.WithContext(ctx), group, "", "2006-01-02 15:04:05"),
	}, nil
}

// CreateGroupPost 将帖子关联到群组。
func CreateGroupPost(ctx context.Context, db *gorm.DB, in *super.CreateGroupPostReq) (*super.CreateGroupPostResp, error) {
	if db == nil {
		return nil, gorm.ErrInvalidDB
	}
	groupID, err := parseGroupID(in.GetGroupId())
	if err != nil {
		return &super.CreateGroupPostResp{Success: false, Message: "invalid group id"}, nil
	}
	postID, err := parsePostID(in.GetPostId())
	if err != nil {
		return &super.CreateGroupPostResp{Success: false, Message: "invalid post id"}, nil
	}
	userID, err := parseUserID(in.GetUserId())
	if err != nil {
		return &super.CreateGroupPostResp{Success: false, Message: "invalid user id"}, nil
	}
	var group model.Group
	if err := db.WithContext(ctx).First(&group, groupID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return &super.CreateGroupPostResp{Success: false, Message: "group not found"}, nil
		}
		return nil, err
	}
	var member model.GroupMember
	if err := db.WithContext(ctx).Where("group_id = ? AND user_id = ?", groupID, userID).First(&member).Error; err != nil {
		return &super.CreateGroupPostResp{Success: false, Message: "join the group before posting"}, nil
	}
	var post model.Post
	if err := db.WithContext(ctx).Preload("TopicTags").First(&post, postID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return &super.CreateGroupPostResp{Success: false, Message: "post not found"}, nil
		}
		return nil, err
	}
	if post.UserID != uint(userID) {
		return &super.CreateGroupPostResp{Success: false, Message: "only the post author can link it to a group"}, nil
	}
	var existing model.GroupPost
	if err := db.WithContext(ctx).Where("group_id = ? AND post_id = ?", groupID, postID).First(&existing).Error; err == nil {
		return buildGroupPostResp(db.WithContext(ctx), existing, post, uint(userID))
	}
	link := model.GroupPost{GroupID: uint(groupID), PostID: uint(postID)}
	if err := db.WithContext(ctx).Create(&link).Error; err != nil {
		return &super.CreateGroupPostResp{Success: false, Message: "failed to link post: " + err.Error()}, nil
	}
	return buildGroupPostResp(db.WithContext(ctx), link, post, uint(userID))
}

func buildGroupPostResp(db *gorm.DB, link model.GroupPost, post model.Post, viewerUID uint) (*super.CreateGroupPostResp, error) {
	var user model.User
	if err := db.First(&user, post.UserID).Error; err != nil {
		return &super.CreateGroupPostResp{Success: false, Message: "author not found"}, nil
	}
	liked := postbiz.LikedTargetIDSet(db, viewerUID, "post", []uint{post.ID})
	return &super.CreateGroupPostResp{
		Success: true,
		Message: "linked successfully",
		GroupPost: &super.GroupPost{
			Id:        uint64(link.ID),
			GroupId:   uint64(link.GroupID),
			PostId:    uint64(link.PostID),
			Post:      postbiz.BuildProtoPost(post, user, liked[post.ID]),
			CreatedAt: link.CreatedAt.Format("2006-01-02 15:04:05"),
		},
	}, nil
}
