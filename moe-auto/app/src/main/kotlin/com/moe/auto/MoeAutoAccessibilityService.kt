package com.moe.auto

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Path
import android.os.Bundle
import android.util.DisplayMetrics
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import kotlinx.coroutines.delay
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

class MoeAutoAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "MoeAutoA11y"
    }

    private lateinit var displayMetrics: DisplayMetrics

    override fun onServiceConnected() {
        super.onServiceConnected()
        displayMetrics = resources.displayMetrics
        AutoBridge.accessibilityService = this
        AutoBridge.appendLog("无障碍服务已连接")
        Log.i(TAG, "connected")
    }

    override fun onDestroy() {
        AutoBridge.accessibilityService = null
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // 被动监听，脚本执行时主动读 rootInActiveWindow
    }

    override fun onInterrupt() {
        AutoBridge.appendLog("无障碍服务中断")
    }

    suspend fun tapNormalized(x: Float, y: Float): Boolean {
        val px = x.coerceIn(0f, 1f) * displayMetrics.widthPixels
        val py = y.coerceIn(0f, 1f) * displayMetrics.heightPixels
        val path = Path().apply { moveTo(px, py) }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 50))
            .build()
        return dispatchGestureAwait(gesture)
    }

    suspend fun swipeNormalized(
        x1: Float,
        y1: Float,
        x2: Float,
        y2: Float,
        durationMs: Long,
    ): Boolean {
        val sx = x1.coerceIn(0f, 1f) * displayMetrics.widthPixels
        val sy = y1.coerceIn(0f, 1f) * displayMetrics.heightPixels
        val ex = x2.coerceIn(0f, 1f) * displayMetrics.widthPixels
        val ey = y2.coerceIn(0f, 1f) * displayMetrics.heightPixels
        val path = Path().apply {
            moveTo(sx, sy)
            lineTo(ex, ey)
        }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, durationMs.coerceAtLeast(100)))
            .build()
        return dispatchGestureAwait(gesture)
    }

    private suspend fun dispatchGestureAwait(gesture: GestureDescription): Boolean {
        return suspendCancellableCoroutine { cont ->
            val ok = dispatchGesture(
                gesture,
                object : GestureResultCallback() {
                    override fun onCompleted(gestureDescription: GestureDescription?) {
                        if (cont.isActive) cont.resume(true)
                    }

                    override fun onCancelled(gestureDescription: GestureDescription?) {
                        if (cont.isActive) cont.resume(false)
                    }
                },
                null,
            )
            if (!ok && cont.isActive) {
                cont.resume(false)
            }
        }
    }

    suspend fun clickText(text: String, timeoutMs: Long): Boolean {
        val deadline = System.currentTimeMillis() + timeoutMs
        while (System.currentTimeMillis() < deadline) {
            val root = rootInActiveWindow
            if (root != null) {
                val node = UiFinder.findByText(root, text)
                if (node != null) {
                    val clicked = clickNode(node)
                    if (node !== root) {
                        node.recycle()
                    }
                    root.recycle()
                    if (clicked) return true
                } else {
                    root.recycle()
                }
            }
            delay(200)
        }
        return false
    }

    suspend fun waitForText(text: String, timeoutMs: Long): Boolean {
        val deadline = System.currentTimeMillis() + timeoutMs
        while (System.currentTimeMillis() < deadline) {
            val root = rootInActiveWindow
            if (root != null) {
                val found = UiFinder.containsText(root, text)
                root.recycle()
                if (found) return true
            }
            delay(250)
        }
        return false
    }

    private suspend fun clickNode(node: AccessibilityNodeInfo): Boolean {
        if (node.isClickable && node.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
            return true
        }
        var parent = node.parent
        while (parent != null) {
            if (parent.isClickable && parent.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                parent.recycle()
                return true
            }
            val next = parent.parent
            parent.recycle()
            parent = next
        }
        val rect = android.graphics.Rect()
        node.getBoundsInScreen(rect)
        val cx = rect.centerX().toFloat() / displayMetrics.widthPixels
        val cy = rect.centerY().toFloat() / displayMetrics.heightPixels
        return tapNormalized(cx, cy)
    }

    fun inputText(text: String): Boolean {
        val root = rootInActiveWindow ?: return false
        val edit = UiFinder.findEditable(root) ?: run {
            root.recycle()
            return pasteViaClipboard(text)
        }
        val args = Bundle().apply {
            putCharSequence(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                text,
            )
        }
        val ok = edit.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
        if (edit !== root) edit.recycle()
        root.recycle()
        if (ok) return true
        return pasteViaClipboard(text)
    }

    private fun pasteViaClipboard(text: String): Boolean {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newPlainText("moe-auto", text))
        val root = rootInActiveWindow ?: return false
        val edit = UiFinder.findEditable(root) ?: run {
            root.recycle()
            return false
        }
        edit.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
        val ok = edit.performAction(AccessibilityNodeInfo.ACTION_PASTE)
        if (edit !== root) edit.recycle()
        root.recycle()
        return ok
    }

    fun launchPackage(packageName: String): Boolean {
        val intent = packageManager.getLaunchIntentForPackage(packageName) ?: return false
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        return true
    }

    fun performGlobalBack(): Boolean = performGlobalAction(GLOBAL_ACTION_BACK)
    fun performGlobalHome(): Boolean = performGlobalAction(GLOBAL_ACTION_HOME)
    fun performGlobalRecents(): Boolean = performGlobalAction(GLOBAL_ACTION_RECENTS)
}
