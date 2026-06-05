package com.moe.auto

import android.content.Context
import org.json.JSONObject
import java.io.File
import java.util.UUID

data class ScriptEntry(
    val id: String,
    val name: String,
    val description: String,
    val source: ScriptSource,
)

sealed class ScriptSource {
    data class Asset(val path: String) : ScriptSource()
    data class UserFile(val file: File) : ScriptSource()
}

class ScriptRepository(context: Context) {
    private val appContext = context.applicationContext
    private val userDir = File(appContext.filesDir, "user_scripts").apply { mkdirs() }
    private val templateDir = File(userDir, "templates").apply { mkdirs() }

    private val builtIn = listOf(
        ScriptEntry(
            id = "demo_tap_swipe",
            name = "示例：桌面滑动",
            description = "内置示例，可复制后修改",
            source = ScriptSource.Asset("scripts/demo_tap_swipe.json"),
        ),
        ScriptEntry(
            id = "open_settings",
            name = "示例：打开设置",
            description = "内置示例",
            source = ScriptSource.Asset("scripts/open_settings.json"),
        ),
    )

    fun listAll(): List<ScriptEntry> = builtIn + listUser()

    fun listUser(): List<ScriptEntry> {
        return userDir.listFiles { f -> f.extension == "json" }
            ?.sortedByDescending { it.lastModified() }
            ?.mapNotNull { file -> file.toEntry() }
            ?: emptyList()
    }

    fun readJson(source: ScriptSource): String {
        return when (source) {
            is ScriptSource.Asset ->
                appContext.assets.open(source.path).bufferedReader().use { it.readText() }
            is ScriptSource.UserFile ->
                source.file.readText()
        }
    }

    fun createNewScript(): File {
        val id = "script_${UUID.randomUUID().toString().take(8)}"
        val file = File(userDir, "$id.json")
        file.writeText(DEFAULT_SCRIPT_TEMPLATE)
        return file
    }

    fun saveNamedScript(name: String, json: String): File {
        val safe = name.replace(Regex("[^a-zA-Z0-9_\\-一-龥]"), "_").ifBlank { "script" }
        val file = File(userDir, "$safe.json")
        saveUserScript(file, json)
        return file
    }

    fun saveUserScript(file: File, json: String) {
        ScriptParser.parse(json)
        file.writeText(json)
    }

    fun deleteUserScript(file: File) {
        if (file.parentFile?.absolutePath == userDir.absolutePath) {
            file.delete()
        }
    }

    fun importJson(uri: android.net.Uri, displayName: String?): File {
        val id = displayName?.substringBeforeLast('.')?.ifBlank { null }
            ?: "import_${UUID.randomUUID().toString().take(8)}"
        val safeName = id.replace(Regex("[^a-zA-Z0-9_\\-一-龥]"), "_")
        val dest = File(userDir, "$safeName.json")
        appContext.contentResolver.openInputStream(uri)?.use { input ->
            dest.outputStream().use { output -> input.copyTo(output) }
        } ?: error("无法读取文件")
        ScriptParser.parse(dest.readText())
        return dest
    }

    fun resolveImagePath(relativeOrAbsolute: String): File? {
        val direct = File(relativeOrAbsolute)
        if (direct.isFile) return direct
        val inTemplates = File(templateDir, relativeOrAbsolute)
        if (inTemplates.isFile) return inTemplates
        val inUser = File(userDir, relativeOrAbsolute)
        if (inUser.isFile) return inUser
        return null
    }

    fun templatesDir(): File = templateDir

    fun userScriptsDirPath(): String = userDir.absolutePath

    fun listTemplates(): List<File> =
        templateDir.listFiles { f -> f.isFile && f.extension.lowercase() in setOf("png", "jpg", "jpeg", "webp") }
            ?.sortedByDescending { it.lastModified() }
            ?: emptyList()

    fun saveTemplatePng(name: String, bitmap: android.graphics.Bitmap): File {
        val safe = name.replace(Regex("[^a-zA-Z0-9_\\-一-龥]"), "_").ifBlank { "template" }
        val file = File(templateDir, "$safe.png")
        file.outputStream().use { out ->
            bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, out)
        }
        return file
    }

    fun importTemplate(uri: android.net.Uri, displayName: String?): File {
        val base = displayName?.substringBeforeLast('.')?.ifBlank { null } ?: "import_tpl"
        val safe = base.replace(Regex("[^a-zA-Z0-9_\\-一-龥]"), "_")
        val ext = displayName?.substringAfterLast('.', "png")?.lowercase() ?: "png"
        val dest = File(templateDir, "$safe.$ext")
        appContext.contentResolver.openInputStream(uri)?.use { input ->
            dest.outputStream().use { output -> input.copyTo(output) }
        } ?: error("无法读取图片")
        return dest
    }

    fun deleteTemplate(file: File) {
        if (file.parentFile?.absolutePath == templateDir.absolutePath) {
            file.delete()
        }
    }

    fun templateScriptPath(file: File): String = "templates/${file.name}"

    private fun File.toEntry(): ScriptEntry? {
        return try {
            val root = JSONObject(readText())
            ScriptEntry(
                id = root.optString("id", nameWithoutExtension),
                name = root.optString("name", nameWithoutExtension),
                description = root.optString("description", "自定义脚本"),
                source = ScriptSource.UserFile(this),
            )
        } catch (_: Exception) {
            null
        }
    }

    companion object {
        val DEFAULT_SCRIPT_TEMPLATE = """
            {
              "id": "my_script",
              "name": "我的脚本",
              "description": "自定义自动化任务",
              "version": 1,
              "loop": 1,
              "steps": [
                { "action": "log", "message": "开始执行" },
                { "action": "ocr_click", "text": "设置", "timeout_ms": 8000 },
                { "action": "wait", "ms": 1000 },
                { "action": "click_image", "image": "templates/button.png", "threshold": 0.82, "timeout_ms": 8000 }
              ]
            }
        """.trimIndent()
    }
}
