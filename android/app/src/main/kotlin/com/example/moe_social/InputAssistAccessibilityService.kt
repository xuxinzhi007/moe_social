package com.example.moe_social

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.util.Log
import android.content.Context

/**
 * 独立的输入辅助无障碍服务：
 * - 只监听输入框聚焦/点击
 * - 通过 MainActivity 的 EventChannel 把事件发给 Flutter（显示悬浮球）
 *
 * 这样不会影响 AutoGLMAccessibilityService（自动化助手）。
 */
class InputAssistAccessibilityService : AccessibilityService() {

    companion object {
        var accessibilityEventListener: ((String, String) -> Unit)? = null
    }

    private fun isInputAssistEnabled(): Boolean {
        val sp = getSharedPreferences("moe_prefs", Context.MODE_PRIVATE)
        return sp.getBoolean("input_assist_enabled", false)
    }

    private var lastEmitAtMs: Long = 0

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.i("InputAssist", "InputAssist Accessibility Service Connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (!isInputAssistEnabled()) return

        if (event.eventType == AccessibilityEvent.TYPE_VIEW_FOCUSED ||
            event.eventType == AccessibilityEvent.TYPE_VIEW_CLICKED) {
            val source = event.source
            if (source != null) {
                val className = event.className?.toString() ?: ""
                val isInput = source.isEditable ||
                    className.contains("EditText", ignoreCase = true) ||
                    className.contains("Input", ignoreCase = true)

                if (isInput) {
                    val now = System.currentTimeMillis()
                    // 简单节流，避免疯狂弹球
                    if (now - lastEmitAtMs < 800) {
                        source.recycle()
                        return
                    }
                    lastEmitAtMs = now
                    val pkg = event.packageName?.toString() ?: ""
                    try {
                        accessibilityEventListener?.invoke("INPUT_FOCUSED", pkg)
                    } catch (_: Exception) {}
                }
                source.recycle()
            }
        }
    }

    override fun onInterrupt() {
        // no-op
    }
}

