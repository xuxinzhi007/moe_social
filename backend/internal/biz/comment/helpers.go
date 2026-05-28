package commentbiz

import (
	"strconv"

	"backend/model"
	"backend/rpc/pb/moe"
	"backend/utils"
)

// BuildProtoComment 将评论与用户转为 moe.Comment。
func BuildProtoComment(c model.Comment, user model.User, isLiked bool, replyToUserName string) *moe.Comment {
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
	return &moe.Comment{
		Id:              strconv.FormatUint(uint64(c.ID), 10),
		PostId:          strconv.FormatUint(uint64(c.PostID), 10),
		UserId:          strconv.FormatUint(uint64(c.UserID), 10),
		UserName:        username,
		UserAvatar:      avatar,
		Content:         c.Content,
		Likes:           int32(c.Likes),
		IsLiked:         isLiked,
		CreatedAt:       utils.FormatAPIDateTime(c.CreatedAt),
		ParentId:        strconv.FormatUint(uint64(c.ParentID), 10),
		ReplyToUserName: replyToUserName,
	}
}
