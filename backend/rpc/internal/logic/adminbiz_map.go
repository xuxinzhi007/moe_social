package logic

import (
	"errors"

	aibiz "backend/internal/biz/ai"
	adminbiz "backend/internal/biz/admin"
	llmbiz "backend/internal/biz/llm"
	notifybiz "backend/internal/biz/notify"
	"backend/rpc/internal/errorx"
)

func mapAdminUserWriteErr(err error) error {
	if err == nil {
		return nil
	}
	switch {
	case errors.Is(err, adminbiz.ErrInvalidUserID):
		return errorx.InvalidArgument("无效的用户 ID")
	case errors.Is(err, adminbiz.ErrUserNotFound):
		return errorx.NotFound("用户不存在")
	case errors.Is(err, adminbiz.ErrInvalidUserRole):
		return errorx.InvalidArgument("无效的角色")
	default:
		return errorx.Internal("更新失败")
	}
}

func mapAdminAchievementWriteErr(err error) error {
	if err == nil {
		return nil
	}
	switch {
	case errors.Is(err, adminbiz.ErrInvalidAchievementID):
		return errorx.InvalidArgument("invalid achievement_id")
	case errors.Is(err, adminbiz.ErrAchievementNotFound):
		return errorx.NotFound("achievement not found")
	default:
		return errorx.Internal("更新成就失败")
	}
}

func mapAdminMenuWriteErr(err error) error {
	if err == nil {
		return nil
	}
	switch {
	case errors.Is(err, adminbiz.ErrEmptyMenuKey):
		return errorx.InvalidArgument("菜单 key 不能为空")
	case errors.Is(err, adminbiz.ErrEmptyMenuKind):
		return errorx.InvalidArgument("菜单 kind 不能为空")
	case errors.Is(err, adminbiz.ErrEmptyMenuLabel):
		return errorx.InvalidArgument("菜单 label 不能为空")
	default:
		return errorx.Internal("保存菜单失败")
	}
}

func mapAdminMenuDeleteErr(err error) error {
	if err == nil {
		return nil
	}
	if errors.Is(err, adminbiz.ErrEmptyMenuKey) {
		return errorx.InvalidArgument("菜单 key 不能为空")
	}
	return errorx.Internal("删除菜单失败")
}

func mapAdminInsightsErr(err error) error {
	if err == nil {
		return nil
	}
	if errors.Is(err, adminbiz.ErrInsightsDB) {
		return errorx.Internal("数据库未就绪")
	}
	if errors.Is(err, adminbiz.ErrInsightsNotFound) {
		return errorx.NotFound(err.Error())
	}
	if errors.Is(err, adminbiz.ErrInsightsInvalid) {
		return errorx.InvalidArgument(err.Error())
	}
	if errors.Is(err, adminbiz.ErrInsightsInternal) {
		return errorx.Internal(err.Error())
	}
	return errorx.Internal("操作失败")
}

func mapAIResourceErr(err error) error {
	if err == nil {
		return nil
	}
	switch {
	case errors.Is(err, aibiz.ErrEmptyUserID):
		return errorx.InvalidArgument("user_id不能为空")
	case errors.Is(err, aibiz.ErrInvalidUserID):
		return errorx.InvalidArgument("无效的user_id")
	case errors.Is(err, aibiz.ErrInvalidPayload):
		return errorx.InvalidArgument("invalid payload_json")
	case errors.Is(err, aibiz.ErrUnknownResourceKind):
		return errorx.Internal("unknown AI resource kind")
	case errors.Is(err, aibiz.ErrEncodeResource):
		return errorx.Internal("encode AI resource failed")
	case errors.Is(err, aibiz.ErrListPublicAgents):
		return errorx.Internal("list public agents failed")
	case errors.Is(err, aibiz.ErrAdminListAgents):
		return errorx.Internal("查询 AI 角色失败")
	default:
		return errorx.Internal("AI 资源操作失败")
	}
}

