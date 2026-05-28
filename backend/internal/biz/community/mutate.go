package communitybiz

import (
	"context"
	"errors"
	"time"

	postbiz "backend/internal/biz/post"
	"backend/model"
	"backend/rpc/pb/moe"

	"gorm.io/gorm"
)

// CreateGroup 创建群组。
func CreateGroup(ctx context.Context, store CommunityStore, in *moe.CreateGroupReq) (*moe.CreateGroupResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	userID, err := parseUserID(in.GetUserId())
	if err != nil {
		return &moe.CreateGroupResp{Success: false, Message: "invalid user id"}, nil
	}
	tx, err := store.Begin(ctx)
	if err != nil {
		return nil, err
	}
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
	if err := tx.CreateGroup(&group); err != nil {
		_ = tx.Rollback()
		return &moe.CreateGroupResp{Success: false, Message: "failed to create group: " + err.Error()}, nil
	}
	member := model.GroupMember{
		GroupID: group.ID,
		UserID:  uint(userID),
		Role:    "admin",
		JoinAt:  nowJoinAt(),
	}
	if err := tx.CreateGroupMember(&member); err != nil {
		_ = tx.Rollback()
		return &moe.CreateGroupResp{Success: false, Message: "failed to add member: " + err.Error()}, nil
	}
	if err := tx.Commit(); err != nil {
		return &moe.CreateGroupResp{Success: false, Message: "failed to commit transaction: " + err.Error()}, nil
	}
	g := groupToProto(ctx, store, group, in.GetUserId(), time.RFC3339)
	g.IsJoined = true
	g.UserRole = "admin"
	return &moe.CreateGroupResp{Success: true, Message: "success", Group: g}, nil
}

// JoinGroup 加入群组。
func JoinGroup(ctx context.Context, store CommunityStore, in *moe.JoinGroupReq) (*moe.JoinGroupResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	groupID, err := parseGroupID(in.GetGroupId())
	if err != nil {
		return &moe.JoinGroupResp{Success: false, Message: "invalid group id"}, nil
	}
	userID, err := parseUserID(in.GetUserId())
	if err != nil {
		return &moe.JoinGroupResp{Success: false, Message: "invalid user id"}, nil
	}
	tx, err := store.Begin(ctx)
	if err != nil {
		return nil, err
	}
	group, err := tx.GetGroup(uint(groupID))
	if err != nil {
		_ = tx.Rollback()
		return &moe.JoinGroupResp{Success: false, Message: "group not found"}, nil
	}
	if _, ok, err := tx.FindGroupMemberOptional(uint(groupID), uint(userID)); err != nil {
		_ = tx.Rollback()
		return nil, err
	} else if ok {
		_ = tx.Rollback()
		return &moe.JoinGroupResp{Success: true, Message: "already joined"}, nil
	}
	if !group.IsPublic {
		_ = tx.Rollback()
		return &moe.JoinGroupResp{Success: false, Message: "this group is private"}, nil
	}
	member := model.GroupMember{
		GroupID: uint(groupID),
		UserID:  uint(userID),
		Role:    "member",
		JoinAt:  nowJoinAt(),
	}
	if err := tx.CreateGroupMember(&member); err != nil {
		_ = tx.Rollback()
		return &moe.JoinGroupResp{Success: false, Message: "failed to join group: " + err.Error()}, nil
	}
	if err := tx.UpdateGroupMemberCount(&group, group.MemberCount+1); err != nil {
		_ = tx.Rollback()
		return &moe.JoinGroupResp{Success: false, Message: "failed to update member count: " + err.Error()}, nil
	}
	if err := tx.Commit(); err != nil {
		return &moe.JoinGroupResp{Success: false, Message: "failed to commit transaction: " + err.Error()}, nil
	}
	return &moe.JoinGroupResp{Success: true, Message: "joined successfully"}, nil
}

// LeaveGroup 退出群组。
func LeaveGroup(ctx context.Context, store CommunityStore, in *moe.LeaveGroupReq) (*moe.LeaveGroupResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	groupID, err := parseGroupID(in.GetGroupId())
	if err != nil {
		return &moe.LeaveGroupResp{Success: false, Message: "invalid group id"}, nil
	}
	userID, err := parseUserID(in.GetUserId())
	if err != nil {
		return &moe.LeaveGroupResp{Success: false, Message: "invalid user id"}, nil
	}
	tx, err := store.Begin(ctx)
	if err != nil {
		return nil, err
	}
	group, err := tx.GetGroup(uint(groupID))
	if err != nil {
		_ = tx.Rollback()
		return &moe.LeaveGroupResp{Success: false, Message: "group not found"}, nil
	}
	member, ok, err := tx.FindGroupMemberOptional(uint(groupID), uint(userID))
	if err != nil {
		_ = tx.Rollback()
		return nil, err
	}
	if !ok {
		_ = tx.Rollback()
		return &moe.LeaveGroupResp{Success: false, Message: "not a member of this group"}, nil
	}
	if err := tx.DeleteGroupMember(&member); err != nil {
		_ = tx.Rollback()
		return &moe.LeaveGroupResp{Success: false, Message: "failed to leave group: " + err.Error()}, nil
	}
	if err := tx.UpdateGroupMemberCount(&group, group.MemberCount-1); err != nil {
		_ = tx.Rollback()
		return &moe.LeaveGroupResp{Success: false, Message: "failed to update member count: " + err.Error()}, nil
	}
	if err := tx.Commit(); err != nil {
		return &moe.LeaveGroupResp{Success: false, Message: "failed to commit transaction: " + err.Error()}, nil
	}
	return &moe.LeaveGroupResp{Success: true, Message: "left successfully"}, nil
}

