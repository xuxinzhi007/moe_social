package com.example.moe_social

import android.accessibilityservice.AccessibilityService
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo
import android.widget.Toast
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * 读屏回复参谋 — 只读 UI 树，不点击、不输入、不代发。
 * 不写死聊天应用白名单；点按贴纸桌宠时读取当前前台聊天窗口可见文本。
 */
class ReplyAssistAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "ReplyAssistA11y"
        private const val SUGGEST_TIMEOUT_MS = 60_000L

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

    private data class WindowRoot(
        val root: AccessibilityNodeInfo,
        val pkg: String,
        val active: Boolean,
        val focused: Boolean,
        val area: Int,
    )

    private val mainHandler = Handler(Looper.getMainLooper())
    private var petOverlay: ReplyAssistPetOverlay? = null
    private var scanOverlay: ReplyAssistScanOverlay? = null
    private var pendingSuggest: (() -> Unit)? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        ReplyAssistFlutterHost.ensureChannel(this)
        Log.i(TAG, "ReplyAssist 无障碍已连接（只读模式）")
    }

    override fun onDestroy() {
        pendingSuggest = null
        dismissScan()
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
        val overlay = petOverlay ?: attachPet(ReplyAssistPetOverlay(this, ::onFaceActivate))
        return overlay.toggle()
    }

    fun isOverlayVisible(): Boolean = petOverlay?.isVisible() == true

    private fun overlay(): ReplyAssistPetOverlay {
        return petOverlay ?: attachPet(ReplyAssistPetOverlay(this, ::onFaceActivate))
    }

    private fun onFaceActivate() {
        val layer = overlay()
        if (layer.isBusy()) return
        layer.showListening()
        // 先让「正在看」画出来，再在下一帧读树，减轻点按时主线程掉帧。
        mainHandler.post { continueAfterListening(layer) }
    }

    private fun attachPet(layer: ReplyAssistPetOverlay): ReplyAssistPetOverlay {
        layer.onScanShouldStop = { onPetScanShouldStop(layer) }
        petOverlay = layer
        return layer
    }

    private fun continueAfterListening(layer: ReplyAssistPetOverlay) {
        if (!layer.isVisible() || !layer.isBusy()) return
        val snapshot = readForegroundSnapshot()
        ReplyAssistBridge.lastSnapshot = snapshot
        val reason = snapshot.optString("reason")
        val messages = snapshot.optJSONArray("messages")
        val count = messages?.length() ?: 0
        if (snapshot.optBoolean("needs_screenshot_fallback") || count == 0) {
            val msg = when (reason) {
                "own_app", "not_chat" -> getString(R.string.reply_assist_fallback_not_chat)
                else -> getString(R.string.reply_assist_fallback_empty)
            }
            layer.showFallback(msg)
            return
        }

        pendingSuggest = null
        dismissScan()
        val token = layer.beginRequest()
        if (!requestOverlaySuggest(layer, token, snapshot)) {
            return
        }

        val bubbles = extractScanBubbles(messages)
        val faceCenter = layer.faceCenterOnScreen()
        if (bubbles.isEmpty() || faceCenter == null || !layer.isScreenInteractive()) {
            enterThinking(layer, token)
            return
        }

        val scan = scanOverlay ?: ReplyAssistScanOverlay(this).also { scanOverlay = it }
        val started = scan.play(bubbles, faceCenter) {
            if (!layer.isCurrentRequest(token) || !layer.isVisible()) return@play
            enterThinking(layer, token)
        }
        if (started) {
            layer.raiseWindow()
            layer.faceCenterOnScreen()?.let { scan.updateFaceCenter(it) }
        } else {
            enterThinking(layer, token)
        }
    }

    private fun extractScanBubbles(messages: JSONArray?): List<ReplyAssistScanOverlay.Bubble> {
        if (messages == null) return emptyList()
        val headerHeight = (112 * resources.displayMetrics.density).toInt()
        val bubbles = mutableListOf<ReplyAssistScanOverlay.Bubble>()
        for (i in 0 until messages.length()) {
            val item = messages.optJSONObject(i) ?: continue
            if (!item.has("left") || !item.has("top") || !item.has("right") || !item.has("bottom")) {
                continue
            }
            val left = item.optInt("left")
            val top = item.optInt("top")
            val right = item.optInt("right")
            val bottom = item.optInt("bottom")
            if (right <= left || bottom <= top) continue
            // 标题栏里的框不再画，即使文案过滤漏网。
            if (top < headerHeight) continue
            bubbles.add(
                ReplyAssistScanOverlay.Bubble(
                    bounds = Rect(left, top, right, bottom),
                    isTarget = item.optBoolean("target"),
                ),
            )
        }
        return bubbles
    }

    private fun enterThinking(layer: ReplyAssistPetOverlay, token: Int) {
        if (!layer.isCurrentRequest(token) || !layer.isVisible()) return
        layer.showThinking()
        flushPendingSuggest()
    }

    private fun shouldDeferSuggestResult(layer: ReplyAssistPetOverlay): Boolean {
        return scanOverlay?.isPlaying() == true || (layer.isBusy() && !layer.isThinking())
    }

    private fun flushPendingSuggest() {
        val pending = pendingSuggest
        pendingSuggest = null
        pending?.invoke()
    }

    private fun onPetScanShouldStop(layer: ReplyAssistPetOverlay) {
        val playing = scanOverlay?.isPlaying() == true
        dismissScan()
        if (playing && layer.isVisible() && layer.isBusy() && !layer.isThinking()) {
            layer.showThinking()
            flushPendingSuggest()
        } else if (!playing || !layer.isVisible() || !layer.isBusy()) {
            pendingSuggest = null
        }
    }

    private fun dismissScan() {
        scanOverlay?.dismiss()
    }

    /** 请求挂在无障碍服务上：用缓存引擎的通道，不依赖 MainActivity 还活着。成功发出请求返回 true。 */
    private fun requestOverlaySuggest(
        layer: ReplyAssistPetOverlay,
        token: Int,
        snapshot: JSONObject,
    ): Boolean {
        val channel = ReplyAssistFlutterHost.ensureChannel(this)
        if (channel == null) {
            degradeOpenApp(layer)
            return false
        }

        val payload = ReplyAssistBridge.jsonToMap(snapshot)
        try {
            channel.invokeMethod(
                "onOverlaySuggest",
                payload,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        mainHandler.post {
                            deliverSuggest(layer, token) {
                                applySuggestResult(layer, result)
                            }
                        }
                    }

                    override fun error(
                        errorCode: String,
                        errorMessage: String?,
                        errorDetails: Any?,
                    ) {
                        mainHandler.post {
                            deliverSuggest(layer, token) {
                                layer.showFallback(
                                    errorMessage?.takeIf { it.isNotBlank() }
                                        ?: getString(R.string.reply_assist_open_app),
                                )
                            }
                        }
                    }

                    override fun notImplemented() {
                        mainHandler.post {
                            deliverSuggest(layer, token) {
                                degradeOpenApp(layer)
                            }
                        }
                    }
                },
            )
        } catch (e: Exception) {
            Log.w(TAG, "onOverlaySuggest failed", e)
            degradeOpenApp(layer)
            return false
        }

        mainHandler.postDelayed({
            if (layer.isCurrentRequest(token) && layer.isThinking()) {
                layer.showFallback(getString(R.string.reply_assist_timeout))
            }
        }, SUGGEST_TIMEOUT_MS)
        return true
    }

    private fun deliverSuggest(layer: ReplyAssistPetOverlay, token: Int, apply: () -> Unit) {
        if (!layer.isCurrentRequest(token)) return
        if (shouldDeferSuggestResult(layer)) {
            pendingSuggest = {
                if (layer.isCurrentRequest(token) && layer.isVisible()) {
                    apply()
                }
            }
            return
        }
        apply()
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

    /** 主动读取当前前台聊天窗口可见文本（best-effort，不限定聊天应用）。 */
    fun readForegroundSnapshot(): JSONObject {
        val picked = resolveForegroundRoot()
        if (picked == null) {
            return emptySnapshot(needsFallback = true, reason = "no_root")
        }
        val (root, pkg, skipReason) = picked
        if (skipReason != null) {
            root.recycle()
            return emptySnapshot(
                needsFallback = false,
                reason = skipReason,
                appPackage = pkg,
            )
        }
        val lines = mutableListOf<JSONObject>()
        val rootBounds = Rect()
        root.getBoundsInScreen(rootBounds)
        val screenWidth = rootBounds.width().takeIf { it > 0 }
            ?: resources.displayMetrics.widthPixels
        val headerHeight = (112 * resources.displayMetrics.density).toInt()
        val headerTitles = mutableSetOf<String>()
        collectHeaderTitles(root, rootBounds.top, headerHeight, headerTitles)
        collectTextNodes(root, lines, screenWidth, rootBounds.top, headerHeight, headerTitles)
        root.recycle()
        if (headerTitles.isNotEmpty()) {
            Log.i(TAG, "读屏标题过滤: ${headerTitles.joinToString()}")
        }

        if (lines.isEmpty()) {
            return emptySnapshot(
                needsFallback = true,
                reason = "empty_tree",
                appPackage = pkg,
            )
        }
        val kept = lines.takeLast(24)
        val targetIndex = ReplyAssistSnapshotPolicy.pickTargetIndex(
            kept.map { it.optString("role") },
        )
        val messages = JSONArray()
        kept.forEachIndexed { index, item ->
            if (index == targetIndex) {
                item.put("target", true)
            }
            messages.put(item)
        }
        val json = JSONObject()
            .put("needs_screenshot_fallback", false)
            .put("app_package", pkg)
            .put("adult_intimate", ReplyAssistAdultSettings.isEnabled(this))
            .put("messages", messages)
        if (targetIndex >= 0) {
            json.put("target_message", JSONObject(kept[targetIndex].toString()))
        }
        return json
    }

    /**
     * 兼容旧 MethodChannel / Flutter 调用名；实现与 [readForegroundSnapshot] 相同。
     */
    fun readWeChatSnapshot(): JSONObject = readForegroundSnapshot()

    /**
     * 从可交互窗口里挑真正的前台应用窗，跳过输入法、系统窗和 Moe 自己。
     */
    private fun resolveForegroundRoot(): Triple<AccessibilityNodeInfo, String, String?>? {
        val self = packageName
        val ranked = mutableListOf<WindowRoot>()
        val skipped = mutableListOf<WindowRoot>()
        val windowList = try {
            windows
        } catch (_: Exception) {
            emptyList()
        }
        for (window in windowList) {
            if (window.type != AccessibilityWindowInfo.TYPE_APPLICATION) continue
            val root = window.root ?: continue
            val pkg = root.packageName?.toString().orEmpty()
            val bounds = Rect()
            window.getBoundsInScreen(bounds)
            val item = WindowRoot(
                root = root,
                pkg = pkg,
                active = window.isActive,
                focused = window.isFocused,
                area = (bounds.width() * bounds.height()).coerceAtLeast(0),
            )
            if (ReplyAssistSnapshotPolicy.shouldSkipPackage(pkg, self)) {
                skipped.add(item)
            } else {
                ranked.add(item)
            }
        }

        val best = ranked.maxWithOrNull(
            compareBy<WindowRoot> { it.active }
                .thenBy { it.focused }
                .thenBy { it.area },
        )
        recycleRoots(ranked, except = best?.root)
        recycleRoots(skipped, except = null)
        if (best != null) {
            return Triple(best.root, best.pkg, null)
        }

        val fallback = rootInActiveWindow ?: return null
        val pkg = fallback.packageName?.toString().orEmpty()
        return Triple(fallback, pkg, ReplyAssistSnapshotPolicy.skipReason(pkg, self))
    }

    private fun recycleRoots(items: List<WindowRoot>, except: AccessibilityNodeInfo?) {
        items.forEach { item ->
            if (item.root !== except) {
                item.root.recycle()
            }
        }
    }

    private fun collectHeaderTitles(
        node: AccessibilityNodeInfo,
        windowTop: Int,
        headerHeight: Int,
        out: MutableSet<String>,
    ) {
        val visible = try {
            node.isVisibleToUser
        } catch (_: Exception) {
            true
        }
        if (!visible) return
        val bounds = Rect()
        node.getBoundsInScreen(bounds)
        val text = node.text?.toString()?.trim().orEmpty()
        val desc = try {
            node.contentDescription?.toString()?.trim().orEmpty()
        } catch (_: Exception) {
            ""
        }
        val viewId = try {
            node.viewIdResourceName
        } catch (_: Exception) {
            null
        }
        val inHeader = ReplyAssistSnapshotPolicy.isLikelyHeader(
            bounds.top,
            windowTop,
            headerHeight,
        ) || (
            bounds.height() in 1..headerHeight &&
                bounds.top >= windowTop &&
                bounds.bottom <= windowTop + headerHeight
        )
        val toolbar = ReplyAssistSnapshotPolicy.isToolbarLike(
            node.className?.toString(),
            viewId,
        )
        if (inHeader || toolbar) {
            if (text.isNotEmpty()) out.add(text)
            if (desc.isNotEmpty() && desc.length <= 40) out.add(desc)
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            collectHeaderTitles(child, windowTop, headerHeight, out)
            child.recycle()
        }
    }

    private fun collectTextNodes(
        node: AccessibilityNodeInfo,
        out: MutableList<JSONObject>,
        screenWidth: Int,
        windowTop: Int,
        headerHeight: Int,
        headerTitles: Set<String>,
    ) {
        val visible = try {
            node.isVisibleToUser
        } catch (_: Exception) {
            true
        }
        if (!visible) return

        val editable = node.isEditable
        val password = try {
            node.isPassword
        } catch (_: Exception) {
            false
        }
        val raw = node.text?.toString()
        val bounds = Rect()
        node.getBoundsInScreen(bounds)
        // 整块都在标题栏里的节点不再往下走，避免把昵称串进对话。
        if (bounds.height() in 1..headerHeight &&
            bounds.top >= windowTop &&
            bounds.bottom <= windowTop + headerHeight
        ) {
            return
        }
        val inHeader = ReplyAssistSnapshotPolicy.isLikelyHeader(bounds.top, windowTop, headerHeight)
        if (!inHeader &&
            ReplyAssistSnapshotPolicy.shouldKeepNodeText(raw, editable, password) &&
            !ReplyAssistSnapshotPolicy.shouldDropAsHeaderTitle(raw!!.trim(), headerTitles)
        ) {
            val text = raw.trim()
            val role = ReplyAssistSnapshotPolicy.inferRole(bounds.left, bounds.right, screenWidth)
            val existing = ReplyAssistSnapshotPolicy.shouldReplaceExisting(
                out.map { it.optString("text") },
                text,
            )
            if (existing >= 0) {
                val keepRole = if (role != "unknown") role else out[existing].optString("role")
                out.removeAt(existing)
                out.add(messageJson(keepRole, text, bounds))
            } else {
                out.add(messageJson(role, text, bounds))
            }
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            collectTextNodes(child, out, screenWidth, windowTop, headerHeight, headerTitles)
            child.recycle()
        }
    }

    private fun messageJson(role: String, text: String, bounds: Rect): JSONObject {
        return JSONObject()
            .put("role", role)
            .put("text", text)
            .put("left", bounds.left)
            .put("top", bounds.top)
            .put("right", bounds.right)
            .put("bottom", bounds.bottom)
    }

    private fun emptySnapshot(
        needsFallback: Boolean,
        reason: String,
        appPackage: String = "",
    ): JSONObject {
        val json = JSONObject()
            .put("needs_screenshot_fallback", needsFallback)
            .put("reason", reason)
            .put("messages", JSONArray())
        if (appPackage.isNotEmpty()) {
            json.put("app_package", appPackage)
        }
        json.put("adult_intimate", ReplyAssistAdultSettings.isEnabled(this))
        return json
    }
}
