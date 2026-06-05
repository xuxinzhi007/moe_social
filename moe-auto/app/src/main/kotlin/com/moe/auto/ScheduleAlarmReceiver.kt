package com.moe.auto

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import java.io.File

class ScheduleAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val taskId = intent?.getStringExtra(SchedulePlanner.EXTRA_TASK_ID) ?: return
        val repo = ScheduleRepository(context)
        val task = repo.findById(taskId) ?: return
        if (!task.enabled) return

        AutoBridge.appendLog("定时触发: ${task.name}")

        when (task.scriptSourceType) {
            "asset" -> ScriptRunnerService.startAsset(context, task.scriptRef)
            "file" -> ScriptRunnerService.startFile(context, File(task.scriptRef))
            "app" -> {
                val intentToLaunch = context.packageManager.getLaunchIntentForPackage(task.scriptRef)
                if (intentToLaunch == null) {
                    AutoBridge.appendLog("未找到可启动应用: ${task.scriptRef}")
                } else {
                    intentToLaunch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intentToLaunch)
                }
            }
            else -> AutoBridge.appendLog("未知脚本来源: ${task.scriptSourceType}")
        }

        when (task.repeat) {
            ScheduleRepeat.ONCE -> repo.upsert(task.copy(enabled = false, nextRunAtMs = 0L))
            else -> {
                val next = ScheduleTimeCalculator.computeNextRunMs(task, System.currentTimeMillis() + 60_000)
                val updated = task.copy(nextRunAtMs = next)
                repo.upsert(updated)
                SchedulePlanner.schedule(context, updated)
            }
        }
    }
}
