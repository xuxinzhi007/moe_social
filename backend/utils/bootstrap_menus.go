package utils

import (
	"backend/model"

	"gorm.io/gorm"
)

type adminMenuSeed struct {
	Key         string
	Kind        string
	ParentKey   string
	Path        string
	Label       string
	Icon        string
	Caption     string
	Status      string
	AppDomain   string
	SortOrder   int
	DefaultOpen bool
	End         bool
}

// defaultAdminMenus 与 moe-admin/src/config/menu.ts ADMIN_MENU_TREE 对齐。
var defaultAdminMenus = []adminMenuSeed{
	{Key: "dashboard", Kind: "item", Path: "/", Label: "工作台", Icon: "🏠", Status: "ready", AppDomain: "dashboard", SortOrder: 0, End: true},
	{Key: "app-users", Kind: "group", Label: "App 用户", Icon: "👤", Caption: "账号 · 会员 · 成长", SortOrder: 10, DefaultOpen: true},
	{Key: "users", Kind: "item", ParentKey: "app-users", Path: "/users", Label: "用户列表", Status: "ready", AppDomain: "profile / auth", SortOrder: 11},
	{Key: "vip-plans", Kind: "item", ParentKey: "app-users", Path: "/vip/plans", Label: "会员与套餐", Status: "ready", AppDomain: "commerce / vip", SortOrder: 12},
	{Key: "wallet-orders", Kind: "item", ParentKey: "app-users", Path: "/wallet/orders", Label: "钱包与订单", Status: "ready", AppDomain: "commerce / wallet", SortOrder: 13},
	{Key: "app-growth", Kind: "item", ParentKey: "app-users", Path: "/app/growth", Label: "签到 · 等级 · 成就", Status: "planned", AppDomain: "checkin / level / achievements", SortOrder: 14},
	{Key: "app-content", Kind: "group", Label: "内容与社区", Icon: "📝", Caption: "动态 · 社区 · 审核", SortOrder: 20},
	{Key: "content-posts", Kind: "item", ParentKey: "app-content", Path: "/content/posts", Label: "动态审核", Status: "ready", AppDomain: "feed", SortOrder: 21},
	{Key: "content-comments", Kind: "item", ParentKey: "app-content", Path: "/content/comments", Label: "评论管理", Status: "ready", AppDomain: "feed / comments", SortOrder: 22},
	{Key: "content-community", Kind: "item", ParentKey: "app-content", Path: "/content/community", Label: "兴趣社区", Status: "ready", AppDomain: "community", SortOrder: 23},
	{Key: "content-reports", Kind: "item", ParentKey: "app-content", Path: "/content/reports", Label: "举报处理", Status: "ready", AppDomain: "feed / report", SortOrder: 24},
	{Key: "app-ops", Kind: "group", Label: "运营触达", Icon: "📢", Caption: "官网 · 公告 · 推送", SortOrder: 30, DefaultOpen: true},
	{Key: "feedback", Kind: "item", ParentKey: "app-ops", Path: "/feedback", Label: "官网反馈", Status: "ready", AppDomain: "website / landing", SortOrder: 31},
	{Key: "app-announcements", Kind: "item", ParentKey: "app-ops", Path: "/app/announcements", Label: "公告管理", Status: "planned", AppDomain: "—", SortOrder: 32},
	{Key: "app-notify", Kind: "item", ParentKey: "app-ops", Path: "/app/notify", Label: "通知推送", Status: "planned", AppDomain: "notification", SortOrder: 33},
	{Key: "app-play", Kind: "group", Label: "AI 与玩法", Icon: "🎮", Caption: "酒馆 · 礼物 · 社交", SortOrder: 40},
	{Key: "app-ai", Kind: "item", ParentKey: "app-play", Path: "/app/ai", Label: "AI 角色酒馆", Status: "planned", AppDomain: "ai", SortOrder: 41},
	{Key: "gifts-catalog", Kind: "item", ParentKey: "app-play", Path: "/gifts/catalog", Label: "礼物与扭蛋", Status: "ready", AppDomain: "gacha / gifts", SortOrder: 42},
	{Key: "app-social", Kind: "item", ParentKey: "app-play", Path: "/app/social", Label: "好友与关注", Status: "planned", AppDomain: "discover / friend", SortOrder: 43},
	{Key: "system", Kind: "group", Label: "系统管理", Icon: "⚙️", Caption: "账号 · 菜单 · 审计", SortOrder: 50},
	{Key: "system-platform", Kind: "item", ParentKey: "system", Path: "/system/platform", Label: "平台治理", Status: "ready", AppDomain: "platform", SortOrder: 51},
	{Key: "system-admins", Kind: "item", ParentKey: "system", Path: "/system/admins", Label: "管理员账号", Status: "planned", AppDomain: "admin_account", SortOrder: 52},
	{Key: "system-menus", Kind: "item", ParentKey: "system", Path: "/system/menus", Label: "侧栏菜单配置", Status: "ready", AppDomain: "admin_menu", SortOrder: 53},
	{Key: "system-audit", Kind: "item", ParentKey: "system", Path: "/system/audit", Label: "操作日志", Status: "ready", AppDomain: "admin_audit_log", SortOrder: 54},
	{Key: "devops", Kind: "group", Label: "运维与监控", Icon: "🚀", Caption: "构建 · 发布 · Agent", SortOrder: 60},
	{Key: "deploy", Kind: "item", ParentKey: "devops", Path: "/deploy", Label: "运维总览", Status: "ready", AppDomain: "—", SortOrder: 61},
	{Key: "docker", Kind: "item", ParentKey: "devops", Path: "/docker", Label: "云 Docker", Status: "ready", SortOrder: 62},
	{Key: "build", Kind: "item", ParentKey: "devops", Path: "/build", Label: "构建流水线", Status: "ready", SortOrder: 63},
	{Key: "release", Kind: "item", ParentKey: "devops", Path: "/release", Label: "GitHub APK 构建", Status: "ready", SortOrder: 64},
	{Key: "jobs", Kind: "item", ParentKey: "devops", Path: "/jobs", Label: "任务审计", Status: "ready", SortOrder: 65},
	{Key: "rpc", Kind: "item", ParentKey: "devops", Path: "/rpc", Label: "RPC 监控", Status: "ready", AppDomain: "—", SortOrder: 66},
}

// BootstrapAdminMenus 仅在菜单表为空时写入默认侧栏项。
func BootstrapAdminMenus(db *gorm.DB) (int32, error) {
	if db == nil {
		return 0, nil
	}
	var count int64
	if err := db.Model(&model.AdminMenu{}).Count(&count).Error; err != nil {
		return 0, err
	}
	if count > 0 {
		return 0, nil
	}

	var created int32
	for _, seed := range defaultAdminMenus {
		row := model.AdminMenu{
			Key:         seed.Key,
			Kind:        seed.Kind,
			ParentKey:   seed.ParentKey,
			Path:        seed.Path,
			Label:       seed.Label,
			Icon:        seed.Icon,
			Caption:     seed.Caption,
			Status:      seed.Status,
			AppDomain:   seed.AppDomain,
			SortOrder:   seed.SortOrder,
			DefaultOpen: seed.DefaultOpen,
			End:         seed.End,
			Enabled:     true,
		}
		if row.Status == "" {
			row.Status = "planned"
		}
		if err := db.Create(&row).Error; err != nil {
			return created, err
		}
		created++
	}
	return created, nil
}
