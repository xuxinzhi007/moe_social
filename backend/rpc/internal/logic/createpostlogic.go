package logic

import (
	"context"
	"encoding/json"
	"strconv"
	"backend/model"
	"backend/rpc/internal/achievement"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type CreatePostLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewCreatePostLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CreatePostLogic {
	return &CreatePostLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *CreatePostLogic) CreatePost(in *super.CreatePostReq) (*super.CreatePostResp, error) {
	if in.UserId == "" {
		return nil, errorx.New(400, "用户ID不能为空")
	}
	if in.Content == "" && in.HandDrawCard == "" && len(in.Images) == 0 {
		return nil, errorx.New(400, "请填写文字、上传图片或添加手绘卡片")
	}

	userID, err := strconv.ParseUint(in.UserId, 10, 32)
	if err != nil {
		return nil, errorx.New(400, "无效的用户ID")
	}

	var user model.User
	if err := l.svcCtx.DB.Where("id = ?", userID).First(&user).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, errorx.New(404, "用户不存在")
		}
		l.Error("查找用户失败: ", err)
		return nil, errorx.New(500, "服务器内部错误")
	}

	if err := requireGroupMember(l.svcCtx.DB, in.GetGroupId(), uint(userID)); err != nil {
		return nil, err
	}

	modStatus := "ok"
	if in.HandDrawCard != "" && l.svcCtx.Config.HandDrawRequireModeration {
		modStatus = "pending"
	}

	tx := l.svcCtx.DB.Begin()
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	post := model.Post{
		UserID:           uint(userID),
		Content:          in.Content,
		HandDrawCard:     in.HandDrawCard,
		HandDrawThumbURL: in.HandDrawThumbUrl,
		ModerationStatus: modStatus,
		MoodTag:          in.MoodTag,
	}
	if len(in.Images) > 0 {
		imagesJSON, err := json.Marshal(in.Images)
		if err != nil {
			tx.Rollback()
			return nil, errorx.New(500, "服务器内部错误")
		}
		post.Images = string(imagesJSON)
	}

	if err := tx.Create(&post).Error; err != nil {
		tx.Rollback()
		l.Error("创建帖子失败: ", err)
		return nil, errorx.New(500, "创建帖子失败")
	}

	var topicTags []model.TopicTag
	if len(in.TopicTags) > 0 {
		for _, tag := range in.TopicTags {
			var topicTag model.TopicTag
			if err := tx.Where("name = ?", tag.Name).FirstOrCreate(&topicTag, model.TopicTag{
				Name:  tag.Name,
				Color: tag.Color,
			}).Error; err != nil {
				continue
			}
			topicTags = append(topicTags, topicTag)
		}
		if len(topicTags) > 0 {
			tx.Where("post_id = ?", post.ID).Delete(&model.PostTopic{})
			for _, tag := range topicTags {
				_ = tx.Create(&model.PostTopic{PostID: post.ID, TopicTagID: tag.ID}).Error
			}
		}
	}

	if err := linkPostToGroupTx(tx, in.GetGroupId(), post.ID, uint(userID)); err != nil {
		tx.Rollback()
		return nil, err
	}

	handDrawApproved := in.HandDrawCard != "" && modStatus == "ok"
	engine := achievement.NewEngine(l.svcCtx.DB)
	achUnlocks, err := engine.ApplyEvent(tx, uint(userID), achievement.Event{
		Type:             achievement.EventPostCreated,
		ImageCount:       len(in.Images),
		HasTopic:         len(topicTags) > 0,
		ContentLen:       len([]rune(in.Content)),
		MoodTag:          in.MoodTag,
		HasHandDraw:      in.HandDrawCard != "",
		HandDrawApproved: handDrawApproved,
		Hour:             achievement.CurrentEventHour(),
	})
	if err != nil {
		l.Errorf("成就处理失败（帖子仍会发布）: %v；若库内无成就定义请执行 rpc -migrate", err)
		achUnlocks = nil
	}

	if err := tx.Commit().Error; err != nil {
		return nil, errorx.New(500, "创建帖子失败")
	}

	responseTopicTags := make([]*super.TopicTag, 0, len(topicTags))
	for _, tag := range topicTags {
		responseTopicTags = append(responseTopicTags, &super.TopicTag{
			Id:        strconv.FormatUint(uint64(tag.ID), 10),
			Name:      tag.Name,
			Color:     tag.Color,
			CreatedAt: tag.CreatedAt.Format("2006-01-02 15:04:05"),
		})
	}

	return &super.CreatePostResp{
		Post: &super.Post{
			Id:               strconv.FormatUint(uint64(post.ID), 10),
			UserId:           in.UserId,
			UserName:         user.Username,
			UserAvatar:       user.Avatar,
			Content:          post.Content,
			Images:           in.Images,
			TopicTags:        responseTopicTags,
			Likes:            0,
			Comments:         0,
			IsLiked:          false,
			CreatedAt:        post.CreatedAt.Format("2006-01-02 15:04:05"),
			HandDrawCard:     post.HandDrawCard,
			HandDrawThumbUrl: post.HandDrawThumbURL,
			ModerationStatus: moderationStatusOrDefault(post.ModerationStatus),
		},
		NewAchievements: achievement.UnlocksToProto(achUnlocks),
	}, nil
}
