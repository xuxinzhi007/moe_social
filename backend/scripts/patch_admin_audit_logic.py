import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent / "api" / "internal" / "logic" / "admin"

AUDIT_SPECS = {
    "adminupdateuserlogic.go": ("update", "user", 'fmt.Sprintf("%d", req.UserId)', '"更新 App 用户"'),
    "admincreatevipplanlogic.go": ("create", "vip_plan", "resp.Data.Id", '"创建 VIP 套餐"'),
    "adminupdatevipplanlogic.go": ("update", "vip_plan", 'fmt.Sprintf("%d", req.PlanId)', '"更新 VIP 套餐"'),
    "admindeletevipplanlogic.go": ("delete", "vip_plan", 'fmt.Sprintf("%d", req.PlanId)', '"删除 VIP 套餐"'),
    "adminbootstrapvipplanslogic.go": ("bootstrap", "vip_plan", '""', '"导入默认 VIP 套餐"'),
    "adminbootstrapachievementslogic.go": ("bootstrap", "achievement", '""', '"导入默认成就定义"'),
    "admincreategiftlogic.go": ("create", "gift", "resp.Data.Id", '"创建礼物"'),
    "adminupdategiftlogic.go": ("update", "gift", "req.GiftId", '"更新礼物"'),
    "admindeletegiftlogic.go": ("delete", "gift", "req.GiftId", '"删除礼物"'),
    "adminbootstrapgiftslogic.go": ("bootstrap", "gift", '""', '"导入默认礼物"'),
    "admindeletepostlogic.go": ("delete", "post", "req.PostId", '"删除帖子"'),
    "admindeletecommentlogic.go": ("delete", "comment", "req.CommentId", '"删除评论"'),
    "admindeletegrouplogic.go": ("delete", "group", "req.GroupId", '"删除群组"'),
    "adminbootstraplevelslogic.go": ("bootstrap", "level_config", '""', '"导入默认等级配置"'),
    "adminupdatelevelconfiglogic.go": ("update", "level_config", 'fmt.Sprintf("%d", req.LevelId)', '"更新等级配置"'),
    "adminupdatecheckinrewardlogic.go": ("update", "check_in_reward", 'fmt.Sprintf("%d", req.RewardId)', '"更新签到奖励"'),
    "adminupdateachievementlogic.go": ("update", "achievement", "req.AchievementId", '"更新成就定义"'),
    "admincreateannouncementlogic.go": ("create", "announcement", "resp.Data.Id", '"创建公告"'),
    "adminupdateannouncementlogic.go": ("update", "announcement", "req.AnnouncementId", '"更新公告"'),
    "admindeleteannouncementlogic.go": ("delete", "announcement", "req.AnnouncementId", '"删除公告"'),
    "adminpublishannouncementlogic.go": ("publish", "announcement", "req.AnnouncementId", '"发布公告"'),
    "adminbroadcastnotificationlogic.go": ("broadcast", "notification", '""', '"广播通知"'),
    "adminsendnotificationlogic.go": ("send", "notification", "req.UserId", '"发送用户通知"'),
    "admindeleteaiagentlogic.go": ("delete", "ai_agent", "req.AgentId", '"删除 AI 分身"'),
    "admindeletefollowlogic.go": ("delete", "follow", "req.FollowId", '"删除关注关系"'),
    "admincreateaccountlogic.go": ("create", "admin_account", "resp.Data.Id", '"创建管理员账号"'),
    "adminupdateaccountlogic.go": ("update", "admin_account", "req.AccountId", '"更新管理员账号"'),
    "admindeleteaccountlogic.go": ("delete", "admin_account", "req.AccountId", '"删除管理员账号"'),
    "adminupsertmenulogic.go": ("update", "admin_menu", "req.MenuKey", '"更新侧栏菜单"'),
    "admindeletemenulogic.go": ("delete", "admin_menu", "req.MenuKey", '"删除侧栏菜单"'),
    "adminbootstrapmenuslogic.go": ("bootstrap", "admin_menu", '""', '"导入默认侧栏菜单"'),
    "adminupdateruntimeconfiglogic.go": ("update", "runtime_config", '""', '"更新运行时配置"'),
    "admindeletemediaimagelogic.go": ("delete", "media_image", "req.Filename", '"删除云图库文件"'),
    "admindeletememorylogic.go": ("delete", "user_memory", 'fmt.Sprintf("%d", req.MemoryId)', '"删除用户记忆"'),
}


def patch_logic(path: pathlib.Path, action: str, resource: str, rid: str, detail: str) -> bool:
    text = path.read_text(encoding="utf-8")
    if "TryRecordAdminAudit" in text:
        return False

    pattern = re.compile(
        r"\n\treturn (&types\.[\w]+Resp\{[\s\S]*?\}), nil\n\}\s*$",
        re.MULTILINE,
    )
    m = pattern.search(text)
    if not m:
        print("pattern fail", path.name)
        return False

    if "fmt.Sprintf" in rid and '"fmt"' not in text:
        text = text.replace(
            'import (\n\t"context"\n',
            'import (\n\t"context"\n\t"fmt"\n',
        )

    body = m.group(1)
    replacement = f"""
	resp := {body}
	if resp.BaseResp.Success {{
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "{action}", "{resource}", {rid}, {detail})
	}}
	return resp, nil
}}"""
    text = text[: m.start()] + replacement

    if "backend/api/internal/common" not in text:
        text = text.replace(
            '"backend/api/internal/svc"\n',
            '"backend/api/internal/common"\n\t"backend/api/internal/svc"\n',
        )

    path.write_text(text, encoding="utf-8")
    return True


def main() -> None:
    for name, spec in AUDIT_SPECS.items():
        path = ROOT / name
        if not path.exists():
            print("missing", name)
            continue
        if patch_logic(path, *spec):
            print("patched", name)
        else:
            print("skip", name)


if __name__ == "__main__":
    main()
