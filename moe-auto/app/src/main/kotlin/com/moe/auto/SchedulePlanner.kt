package com.moe.auto

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings

object SchedulePlanner {
    const val EXTRA_TASK_ID = "task_id"

    fun rescheduleAll(context: Context) {
        val repo = ScheduleRepository(context)
        repo.listAll().filter { it.enabled }.forEach { schedule(context, it) }
        cancelOrphans(context, repo.listAll().map { it.id }.toSet())
    }

    fun schedule(context: Context, task: ScheduledTask) {
        if (!task.enabled) {
            cancel(context, task.id)
            return
        }
        val next = if (task.nextRunAtMs > System.currentTimeMillis()) {
            task.nextRunAtMs
        } else {
            ScheduleTimeCalculator.computeNextRunMs(task)
        }
        val repo = ScheduleRepository(context)
        repo.upsert(task.copy(nextRunAtMs = next))

        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = pendingIntent(context, task.id)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, pi)
            } else {
                @Suppress("DEPRECATION")
                am.setExact(AlarmManager.RTC_WAKEUP, next, pi)
            }
        } catch (_: SecurityException) {
            AutoBridge.appendLog("定时任务需要精确闹钟权限: ${task.name}")
        }
    }

    fun cancel(context: Context, taskId: String) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(pendingIntent(context, taskId))
    }

    fun canScheduleExactAlarms(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return am.canScheduleExactAlarms()
    }

    fun openExactAlarmSettings(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM))
        }
    }

    private fun pendingIntent(context: Context, taskId: String): PendingIntent {
        val intent = Intent(context, ScheduleAlarmReceiver::class.java).apply {
            putExtra(EXTRA_TASK_ID, taskId)
        }
        return PendingIntent.getBroadcast(
            context,
            taskId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun cancelOrphans(context: Context, activeIds: Set<String>) {
        // Best-effort: no persistent orphan list; alarms use task id hash.
    }
}
