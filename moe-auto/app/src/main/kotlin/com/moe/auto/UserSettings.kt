package com.moe.auto

import android.content.Context

class UserSettings(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    var executionOverlayEnabled: Boolean
        get() = prefs.getBoolean(KEY_OVERLAY, true)
        set(value) {
            prefs.edit().putBoolean(KEY_OVERLAY, value).apply()
            ExecutionOverlayManager.enabled = value
        }

    var showNotificationStep: Boolean
        get() = prefs.getBoolean(KEY_NOTIF_STEP, false)
        set(value) = prefs.edit().putBoolean(KEY_NOTIF_STEP, value).apply()

    fun applyToRuntime() {
        ExecutionOverlayManager.enabled = executionOverlayEnabled
    }

    companion object {
        private const val PREFS = "moe_auto_settings"
        private const val KEY_OVERLAY = "execution_overlay"
        private const val KEY_NOTIF_STEP = "notification_step"

        fun get(context: Context): UserSettings = UserSettings(context)
    }
}
