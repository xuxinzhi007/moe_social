package com.example.moe_social

import android.content.Context

/**
 * 「成人向 / 亲密对话」开关。页面通过 MethodChannel `setAdultMode` 写入；
 * 浮窗发起 suggest 时带到请求里。默认关闭。
 */
object ReplyAssistAdultSettings {
    const val PREFS_NAME = "FlutterSharedPreferences"
    const val PREFS_KEY = "flutter.reply_assist_adult_intimate"

    @Volatile
    private var cached: Boolean? = null

    fun setEnabled(enabled: Boolean) {
        cached = enabled
    }

    fun isEnabled(context: Context): Boolean {
        cached?.let { return it }
        return try {
            val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            if (prefs.contains(PREFS_KEY)) {
                prefs.getBoolean(PREFS_KEY, false)
            } else {
                false
            }
        } catch (_: Exception) {
            false
        }
    }
}
