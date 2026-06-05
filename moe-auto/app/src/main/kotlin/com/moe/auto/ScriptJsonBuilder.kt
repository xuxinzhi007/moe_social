package com.moe.auto

import com.moe.auto.ui.stepToJson
import org.json.JSONArray
import org.json.JSONObject

object ScriptJsonBuilder {
    fun build(
        id: String,
        name: String,
        description: String,
        steps: List<ScriptStep>,
        loop: Int = 1,
    ): String {
        val arr = JSONArray()
        steps.forEach { arr.put(stepToJson(it)) }
        return JSONObject()
            .put("id", id)
            .put("name", name)
            .put("description", description)
            .put("version", 1)
            .put("loop", loop)
            .put("steps", arr)
            .toString(2)
    }
}
