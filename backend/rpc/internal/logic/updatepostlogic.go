package logic

import (
	"context"
	"encoding/json"
	"strconv"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type UpdatePostLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewUpdatePostLogic(ctx context.Context, svcCtx *svc.ServiceContext) *UpdatePostLogic {
	return &UpdatePostLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *UpdatePostLogic) UpdatePost(in *super.UpdatePostReq) (*super.UpdatePostResp, error) {
	if in.PostId == "" || in.UserId == "" {
		return nil, errorx.New(400, "post_id 和 user_id 不能为空")
	}

	postID, err := strconv.ParseUint(in.PostId, 10, 64)
	if err != nil {
		return nil, errorx.New(400, "无效的 post_id")
	}
	userID, err := strconv.ParseUint(in.UserId, 10, 64)
	if err != nil {
		return nil, errorx.New(400, "无效的 user_id")
	}

	// 查帖子（不 Preload，后面单独处理 TopicTags）
	var p model.Post
	if err := l.svcCtx.DB.First(&p, postID).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, errorx.New(404, "帖子不存在")
		}
		return nil, errorx.New(500, "查询帖子失败")
	}
	if uint64(p.UserID) != userID {
		return nil, errorx.New(403, "无权编辑此帖子")
	}

	// 更新字段（只更新非空传入的字段）
	if in.Content != "" {
		p.Content = in.Content
	}
	if in.Images != nil {
		if len(in.Images) == 0 {
			p.Images = "[]"
		} else {
			imagesJSON, _ := json.Marshal(in.Images)
			p.Images = string(imagesJSON)
		}
	}
	if in.HandDrawCard != "" {
		p.HandDrawCard = in.HandDrawCard
	}
	if in.HandDrawThumbUrl != "" {
		p.HandDrawThumbURL = in.HandDrawThumbUrl
	}

	if err := l.svcCtx.DB.Save(&p).Error; err != nil {
		l.Error("更新帖子失败: ", err)
		return nil, errorx.New(500, "更新帖子失败")
	}

	// 更新话题标签关联
	if in.TopicTags != nil {
		l.svcCtx.DB.Where("post_id = ?", p.ID).Delete(&model.PostTopic{})
		for _, tag := range in.TopicTags {
			var tt model.TopicTag
			l.svcCtx.DB.Where("name = ?", tag.Name).FirstOrCreate(&tt, model.TopicTag{
				Name:  tag.Name,
				Color: tag.Color,
			})
			l.svcCtx.DB.Create(&model.PostTopic{PostID: p.ID, TopicTagID: tt.ID})
		}
	}

	// 重新加载带 TopicTags 的完整帖子
	l.svcCtx.DB.Preload("TopicTags").First(&p, p.ID)

	// 查询作者信息
	var user model.User
	if err := l.svcCtx.DB.Select("id, username, avatar").First(&user, p.UserID).Error; err != nil {
		l.Error("查询用户失败: ", err)
	}

	// 查询真实点赞数
	var likeCount int64
	l.svcCtx.DB.Model(&model.Like{}).
		Where("target_type = 'post' AND target_id = ?", p.ID).
		Count(&likeCount)

	// 查询真实评论数
	var commentCount int64
	l.svcCtx.DB.Model(&model.Comment{}).
		Where("post_id = ? AND deleted_at IS NULL", p.ID).
		Count(&commentCount)

	// 构建响应话题标签
	respTags := make([]*super.TopicTag, 0, len(p.TopicTags))
	for _, t := range p.TopicTags {
		respTags = append(respTags, &super.TopicTag{
			Id:    strconv.FormatUint(uint64(t.ID), 10),
			Name:  t.Name,
			Color: t.Color,
		})
	}

	var images []string
	if p.Images != "" {
		_ = json.Unmarshal([]byte(p.Images), &images)
	}

	return &super.UpdatePostResp{
		Post: &super.Post{
			Id:               strconv.FormatUint(uint64(p.ID), 10),
			UserId:           in.UserId,
			UserName:         user.Username,
			UserAvatar:       user.Avatar,
			Content:          p.Content,
			Images:           images,
			TopicTags:        respTags,
			Likes:            int32(likeCount),
			Comments:         int32(commentCount),
			IsLiked:          false, // 前端会从 LikeStateManager 取，无需服务端返回
			CreatedAt:        p.CreatedAt.Format("2006-01-02 15:04:05"),
			HandDrawCard:     p.HandDrawCard,
			HandDrawThumbUrl: p.HandDrawThumbURL,
			ModerationStatus: moderationStatusOrDefault(p.ModerationStatus),
		},
	}, nil
}