// DeleteGroup 删除群组。
func DeleteGroup(ctx context.Context, store CommunityStore, in *moe.DeleteGroupReq) (*moe.DeleteGroupResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	groupID, err := parseGroupID(in.GetGroupId())
	if err != nil {
		return &moe.DeleteGroupResp{Success: false, Message: "invalid group id"}, nil
	}
	tx, err := store.Begin(ctx)
	if err != nil {
		return nil, err
	}
	group, err := tx.GetGroup(uint(groupID))
	if err != nil {
		_ = tx.Rollback()
		return &moe.DeleteGroupResp{Success: false, Message: "group not found"}, nil
	}
	if err := tx.DeleteGroupMembersByGroupID(uint(groupID)); err != nil {
		_ = tx.Rollback()
		return &moe.DeleteGroupResp{Success: false, Message: "failed to delete group members: " + err.Error()}, nil
	}
	if err := tx.DeleteGroup(&group); err != nil {
		_ = tx.Rollback()
		return &moe.DeleteGroupResp{Success: false, Message: "failed to delete group: " + err.Error()}, nil
	}
	if err := tx.Commit(); err != nil {
		return &moe.DeleteGroupResp{Success: false, Message: "failed to commit transaction: " + err.Error()}, nil
	}
	return &moe.DeleteGroupResp{Success: true, Message: "deleted successfully"}, nil
}

// UpdateGroup 更新群组资料。
func UpdateGroup(ctx context.Context, store CommunityStore, in *moe.UpdateGroupReq) (*moe.UpdateGroupResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	groupID, err := parseGroupID(in.GetGroupId())
	if err != nil {
		return &moe.UpdateGroupResp{Success: false, Message: "invalid group id"}, nil
	}
	if _, err := store.GetGroupByID(ctx, uint(groupID)); err != nil {
		return &moe.UpdateGroupResp{Success: false, Message: "group not found"}, nil
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
	if err := store.UpdateGroupFields(ctx, uint(groupID), updates); err != nil {
		return &moe.UpdateGroupResp{Success: false, Message: "failed to update group: " + err.Error()}, nil
	}
	group, _ := store.GetGroupByID(ctx, uint(groupID))
	return &moe.UpdateGroupResp{
		Success: true,
		Message: "success",
		Group:   groupToProto(ctx, store, group, "", "2006-01-02 15:04:05"),
	}, nil
}

// CreateGroupPost 将帖子关联到群组。
func CreateGroupPost(ctx context.Context, store CommunityStore, postStore postbiz.PostStore, in *moe.CreateGroupPostReq) (*moe.CreateGroupPostResp, error) {
	if store == nil {
		return nil, gorm.ErrInvalidDB
	}
	groupID, err := parseGroupID(in.GetGroupId())
	if err != nil {
		return &moe.CreateGroupPostResp{Success: false, Message: "invalid group id"}, nil
	}
	postID, err := parsePostID(in.GetPostId())
	if err != nil {
		return &moe.CreateGroupPostResp{Success: false, Message: "invalid post id"}, nil
	}
	userID, err := parseUserID(in.GetUserId())
	if err != nil {
		return &moe.CreateGroupPostResp{Success: false, Message: "invalid user id"}, nil
	}
	if _, err := store.GetGroupByID(ctx, uint(groupID)); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return &moe.CreateGroupPostResp{Success: false, Message: "group not found"}, nil
		}
		return nil, err
	}
	if _, err := store.FindGroupMember(ctx, uint(groupID), uint(userID)); err != nil {
		return &moe.CreateGroupPostResp{Success: false, Message: "join the group before posting"}, nil
	}
	post, err := store.GetPostWithTags(ctx, uint(postID))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return &moe.CreateGroupPostResp{Success: false, Message: "post not found"}, nil
		}
		return nil, err
	}
	if post.UserID != uint(userID) {
		return &moe.CreateGroupPostResp{Success: false, Message: "only the post author can link it to a group"}, nil
	}
	if existing, ok, err := store.FindGroupPostLink(ctx, uint(groupID), uint(postID)); err != nil {
		return nil, err
	} else if ok {
		return buildGroupPostResp(ctx, store, postStore, existing, post, uint(userID))
	}
	link := model.GroupPost{GroupID: uint(groupID), PostID: uint(postID)}
	if err := store.CreateGroupPostLink(ctx, &link); err != nil {
		return &moe.CreateGroupPostResp{Success: false, Message: "failed to link post: " + err.Error()}, nil
	}
	return buildGroupPostResp(ctx, store, postStore, link, post, uint(userID))
}

func buildGroupPostResp(ctx context.Context, store CommunityStore, postStore postbiz.PostStore, link model.GroupPost, post model.Post, viewerUID uint) (*moe.CreateGroupPostResp, error) {
	user, err := store.GetUser(ctx, post.UserID)
	if err != nil {
		return &moe.CreateGroupPostResp{Success: false, Message: "author not found"}, nil
	}
	liked := postbiz.LikedTargetIDSet(ctx, postStore, viewerUID, "post", []uint{post.ID})
	return &moe.CreateGroupPostResp{
		Success: true,
		Message: "linked successfully",
		GroupPost: &moe.GroupPost{
			Id:        uint64(link.ID),
			GroupId:   uint64(link.GroupID),
			PostId:    uint64(link.PostID),
			Post:      postbiz.BuildProtoPost(post, user, liked[post.ID]),
			CreatedAt: link.CreatedAt.Format("2006-01-02 15:04:05"),
		},
	}, nil
}
