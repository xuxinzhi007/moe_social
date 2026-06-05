package com.moe.auto

import android.app.Application

class MoeAutoApp : Application() {
    override fun onCreate() {
        super.onCreate()
        AutoBridge.init(applicationContext)
        ExecutionOverlayManager.init(applicationContext)
        UserSettings.get(this).applyToRuntime()
        InstalledAppsHelper.warmLabelCache(this)
        SchedulePlanner.rescheduleAll(this)
    }
}