func mapMemoryWriteErr(err error) error {
	if err == nil {
		return nil
	}
	switch {
	case errors.Is(err, llmbiz.ErrMemoryEmptyUserID):
		return errorx.InvalidArgument(err.Error())
	case errors.Is(err, llmbiz.ErrMemoryEmptyKey):
		return errorx.InvalidArgument(err.Error())
	case errors.Is(err, llmbiz.ErrMemoryEmptyValue):
		return errorx.InvalidArgument(err.Error())
	case errors.Is(err, llmbiz.ErrMemoryInvalidUser):
		return errorx.InvalidArgument(err.Error())
	case errors.Is(err, llmbiz.ErrMemoryTechnical):
		return errorx.InvalidArgument(err.Error())
	case errors.Is(err, llmbiz.ErrMemoryNotFound):
		return errorx.NotFound("用户记忆不存在")
	default:
		return errorx.Internal("更新用户记忆失败")
	}
}

func mapAdminModerationErr(err error) error {
	if err == nil {
		return nil
	}
	switch {
	case errors.Is(err, adminbiz.ErrInvalidFollowUserID):
		return errorx.InvalidArgument("用户 ID 无效")
	case errors.Is(err, adminbiz.ErrListFollows):
		return errorx.Internal("查询关注失败")
	case errors.Is(err, adminbiz.ErrInvalidFollowID):
		return errorx.InvalidArgument("关注 ID 无效")
	case errors.Is(err, adminbiz.ErrDeleteFollow):
		return errorx.Internal("删除关注失败")
	case errors.Is(err, adminbiz.ErrListPosts):
		return errorx.Internal("查询动态失败")
	case errors.Is(err, adminbiz.ErrEmptyPostID):
		return errorx.InvalidArgument("帖子 ID 不能为空")
	case errors.Is(err, adminbiz.ErrInvalidPostID):
		return errorx.InvalidArgument("无效的帖子 ID")
	case errors.Is(err, adminbiz.ErrPostNotFound):
		return errorx.NotFound("帖子不存在")
	case errors.Is(err, adminbiz.ErrDeletePost):
		return errorx.Internal("删除帖子失败")
	case errors.Is(err, adminbiz.ErrListComments):
		return errorx.Internal("查询评论失败")
	case errors.Is(err, adminbiz.ErrEmptyCommentID):
		return errorx.InvalidArgument("评论 ID 不能为空")
	case errors.Is(err, adminbiz.ErrInvalidCommentID):
		return errorx.InvalidArgument("无效的评论 ID")
	case errors.Is(err, adminbiz.ErrCommentNotFound):
		return errorx.NotFound("评论不存在")
	case errors.Is(err, adminbiz.ErrDeleteComment):
		return errorx.Internal("删除评论失败")
	case errors.Is(err, adminbiz.ErrListGroups):
		return errorx.Internal("查询社区失败")
	case errors.Is(err, adminbiz.ErrListFriendRequests):
		return errorx.Internal("查询好友申请失败")
	case errors.Is(err, adminbiz.ErrListPostReports):
		return errorx.Internal("查询举报失败")
	case errors.Is(err, adminbiz.ErrListMemories):
		return errorx.Internal("查询记忆失败")
	case errors.Is(err, adminbiz.ErrInvalidMemoryID):
		return errorx.InvalidArgument("invalid memory_id")
	case errors.Is(err, adminbiz.ErrMemoryNotFound):
		return errorx.NotFound("记忆不存在")
	case errors.Is(err, adminbiz.ErrDeleteMemory):
		return errorx.Internal("删除记忆失败")
	case errors.Is(err, adminbiz.ErrMemoryStats):
		return errorx.Internal("查询记忆统计失败")
	case errors.Is(err, adminbiz.ErrDashboard):
		return errorx.Internal("服务器内部错误")
	case errors.Is(err, adminbiz.ErrInvalidProfileUserID):
		return errorx.InvalidArgument("invalid user_id")
	case errors.Is(err, adminbiz.ErrProfileUserNotFound):
		return errorx.NotFound("user not found")
	default:
		return errorx.Internal("操作失败")
	}
}

