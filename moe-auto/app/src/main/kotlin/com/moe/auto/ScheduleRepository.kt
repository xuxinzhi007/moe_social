package com.moe.auto

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

class ScheduleRepository(context: Context) {
    private val file = File(context.applicationContext.filesDir, "schedules.json")

    fun listAll(): List<ScheduledTask> {
        if (!file.exists()) return emptyList()
        return try {
            val arr = JSONArray(file.readText())
            (0 until arr.length()).map { ScheduledTask.fromJson(arr.getJSONObject(it)) }
        } catch (_: Exception) {
            emptyList()
        }
    }

    fun saveAll(tasks: List<ScheduledTask>) {
        val arr = JSONArray()
        tasks.forEach { arr.put(it.toJson()) }
        file.writeText(arr.toString(2))
    }

    fun upsert(task: ScheduledTask) {
        val list = listAll().toMutableList()
        val idx = list.indexOfFirst { it.id == task.id }
        if (idx >= 0) list[idx] = task else list.add(task)
        saveAll(list)
    }

    fun delete(id: String) {
        saveAll(listAll().filter { it.id != id })
    }

    fun findById(id: String): ScheduledTask? = listAll().find { it.id == id }

    fun toggleEnabled(id: String, enabled: Boolean) {
        val task = findById(id) ?: return
        upsert(task.copy(enabled = enabled))
    }
}
