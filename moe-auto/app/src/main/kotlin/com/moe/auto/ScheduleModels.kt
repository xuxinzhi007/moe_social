package com.moe.auto

import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.UUID

enum class ScheduleRepeat {
    DAILY,
    WEEKLY,
    ONCE,
}

data class ScheduledTask(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val enabled: Boolean = true,
    val scriptSourceType: String,
    val scriptRef: String,
    val scriptDisplayName: String,
    val hour: Int,
    val minute: Int,
    val repeat: ScheduleRepeat,
    val weekDays: List<Int> = emptyList(),
    val nextRunAtMs: Long = 0L,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("id", id)
        .put("name", name)
        .put("enabled", enabled)
        .put("script_source_type", scriptSourceType)
        .put("script_ref", scriptRef)
        .put("script_display_name", scriptDisplayName)
        .put("hour", hour)
        .put("minute", minute)
        .put("repeat", repeat.name)
        .put("week_days", JSONArray(weekDays))
        .put("next_run_at_ms", nextRunAtMs)

    companion object {
        fun fromJson(obj: JSONObject): ScheduledTask {
            val days = mutableListOf<Int>()
            val arr = obj.optJSONArray("week_days")
            if (arr != null) {
                for (i in 0 until arr.length()) {
                    days.add(arr.getInt(i))
                }
            }
            return ScheduledTask(
                id = obj.getString("id"),
                name = obj.getString("name"),
                enabled = obj.optBoolean("enabled", true),
                scriptSourceType = obj.getString("script_source_type"),
                scriptRef = obj.getString("script_ref"),
                scriptDisplayName = obj.optString("script_display_name", obj.getString("name")),
                hour = obj.getInt("hour"),
                minute = obj.getInt("minute"),
                repeat = ScheduleRepeat.valueOf(obj.getString("repeat")),
                weekDays = days,
                nextRunAtMs = obj.optLong("next_run_at_ms", 0L),
            )
        }
    }
}

object ScheduleTimeCalculator {
    fun computeNextRunMs(task: ScheduledTask, afterMs: Long = System.currentTimeMillis()): Long {
        val cal = Calendar.getInstance().apply { timeInMillis = afterMs }
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)

        return when (task.repeat) {
            ScheduleRepeat.DAILY -> nextDaily(cal, task.hour, task.minute, afterMs)
            ScheduleRepeat.WEEKLY -> nextWeekly(cal, task.hour, task.minute, task.weekDays, afterMs)
            ScheduleRepeat.ONCE -> nextDaily(cal, task.hour, task.minute, afterMs)
        }
    }

    private fun nextDaily(cal: Calendar, hour: Int, minute: Int, afterMs: Long): Long {
        cal.set(Calendar.HOUR_OF_DAY, hour)
        cal.set(Calendar.MINUTE, minute)
        if (cal.timeInMillis <= afterMs) {
            cal.add(Calendar.DAY_OF_YEAR, 1)
        }
        return cal.timeInMillis
    }

    private fun nextWeekly(
        cal: Calendar,
        hour: Int,
        minute: Int,
        weekDays: List<Int>,
        afterMs: Long,
    ): Long {
        val days = weekDays.ifEmpty { listOf(Calendar.MONDAY) }
        var best = Long.MAX_VALUE
        val base = Calendar.getInstance().apply { timeInMillis = afterMs }
        for (day in days) {
            val c = base.clone() as Calendar
            c.set(Calendar.HOUR_OF_DAY, hour)
            c.set(Calendar.MINUTE, minute)
            c.set(Calendar.SECOND, 0)
            c.set(Calendar.MILLISECOND, 0)
            val currentDow = c.get(Calendar.DAY_OF_WEEK)
            var delta = day - currentDow
            if (delta < 0) delta += 7
            if (delta == 0 && c.timeInMillis <= afterMs) delta = 7
            c.add(Calendar.DAY_OF_YEAR, delta)
            if (c.timeInMillis < best) best = c.timeInMillis
        }
        return best
    }

    fun formatNextRun(ms: Long): String {
        if (ms <= 0L) return "未排程"
        val cal = Calendar.getInstance().apply { timeInMillis = ms }
        return "%d/%d %02d:%02d".format(
            cal.get(Calendar.MONTH) + 1,
            cal.get(Calendar.DAY_OF_MONTH),
            cal.get(Calendar.HOUR_OF_DAY),
            cal.get(Calendar.MINUTE),
        )
    }
}
