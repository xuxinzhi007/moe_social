package commentbiz

import (
	"strconv"
	"strings"

	commentv1 "backend/api/comment/v1"
	"backend/model"
	"backend/utils"
)

// BuildCommentV1 将评论与用户转为 comment.v1 Comment。
func BuildCommentV1(c model.Comment, user model.User, isLiked bool, replyToUserName string) *commentv1.Comment {
	username := "未知用户"
	avatar := "https://picsum.photos/150"
	if user.ID > 0 {
		if user.Username != "" {
			username = user.Username
		} else if user.Email != "" {
			username = user.Email
		}
		if user.Avatar != "" {
			avatar = user.Avatar
		}
	}
	return &commentv1.Comment{
		Id:                strconv.FormatUint(uint64(c.ID), 10),
		PostId:            strconv.FormatUint(uint64(c.PostID), 10),
		UserId:            strconv.FormatUint(uint64(c.UserID), 10),
		UserName:          username,
		UserAvatar:        avatar,
		Content:           c.Content,
		Likes:             int32(c.Likes),
		IsLiked:           isLiked,
		CreatedAt:         utils.FormatAPIDateTime(c.CreatedAt),
		ParentId:          strconv.FormatUint(uint64(c.ParentID), 10),
		ReplyToUserName:   replyToUserName,
		AuthorIsBot:       user.IsBot,
		AuthorBotAgentKey: strings.TrimSpace(user.BotAgentKey),
	}
}

// BuildProtoComment 保留别名，返回 comment.v1 Comment。
func BuildProtoComment(c model.Comment, user model.User, isLiked bool, replyToUserName string) *commentv1.Comment {
	return BuildCommentV1(c, user, isLiked, replyToUserName)
}
