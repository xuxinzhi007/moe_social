package com.example.moe_social

import android.accessibilityservice.AccessibilityService
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Toast
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * 读屏回复参谋 — 只读 UI 树，不点击、不输入、不代发。
 * 包名白名单：微信。点按贴纸桌宠触发一次读屏，当场出复制气泡。
 */
class ReplyAssistAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "ReplyAssistA11y"
        private const val WECHAT_PACKAGE = "com.tencent.mm"
        private const val SUGGEST_TIMEOUT_MS = 25_000L

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

    private val mainHandler = Handler(Looper.getMainLooper())
    private var petOverlay: ReplyAssistPetOverlay? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.i(TAG, "ReplyAssist 无障碍已连接（只读模式）")
    }

    override fun onDestroy() {
        petOverlay?.hide()
        petOverlay = null
        instance = null
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // 不持续监听；读屏仅在用户点按桌宠时主动调用。
    }

    override fun onInterrupt() {
        Log.w(TAG, "ReplyAssist 无障碍中断")
    }

    fun toggleOverlay(): Boolean {
        val overlay = petOverlay ?: ReplyAssistPetOverlay(this, ::onFaceActivate).also {
            petOverlay = it
        }
        return overlay.toggle()
    }

    fun isOverlayVisible(): Boolean = petOverlay?.isVisible() == true

    private fun overlay(): ReplyAssistPetOverlay {
        return petOverlay ?: ReplyAssistPetOverlay(this, ::onFaceActivate).also {
            petOverlay = it
        }
    }

    private fun onFaceActivate() {
        val layer = overlay()
        if (layer.isBusy()) return
        layer.showListening()
        val snapshot = readWeChatSnapshot()
        ReplyAssistBridge.lastSnapshot = snapshot
        if (!layer.isVisible()) return
        val reason = snapshot.optString("reason")
        val count = snapshot.optJSONArray("messages")?.length() ?: 0
        if (snapshot.optBoolean("needs_screenshot_fallback") || count == 0) {
            val msg = when (reason) {
                "not_wechat" -> getString(R.string.reply_assist_fallback_not_wechat)
                else -> getString(R.string.reply_assist_fallback_empty)
            }
            layer.showFallback(msg)
            return
        }

        layer.showThinking()
        val token = layer.beginRequest()
        val channel = ReplyAssistBridge.channel
        if (channel == null) {
            degradeOpenApp(layer)
            return
        }

        val payload = ReplyAssistBridge.jsonToMap(snapshot)
        try {
            channel.invokeMethod(
                "onOverlaySuggest",
                payload,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        mainHandler.post {
                            if (!layer.isCurrentRequest(token)) return@post
                            applySuggestResult(layer, result)
                        }
                    }

                    override fun error(
                        errorCode: String,
                        errorMessage: String?,
                        errorDetails: Any?,
                    ) {
                        mainHandler.post {
                            if (!layer.isCurrentRequest(token)) return@post
                            layer.showFallback(
                                errorMessage?.takeIf { it.isNotBlank() }
                                    ?: getString(R.string.reply_assist_open_app),
                            )
                        }
                    }

                    override fun notImplemented() {
                        mainHandler.post {
                            if (!layer.isCurrentRequest(token)) return@post
                            degradeOpenApp(layer)
                        }
                    }
                },
            )
        } catch (e: Exception) {
            Log.w(TAG, "onOverlaySuggest failed", e)
            degradeOpenApp(layer)
            return
        }

        mainHandler.postDelayed({
            if (layer.isCurrentRequest(token) && layer.isThinking()) {
                layer.showFallback(getString(R.string.reply_assist_timeout))
            }
        }, SUGGEST_TIMEOUT_MS)
    }

    private fun degradeOpenApp(layer: ReplyAssistPetOverlay) {
        layer.showFallback(getString(R.string.reply_assist_open_app))
        Toast.makeText(this, R.string.reply_assist_open_app, Toast.LENGTH_SHORT).show()
    }

    private fun applySuggestResult(layer: ReplyAssistPetOverlay, result: Any?) {
        val map = result as? Map<*, *>
        if (map == null) {
            layer.showFallback(getString(R.string.reply_assist_fallback_empty))
            return
        }
        if (map["ok"] == false) {
            val msg = map["message"]?.toString().orEmpty()
            layer.showFallback(
                msg.ifBlank { getString(R.string.reply_assist_fallback_empty) },
            )
            return
        }
        val optionsRaw = map["options"] as? List<*>
        val options = optionsRaw?.mapNotNull { item ->
            val o = item as? Map<*, *> ?: return@mapNotNull null
            val text = o["text"]?.toString().orEmpty()
            if (text.isEmpty()) null else Pair(o["label"]?.toString().orEmpty(), text)
        }.orEmpty()
        if (options.isEmpty()) {
            layer.showFallback(getString(R.string.reply_assist_fallback_empty))
            return
        }
        layer.showOptions(options.take(3))
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
}