func mapAdminAccountErr(err error) error {
	if err == nil {
		return nil
	}
	switch {
	case errors.Is(err, adminbiz.ErrListAccounts):
		return errorx.Internal("查询管理员失败")
	case errors.Is(err, adminbiz.ErrEmptyAccountUsername):
		return errorx.InvalidArgument("用户名不能为空")
	case errors.Is(err, adminbiz.ErrEmptyAccountPassword):
		return errorx.InvalidArgument("密码不能为空")
	case errors.Is(err, adminbiz.ErrEmptyAccountRole):
		return errorx.InvalidArgument("角色不能为空")
	case errors.Is(err, adminbiz.ErrInvalidAccountID):
		return errorx.InvalidArgument("账号 ID 无效")
	case errors.Is(err, adminbiz.ErrAccountNotFound):
		return errorx.NotFound("管理员不存在")
	case errors.Is(err, adminbiz.ErrAccountDuplicate):
		return errorx.AlreadyExists("用户名已存在")
	case errors.Is(err, adminbiz.ErrCreateAccount):
		return errorx.Internal("创建管理员失败")
	case errors.Is(err, adminbiz.ErrUpdateAccount):
		return errorx.Internal("更新管理员失败")
	case errors.Is(err, adminbiz.ErrDeleteAccount):
		return errorx.Internal("删除管理员失败")
	case errors.Is(err, adminbiz.ErrLastAdminAccount):
		return errorx.InvalidArgument("至少保留一名管理员")
	default:
		return errorx.Internal("操作失败")
	}
}

func mapAdminGrowthErr(err error) error {
	if err == nil {
		return nil
	}
	switch {
	case errors.Is(err, adminbiz.ErrInvalidLevelID):
		return errorx.InvalidArgument("invalid level_id")
	case errors.Is(err, adminbiz.ErrLevelConfigNotFound):
		return errorx.NotFound("level config not found")
	case errors.Is(err, adminbiz.ErrInvalidCheckInRewardID):
		return errorx.InvalidArgument("invalid reward_id")
	case errors.Is(err, adminbiz.ErrCheckInRewardNotFound):
		return errorx.NotFound("check-in reward not found")
	case errors.Is(err, adminbiz.ErrBootstrapLevels):
		return errorx.Internal("初始化等级数据失败")
	default:
		return errorx.Internal("操作失败")
	}
}

func mapAdminOrdersErr(err error) error {
	if err == nil {
		return nil
	}
	switch {
	case errors.Is(err, adminbiz.ErrListVipOrders):
		return errorx.Internal("查询 VIP 订单失败")
	case errors.Is(err, adminbiz.ErrListGiftPurchaseOrders):
		return errorx.Internal("查询礼物订单失败")
	default:
		return errorx.Internal("操作失败")
	}
}

func mapAdminGetUserErr(err error) error {
	if err == nil {
		return nil
	}
	switch {
	case errors.Is(err, adminbiz.ErrInvalidUserID):
		return errorx.InvalidArgument("无效的用户 ID")
	case errors.Is(err, adminbiz.ErrUserNotFound):
		return errorx.NotFound("用户不存在")
	default:
		return errorx.Internal("服务器内部错误")
	}
}

func mapAdminListErr(err error) error {
	if err == nil {
		return nil
	}
	if errors.Is(err, adminbiz.ErrInvalidArgument) {
		return errorx.InvalidArgument("参数无效")
	}
	if errors.Is(err, adminbiz.ErrInvalidAnnouncementID) {
		return errorx.InvalidArgument("无效的公告 ID")
	}
	return errorx.Internal("操作失败")
}

func mapAdminAnnouncementErr(err error) error {
	if err == nil {
		return nil
	}
	if errors.Is(err, adminbiz.ErrInvalidArgument) {
		return errorx.InvalidArgument("参数无效")
	}
	return errorx.Internal("查询公告失败")
}

func mapAdminAuditListErr(err error) error {
	if err == nil {
		return nil
	}
	if errors.Is(err, adminbiz.ErrInvalidArgument) {
		return errorx.InvalidArgument("管理员 ID 无效")
	}
	return errorx.Internal("查询审计日志失败")
}

func mapAdminNotifyErr(err error) error {
	if err == nil {
		return nil
	}
	switch {
	case errors.Is(err, notifybiz.ErrInvalidUserID):
		return errorx.InvalidArgument("用户 ID 无效")
	case errors.Is(err, notifybiz.ErrEmptyContent):
		return errorx.InvalidArgument("通知内容不能为空")
	case errors.Is(err, notifybiz.ErrUserNotFound):
		return errorx.NotFound("用户不存在")
	default:
		return errorx.Internal("发送通知失败")
	}
}
