package commentbiz

import (
	"regexp"
	"strings"

	"backend/model"
)

const (
	// notificationTypeComment 评论了动态或回复了评论。
	notificationTypeComment = 2
	// notificationTypeCommentMention 评论里 @ 了好友。
	notificationTypeCommentMention = 10
	maxCommentMentions             = 5
)

// 用户名与 model.User.Username 一致，最长 50；@ 必须在开头或空白之后，避免把邮箱拆开。
var mentionPattern = regexp.MustCompile(`(?:^|\s)@([\p{L}\p{N}_]{1,50})`)

// mentionUsernames 按出现顺序抽出 @用户名，忽略大小写重复，最多 maxCommentMentions 个。
func mentionUsernames(content string) []string {
	matches := mentionPattern.FindAllStringSubmatch(content, -1)
	if len(matches) == 0 {
		return nil
	}
	seen := make(map[string]struct{}, len(matches))
	out := make([]string, 0, len(matches))
	for _, match := range matches {
		name := match[1]
		key := strings.ToLower(name)
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		out = append(out, name)
		if len(out) == maxCommentMentions {
			break
		}
	}
	return out
}

// mentionNotifyIDs 选出尚未收到本条评论通知、且不是作者本人的好友。
func mentionNotifyIDs(actor uint, already map[uint]struct{}, friends []model.User) []uint {
	if len(friends) == 0 {
		return nil
	}
	out := make([]uint, 0, len(friends))
	seen := make(map[uint]struct{}, len(friends))
	for _, friend := range friends {
		if friend.ID == 0 || friend.ID == actor {
			continue
		}
		if _, ok := already[friend.ID]; ok {
			continue
		}
		if _, ok := seen[friend.ID]; ok {
			continue
		}
		seen[friend.ID] = struct{}{}
		out = append(out, friend.ID)
	}
	return out
}
