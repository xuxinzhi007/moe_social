package com.moe.auto

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.provider.Settings
import android.view.accessibility.AccessibilityManager

object PermissionHelper {
    fun isAccessibilityEnabled(context: Context): Boolean {
        val expected = ComponentName(context, MoeAutoAccessibilityService::class.java)
        if (isEnabledViaManager(context, expected)) {
            return true
        }
        return isEnabledViaSecureSettings(context, expected)
    }

    private fun isEnabledViaManager(context: Context, expected: ComponentName): Boolean {
        val am = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        return am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
            .any { info ->
                val s = info.resolveInfo.serviceInfo
                val className = if (s.name.startsWith(".")) {
                    s.packageName + s.name
                } else {
                    s.name
                }
                s.packageName == expected.packageName && className == expected.className
            }
    }

    private fun isEnabledViaSecureSettings(context: Context, expected: ComponentName): Boolean {
        val enabled = Settings.Secure.getInt(
            context.contentResolver,
            Settings.Secure.ACCESSIBILITY_ENABLED,
            0,
        ) == 1
        if (!enabled) return false

        val list = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false

        return list.split(':').any { raw ->
            val cn = ComponentName.unflattenFromString(raw) ?: return@any false
            val className = if (cn.className.startsWith(".")) {
                cn.packageName + cn.className
            } else {
                cn.className
            }
            cn.packageName == expected.packageName && className == expected.className
        }
    }

    fun canDrawOverlays(context: Context): Boolean {
        return Settings.canDrawOverlays(context)
    }

    fun isServiceConnected(): Boolean = AutoBridge.accessibilityService != null
}
