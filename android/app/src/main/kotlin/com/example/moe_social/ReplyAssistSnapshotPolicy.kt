package com.example.moe_social

/**
 * 回复参谋读屏策略：不写死聊天应用白名单，只跳过自身、输入法和
 * 明显非聊天界面，并滤掉标题栏 / 按钮等杂质文案。
 */
object ReplyAssistSnapshotPolicy {

    private val deniedPackages = setOf(
        "com.android.settings",
        "com.android.systemui",
        "com.android.permissioncontroller",
        "com.google.android.permissioncontroller",
        "com.android.packageinstaller",
        "com.google.android.packageinstaller",
        "com.android.vending",
        "com.android.phone",
        "com.android.dialer",
        "com.google.android.dialer",
        "com.onepassword.android",
        "com.lastpass.lpandroid",
        "com.x8bit.bitwarden",
        "com.azure.authenticator",
        "com.google.android.apps.authenticator2",
        "com.tencent.token",
    )

    fun isOwnPackage(pkg: String?, selfPackage: String): Boolean {
        if (pkg.isNullOrEmpty()) return false
        return pkg == selfPackage || pkg.startsWith("$selfPackage.")
    }

    fun isImePackage(pkg: String?): Boolean {
        if (pkg.isNullOrEmpty()) return false
        val p = pkg.lowercase()
        return "inputmethod" in p ||
            p.contains(".ime.") ||
            p.endsWith(".ime") ||
            p.contains("honeyboard") ||
            p.contains("swiftkey") ||
            p.contains("sginput") ||
            p.contains("qqpinyin") ||
            p.contains("touchpal") ||
            (p.contains("sogou") && p.contains("input")) ||
            p.contains("baidu.input") ||
            (p.contains("iflytek") && p.contains("input"))
    }

    fun isDeniedPackage(pkg: String?): Boolean {
        if (pkg.isNullOrEmpty()) return false
        return pkg in deniedPackages
    }

    fun shouldSkipPackage(pkg: String?, selfPackage: String): Boolean {
        return skipReason(pkg, selfPackage) != null
    }

    fun skipReason(pkg: String?, selfPackage: String): String? {
        return when {
            isOwnPackage(pkg, selfPackage) -> "own_app"
            isImePackage(pkg) || isDeniedPackage(pkg) -> "not_chat"
            else -> null
        }
    }

    private val chromeExact = setOf(
        "发送", "取消", "搜索", "返回", "更多", "相册", "拍照", "拍摄",
        "按住说话", "按住 说话", "表情", "语音", "语音输入", "切换", "键盘",
        "关闭", "确定", "完成", "复制", "转发", "删除", "引用", "提醒",
        "添加", "通讯录", "发现", "我", "微信", "消息", "联系人",
        "视频通话", "语音通话", "图片", "视频", "文件", "位置", "红包", "转账",
        "收藏", "设置", "发送给朋友", "输入", "说点什么", "说句话",
        "发送消息", "发送消息…", "发送消息...", "请输入", "相机", "拍摄照片",
        "聊天信息", "置顶", "清空", "新消息", "已读", "送达",
        "昨天", "今天", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日",
        "周一", "周二", "周三", "周四", "周五", "周六", "周日",
        "Send", "Search", "Cancel", "Done", "Copy", "Forward", "Delete",
        "Reply", "More", "Photos", "Camera", "Chats", "Calls", "Settings",
        "Stickers", "GIFs", "GIF", "Message", "Type a message", "Type a message…",
        "New message", "Today", "Yesterday", "Hold to talk", "Voice message",
        "OK", "Ok",
    )

    private val timestamp = Regex(
        """^(今天|昨天|星期[一二三四五六日天]|周[一二三四五六日])?\s*\d{1,2}:\d{2}(:\d{2})?$""",
    )
    private val dateOnly = Regex("""^\d{1,2}月\d{1,2}日$""")
    private val weekEn = Regex(
        """^(Mon|Tue|Wed|Thu|Fri|Sat|Sun|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)$""",
        RegexOption.IGNORE_CASE,
    )

    fun isChromeText(text: String): Boolean {
        val t = text.trim()
        if (t.isEmpty()) return true
        if (t in chromeExact) return true
        if (timestamp.matches(t) || dateOnly.matches(t) || weekEn.matches(t)) return true
        return false
    }

    fun shouldKeepNodeText(text: String?, editable: Boolean, password: Boolean): Boolean {
        if (editable || password) return false
        val t = text?.trim().orEmpty()
        if (t.isEmpty() || t.length > 500) return false
        return !isChromeText(t)
    }

    /**
     * 聊天气泡通常：自己靠右、对方靠左。
     * 用左右边距判断，避免长文本中心落在屏幕中间被误标成 unknown。
     * 通栏标题或居中系统提示保持 unknown。
     */
    fun inferRole(left: Int, right: Int, screenWidth: Int): String {
        if (screenWidth <= 0 || right <= left) return "unknown"
        // QQ/微信文本节点在头像和气泡内边距之后，很少贴着屏幕边缘。
        // 比较左右留白：哪侧明显更窄，就判定气泡对齐那一侧。
        val leftGap = left.toFloat()
        val rightGap = (screenWidth - right).toFloat()
        return when {
            rightGap * 1.6f <= leftGap -> "self"
            leftGap * 1.6f <= rightGap -> "peer"
            else -> "unknown"
        }
    }

    /** 窗口顶部标题栏/昵称，不当作聊天正文。 */
    fun isLikelyHeader(nodeTop: Int, windowTop: Int, headerHeightPx: Int): Boolean {
        return nodeTop - windowTop < headerHeightPx
    }

    /**
     * 最需要回的一句：优先对方最后一条；没有 peer 时用最后一条 unknown，不用自己的话。
     * 返回下标，没有则 -1。
     */
    fun pickTargetIndex(roles: List<String>): Int {
        val lastPeer = roles.indexOfLast { it == "peer" }
        if (lastPeer >= 0) return lastPeer
        return roles.indexOfLast { it == "unknown" }
    }

    /**
     * 连续短句允许重复；较长文本在树里出现两次时只保留一条（后出现的优先，并保留更明确的角色）。
     */
    fun shouldReplaceExisting(existingTexts: List<String>, text: String): Int {
        val last = existingTexts.indexOfLast { it == text }
        if (last < 0) return -1
        if (text.length >= 8) return last
        if (last == existingTexts.lastIndex) return last
        return -1
    }
}
