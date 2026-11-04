package com.example.moe_social

import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/** 无障碍服务与 Flutter MethodChannel 之间的进程内桥。 */
object ReplyAssistBridge {
    const val CHANNEL = "com.moe_social/reply_assist"

    @Volatile
    var lastSnapshot: JSONObject = JSONObject()

    @Volatile
    var channel: MethodChannel? = null

    fun jsonToMap(json: JSONObject): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>()
        val keys = json.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            map[key] = jsonValue(json.get(key))
        }
        return map
    }

    private fun jsonValue(value: Any?): Any? {
        return when (value) {
            is JSONObject -> jsonToMap(value)
            is JSONArray -> {
                val list = mutableListOf<Any?>()
                for (i in 0 until value.length()) {
                    list.add(jsonValue(value.get(i)))
                }
                list
            }
            JSONObject.NULL -> null
            else -> value
        }
    }
}
