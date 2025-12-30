package com.example.moe_social

object AppPackages {
    val APP_MAP = mapOf(
        // Social & Messaging
        "微信" to "com.tencent.mm",
        "QQ" to "com.tencent.mobileqq",
        "微博" to "com.sina.weibo",
        // E-commerce
        "淘宝" to "com.taobao.taobao",
        "京东" to "com.jingdong.app.mall",
        "拼多多" to "com.xunmeng.pinduoduo",
        // Lifestyle & Social
        "小红书" to "com.xingin.xhs",
        "豆瓣" to "com.douban.frodo",
        "知乎" to "com.zhihu.android",
        // Maps & Navigation
        "高德地图" to "com.autonavi.minimap",
        "百度地图" to "com.baidu.BaiduMap",
        // Food & Services
        "美团" to "com.sankuai.meituan",
        "大众点评" to "com.dianping.v1",
        "饿了么" to "me.ele",
        "肯德基" to "com.yek.android.kfc.activitys",
        // Travel
        "携程" to "ctrip.android.view",
        "铁路12306" to "com.MobileTicket",
        "12306" to "com.MobileTicket",
        "去哪儿" to "com.Qunar",
        "滴滴出行" to "com.sdu.didi.psnger",
        // Video & Entertainment
        "bilibili" to "tv.danmaku.bili",
        "抖音" to "com.ss.android.ugc.aweme",
        "快手" to "com.smile.gifmaker",
        "腾讯视频" to "com.tencent.qqlive",
        "爱奇艺" to "com.qiyi.video",
        "优酷视频" to "com.youku.phone",
        // Music
        "网易云音乐" to "com.netease.cloudmusic",
        "QQ音乐" to "com.tencent.qqmusic",
        // Reading
        "番茄小说" to "com.dragon.read",
        "七猫免费小说" to "com.kmxs.reader",
        // Productivity
        "飞书" to "com.ss.android.lark",
        "QQ邮箱" to "com.tencent.androidqqmail",
        // Common (System Apps)
        "Settings" to "com.android.settings",
        "Chrome" to "com.android.chrome",
        "Gmail" to "com.google.android.gm",
        "Google Maps" to "com.google.android.apps.maps"
    )

    fun getPackageName(appName: String): String? {
        return APP_MAP[appName]
    }
}

