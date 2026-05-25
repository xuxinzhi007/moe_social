package utils

import (
	"encoding/json"
	"strings"
	"time"

	"backend/model"
)

const (
	BehaviorEventScreenView = "screen_view"
	BehaviorEventTap        = "tap"
)

// BehaviorScreenLabel 返回页面可读名称。
func BehaviorScreenLabel(screen string) string {
	labels := map[string]string{
		"login":              "登录",
		"register":           "注册",
		"home":               "首页",
		"profile":            "我的",
		"user_profile":       "用户主页",
		"settings":           "设置",
		"checkin":            "签到",
		"achievements":       "成就",
		"vip_center":         "会员中心",
		"vip_purchase":       "购买会员",
		"wallet":             "钱包",
		"recharge":           "充值",
		"gacha":              "扭蛋",
		"chat":               "聊天",
		"conversations":      "会话列表",
		"community":          "社区",
		"create_post":        "发帖",
		"post_detail":        "帖子详情",
		"notifications":      "通知中心",
		"cloud_gallery":      "云相册",
		"scan":               "扫码",
		"friends":            "好友",
		"order_center":       "订单中心",
		"explore_match":      "探索匹配",
		"topic_posts":        "话题页",
		"comments":           "评论",
		"edit_profile":       "编辑资料",
		"virtual_avatar":     "虚拟形象",
		"message_retention":  "消息保留",
		"interest_group":     "兴趣群组",
		"unknown":            "未知页面",
	}
	if label, ok := labels[screen]; ok {
		return label
	}
	return screen
}

// NormalizeBehaviorScreen 规范化页面 key。
func NormalizeBehaviorScreen(screen string) string {
	screen = strings.TrimSpace(strings.ToLower(screen))
	if screen == "" {
		return "unknown"
	}
	if len(screen) > 64 {
		return screen[:64]
	}
	return screen
}

// NormalizeBehaviorEvent 规范化事件类型。
func NormalizeBehaviorEvent(event string) string {
	event = strings.TrimSpace(strings.ToLower(event))
	switch event {
	case BehaviorEventScreenView, BehaviorEventTap:
		return event
	default:
		return BehaviorEventTap
	}
}

// BehaviorActivityDate 将客户端时间映射为 UTC 日期桶。
func BehaviorActivityDate(clientTs time.Time) time.Time {
	if clientTs.IsZero() {
		clientTs = time.Now().UTC()
	}
	y, m, d := clientTs.UTC().Date()
	return time.Date(y, m, d, 0, 0, 0, 0, time.UTC)
}

// BuildBehaviorTags 根据近 7 日页面聚合生成简单画像标签。
func BuildBehaviorTags(rows []model.UserBehaviorDaily) []string {
	if len(rows) == 0 {
		return nil
	}
	type agg struct {
		visits   int
		duration int64
	}
	byScreen := map[string]agg{}
	for _, row := range rows {
		item := byScreen[row.Screen]
		item.visits += row.VisitCount
		item.duration += row.TotalDurationMs
		byScreen[row.Screen] = item
	}

	var tags []string
	addTag := func(tag string) {
		for _, existing := range tags {
			if existing == tag {
				return
			}
		}
		tags = append(tags, tag)
	}

	if v := byScreen["chat"].visits + byScreen["conversations"].visits; v >= 3 {
		addTag("社交活跃")
	}
	if v := byScreen["vip_center"].visits + byScreen["vip_purchase"].visits + byScreen["wallet"].visits + byScreen["recharge"].visits; v >= 2 {
		addTag("关注会员")
	}
	if v := byScreen["community"].visits + byScreen["post_detail"].visits + byScreen["create_post"].visits + byScreen["home"].visits; v >= 5 {
		addTag("内容浏览")
	}
	if byScreen["checkin"].visits >= 2 {
		addTag("签到习惯")
	}
	if byScreen["gacha"].visits >= 2 {
		addTag("扭蛋玩家")
	}
	if byScreen["cloud_gallery"].visits >= 2 {
		addTag("相册用户")
	}
	if len(tags) == 0 {
		addTag("轻度使用")
	}
	return tags
}

// ParamsJSONFromMap 将 params map 序列化为 JSON 字符串。
func ParamsJSONFromMap(params map[string]string) string {
	if len(params) == 0 {
		return ""
	}
	b, err := json.Marshal(params)
	if err != nil {
		return ""
	}
	return string(b)
}
