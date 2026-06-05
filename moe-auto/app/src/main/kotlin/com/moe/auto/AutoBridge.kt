package com.moe.auto

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * 无障碍服务与 UI / 脚本执行器之间的桥接单例。
 */
object AutoBridge {
    private lateinit var appContext: Context

    @Volatile
    var accessibilityService: MoeAutoAccessibilityService? = null
        internal set

    private val _running = MutableStateFlow(false)
    val running: StateFlow<Boolean> = _running.asStateFlow()

    private val _logs = MutableStateFlow<List<String>>(emptyList())
    val logs: StateFlow<List<String>> = _logs.asStateFlow()

    private const val MAX_LOG_LINES = 200

    fun init(context: Context) {
        appContext = context.applicationContext
    }

    fun context(): Context = appContext

    fun isServiceConnected(): Boolean = accessibilityService != null

    fun setRunning(value: Boolean) {
        _running.value = value
    }

    fun appendLog(line: String) {
        val stamped = "[${System.currentTimeMillis() % 100_000}] $line"
        _logs.value = (_logs.value + stamped).takeLast(MAX_LOG_LINES)
    }

    fun clearLogs() {
        _logs.value = emptyList()
    }

    fun requestStop() {
        ScriptRunnerService.requestStop(appContext)
    }
}
