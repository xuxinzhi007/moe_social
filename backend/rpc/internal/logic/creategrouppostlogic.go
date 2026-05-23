package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type CreateGroupPostLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewCreateGroupPostLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CreateGroupPostLogic {
	return &CreateGroupPostLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *CreateGroupPostLogic) CreateGroupPost(in *super.CreateGroupPostReq) (*super.CreateGroupPostResp, error) {
	groupID, err := strconv.ParseUint(in.GetGroupId(), 10, 64)
	if err != nil || groupID == 0 {
		return &super.CreateGroupPostResp{Success: false, Message: "invalid group id"}, nil
	}
	postID, err := strconv.ParseUint(in.GetPostId(), 10, 64)
	if err != nil || postID == 0 {
		return &super.CreateGroupPostResp{Success: false, Message: "invalid post id"}, nil
	}
	userID, err := strconv.ParseUint(in.GetUserId(), 10, 64)
	if err != nil || userID == 0 {
		return &super.CreateGroupPostResp{Success: false, Message: "invalid user id"}, nil
	}

	db := l.svcCtx.DB

	var group model.Group
	if err := db.First(&group, groupID).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return &super.CreateGroupPostResp{Success: false, Message: "group not found"}, nil
		}
		return nil, err
	}

	var member model.GroupMember
	if err := db.Where("group_id = ? AND user_id = ?", groupID, userID).First(&member).Error; err != nil {
		return &super.CreateGroupPostResp{Success: false, Message: "join the group before posting"}, nil
	}

	var post model.Post
	if err := db.Preload("TopicTags").First(&post, postID).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return &super.CreateGroupPostResp{Success: false, Message: "post not found"}, nil
		}
		return nil, err
	}
	if post.UserID != uint(userID) {
		return &super.CreateGroupPostResp{Success: false, Message: "only the post author can link it to a group"}, nil
	}

	var existing model.GroupPost
	if err := db.Where("group_id = ? AND post_id = ?", groupID, postID).First(&existing).Error; err == nil {
		return l.buildResp(existing, post, uint(userID))
	}

	link := model.GroupPost{
		GroupID: uint(groupID),
		PostID:  uint(postID),
	}
	if err := db.Create(&link).Error; err != nil {
		return &super.CreateGroupPostResp{Success: false, Message: "failed to link post: " + err.Error()}, nil
	}

	return l.buildResp(link, post, uint(userID))
}

func (l *CreateGroupPostLogic) buildResp(link model.GroupPost, post model.Post, viewerUID uint) (*super.CreateGroupPostResp, error) {
	var user model.User
	if err := l.svcCtx.DB.First(&user, post.UserID).Error; err != nil {
		return &super.CreateGroupPostResp{Success: false, Message: "author not found"}, nil
	}
	liked := LikedTargetIDSet(l.svcCtx.DB, viewerUID, "post", []uint{post.ID})

	return &super.CreateGroupPostResp{
		Success: true,
		Message: "linked successfully",
		GroupPost: &super.GroupPost{
			Id:        uint64(link.ID),
			GroupId:   uint64(link.GroupID),
			PostId:    uint64(link.PostID),
			Post:      buildSuperPost(post, user, liked[post.ID]),
			CreatedAt: link.CreatedAt.Format("2006-01-02 15:04:05"),
		},
	}, nil
}
