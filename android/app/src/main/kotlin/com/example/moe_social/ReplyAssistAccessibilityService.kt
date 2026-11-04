package com.example.moe_social

import android.accessibilityservice.AccessibilityService
import android.graphics.PixelFormat
import android.os.Build
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Toast
import org.json.JSONArray
import org.json.JSONObject

/**
 * 读屏回复参谋 — 只读 UI 树，不点击、不输入、不代发。
 * 包名白名单：微信。点按悬浮球触发一次读屏。
 */
class ReplyAssistAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "ReplyAssistA11y"
        private const val WECHAT_PACKAGE = "com.tencent.mm"

        @Volatile
        private var instance: ReplyAssistAccessibilityService? = null

        fun getInstance(): ReplyAssistAccessibilityService? = instance

        fun isServiceEnabled(context: android.content.Context): Boolean {
            val enabled = Settings.Secure.getInt(
                context.contentResolver,
                Settings.Secure.ACCESSIBILITY_ENABLED,
                0,
            ) == 1
            if (!enabled) return false
            val expected = android.content.ComponentName(
                context,
                ReplyAssistAccessibilityService::class.java,
            ).flattenToString()
            val setting = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
            ) ?: return false
            return setting.split(':').any { it.equals(expected, ignoreCase = true) }
        }
    }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var overlayVisible = false

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        Log.i(TAG, "ReplyAssist 无障碍已连接（只读模式）")
    }

    override fun onDestroy() {
        hideOverlayBall()
        instance = null
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // 不持续监听；读屏仅在用户点按悬浮球时主动调用。
    }

    override fun onInterrupt() {
        Log.w(TAG, "ReplyAssist 无障碍中断")
    }

    fun toggleOverlay(): Boolean {
        return if (overlayVisible) {
            hideOverlayBall()
            false
        } else {
            showOverlayBall()
            true
        }
    }

    fun isOverlayVisible(): Boolean = overlayVisible

    private fun showOverlayBall() {
        if (overlayView != null) {
            overlayVisible = true
            return
        }
        val wm = windowManager ?: return
        val ball = View(this).apply {
            setBackgroundColor(0xCC7F7FD5.toInt())
            contentDescription = "Moe 回复参谋"
            setOnClickListener { onOverlayTap() }
        }
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            dp(52),
            dp(52),
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            x = dp(12)
            y = dp(120)
        }
        wm.addView(ball, params)
        overlayView = ball
        overlayVisible = true
    }

    private fun hideOverlayBall() {
        val wm = windowManager
        val view = overlayView
        if (wm != null && view != null) {
            wm.removeView(view)
        }
        overlayView = null
        overlayVisible = false
    }

    private fun onOverlayTap() {
        val snapshot = readWeChatSnapshot()
        val count = snapshot.optJSONArray("messages")?.length() ?: 0
        val msg = if (snapshot.optBoolean("needs_screenshot_fallback")) {
            "读屏为空，请用截图/粘贴"
        } else if (count == 0) {
            "未读到消息"
        } else {
            "已读取 $count 条，请回 App 查看"
        }
        Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
        ReplyAssistBridge.lastSnapshot = snapshot
    }

    /** 主动读取当前前台微信窗口可见文本（best-effort）。 */
    fun readWeChatSnapshot(): JSONObject {
        val root = rootInActiveWindow
        if (root == null) {
            return emptySnapshot(needsFallback = true, reason = "no_root")
        }
        val pkg = root.packageName?.toString().orEmpty()
        if (pkg != WECHAT_PACKAGE) {
            root.recycle()
            return emptySnapshot(needsFallback = false, reason = "not_wechat")
        }
        val lines = mutableListOf<JSONObject>()
        collectTextNodes(root, lines)
        root.recycle()

        if (lines.isEmpty()) {
            return emptySnapshot(needsFallback = true, reason = "empty_tree")
        }
        val messages = JSONArray()
        lines.takeLast(24).forEach { messages.put(it) }
        return JSONObject()
            .put("needs_screenshot_fallback", false)
            .put("app_package", WECHAT_PACKAGE)
            .put("messages", messages)
    }

    private fun collectTextNodes(node: AccessibilityNodeInfo, out: MutableList<JSONObject>) {
        val text = node.text?.toString()?.trim().orEmpty()
        if (text.isNotEmpty() && text.length in 1..500) {
            out.add(
                JSONObject()
                    .put("role", "unknown")
                    .put("text", text),
            )
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            collectTextNodes(child, out)
            child.recycle()
        }
    }

    private fun emptySnapshot(needsFallback: Boolean, reason: String): JSONObject {
        return JSONObject()
            .put("needs_screenshot_fallback", needsFallback)
            .put("reason", reason)
            .put("messages", JSONArray())
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }
}

object ReplyAssistBridge {
    @Volatile
    var lastSnapshot: JSONObject = JSONObject()
}
