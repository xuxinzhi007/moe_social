package com.moe.auto

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.graphics.drawable.Drawable
import android.os.Build

data class InstalledAppInfo(
    val packageName: String,
    val label: String,
    val icon: Drawable?,
)

object InstalledAppsHelper {
    @Volatile
    private var labelCache: Map<String, String> = emptyMap()

    fun loadLaunchableApps(context: Context): List<InstalledAppInfo> {
        val pm = context.packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        @Suppress("DEPRECATION")
        val activities = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.queryIntentActivities(intent, android.content.pm.PackageManager.ResolveInfoFlags.of(0))
        } else {
            pm.queryIntentActivities(intent, 0)
        }
        val seen = linkedSetOf<String>()
        val apps = mutableListOf<InstalledAppInfo>()
        for (ri in activities) {
            val pkg = ri.activityInfo.packageName
            if (!seen.add(pkg)) continue
            val appInfo: ApplicationInfo = ri.activityInfo.applicationInfo
            val label = ri.loadLabel(pm).toString().ifBlank { pkg }
            apps.add(
                InstalledAppInfo(
                    packageName = pkg,
                    label = label,
                    icon = runCatching { ri.loadIcon(pm) }.getOrNull(),
                ),
            )
        }
        val sorted = apps.sortedBy { it.label.lowercase() }
        labelCache = sorted.associate { it.packageName to it.label }
        return sorted
    }

    fun labelFor(packageName: String): String? = labelCache[packageName]

    fun warmLabelCache(context: Context) {
        if (labelCache.isEmpty()) {
            loadLaunchableApps(context)
        }
    }
}
