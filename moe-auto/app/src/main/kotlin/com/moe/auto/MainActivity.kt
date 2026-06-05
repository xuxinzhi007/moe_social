package com.moe.auto

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.moe.auto.ui.MainShell
import com.moe.auto.ui.MoeAutoTheme
import com.moe.auto.ui.AdvancedSettingsScreen
import com.moe.auto.ui.ScheduleListScreen
import com.moe.auto.ui.ScriptEditorScreen
import com.moe.auto.ui.ScriptVisualEditorScreen
import com.moe.auto.ui.ScriptWizardScreen
import com.moe.auto.ui.VisionLabScreen
import java.io.File

class MainActivity : ComponentActivity() {

    private lateinit var scriptRepository: ScriptRepository

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        scriptRepository = ScriptRepository(this)
        enableEdgeToEdge()

        setContent {
            val lifecycleOwner = LocalLifecycleOwner.current
            var refreshTick by mutableIntStateOf(0)
            var a11yEnabled by mutableStateOf(PermissionHelper.isAccessibilityEnabled(this))
            var overlayGranted by mutableStateOf(PermissionHelper.canDrawOverlays(this))
            var serviceConnected by mutableStateOf(PermissionHelper.isServiceConnected())
            val scripts = rememberScriptList(scriptRepository)
            val templates = rememberTemplateList(scriptRepository)
            var editorFile by mutableStateOf<File?>(null)
            var editorJsonMode by mutableStateOf(false)
            var showVisionLab by mutableStateOf(false)
            var showWizard by mutableStateOf(false)
            var showSchedules by mutableStateOf(false)
            var showAdvancedSettings by mutableStateOf(false)

            fun refreshPermissions() {
                a11yEnabled = PermissionHelper.isAccessibilityEnabled(this)
                overlayGranted = PermissionHelper.canDrawOverlays(this)
                serviceConnected = PermissionHelper.isServiceConnected()
            }

            DisposableEffect(lifecycleOwner) {
                val lifecycle = lifecycleOwner.lifecycle
                val observer = LifecycleEventObserver { _, event ->
                    if (event == Lifecycle.Event.ON_RESUME) {
                        refreshTick++
                        refreshPermissions()
                        reloadScripts(scripts, scriptRepository)
                    }
                }
                lifecycle.addObserver(observer)
                onDispose { lifecycle.removeObserver(observer) }
            }

            DisposableEffect(Unit) {
                val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
                val listener = AccessibilityManager.AccessibilityStateChangeListener {
                    refreshPermissions()
                }
                am.addAccessibilityStateChangeListener(listener)
                onDispose { am.removeAccessibilityStateChangeListener(listener) }
            }

            DisposableEffect(refreshTick) {
                refreshPermissions()
                onDispose { }
            }

            val importLauncher = rememberLauncherForActivityResult(
                ActivityResultContracts.OpenDocument(),
            ) { uri: Uri? ->
                if (uri == null) return@rememberLauncherForActivityResult
                try {
                    scriptRepository.importJson(uri, null)
                    reloadScripts(scripts, scriptRepository)
                } catch (e: Exception) {
                    AutoBridge.appendLog("导入失败: ${e.message}")
                }
            }

            val importTemplateLauncher = rememberLauncherForActivityResult(
                ActivityResultContracts.OpenDocument(),
            ) { uri: Uri? ->
                if (uri == null) return@rememberLauncherForActivityResult
                try {
                    scriptRepository.importTemplate(uri, null)
                    reloadTemplates(templates, scriptRepository)
                } catch (e: Exception) {
                    AutoBridge.appendLog("导入模板失败: ${e.message}")
                }
            }

            MoeAutoTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background,
                ) {
                    when {
                    showAdvancedSettings -> AdvancedSettingsScreen(
                        onBack = { showAdvancedSettings = false },
                    )
                    showSchedules -> ScheduleListScreen(
                        scripts = scripts,
                        onBack = { showSchedules = false },
                    )
                    showWizard -> ScriptWizardScreen(
                        context = this@MainActivity,
                        repository = scriptRepository,
                        serviceConnected = serviceConnected,
                        overlayGranted = overlayGranted,
                        onBack = { showWizard = false },
                        onSaved = {
                            showWizard = false
                            reloadScripts(scripts, scriptRepository)
                        },
                    )
                    showVisionLab -> VisionLabScreen(
                        repository = scriptRepository,
                        serviceConnected = serviceConnected,
                        onBack = { showVisionLab = false },
                        onImportImage = {
                            importTemplateLauncher.launch(arrayOf("image/*"))
                        },
                        onRefreshTemplates = { reloadTemplates(templates, scriptRepository) },
                        templates = templates,
                    )
                    editorFile != null && editorJsonMode -> ScriptEditorScreen(
                        file = editorFile!!,
                        repository = scriptRepository,
                        onBack = {
                            editorJsonMode = false
                        },
                    )
                    editorFile != null -> ScriptVisualEditorScreen(
                        file = editorFile!!,
                        repository = scriptRepository,
                        onBack = {
                            editorFile = null
                            editorJsonMode = false
                            reloadScripts(scripts, scriptRepository)
                        },
                        onOpenJsonEditor = { editorJsonMode = true },
                    )
                    else -> MainShell(
                            scripts = scripts,
                            a11yEnabled = a11yEnabled,
                            overlayGranted = overlayGranted,
                            serviceConnected = serviceConnected,
                            appVersion = "0.1.0",
                            scriptsDirHint = scriptRepository.userScriptsDirPath(),
                            onOpenAccessibilitySettings = { openAccessibilitySettings() },
                            onOpenOverlaySettings = { openOverlaySettings() },
                            onCreateScript = {
                                editorFile = scriptRepository.createNewScript()
                            },
                            onImportScript = {
                                importLauncher.launch(arrayOf("application/json", "text/*", "*/*"))
                            },
                            onEditScript = { entry ->
                                val file = (entry.source as? ScriptSource.UserFile)?.file
                                if (file != null) editorFile = file
                            },
                            onDeleteScript = { entry ->
                                val file = (entry.source as? ScriptSource.UserFile)?.file
                                if (file != null) {
                                    scriptRepository.deleteUserScript(file)
                                    reloadScripts(scripts, scriptRepository)
                                }
                            },
                            onRunScript = { entry ->
                                when (val src = entry.source) {
                                    is ScriptSource.Asset ->
                                        ScriptRunnerService.startAsset(this, src.path)
                                    is ScriptSource.UserFile ->
                                        ScriptRunnerService.startFile(this, src.file)
                                }
                            },
                            onStopScript = { ScriptRunnerService.requestStop(this) },
                            onOpenVisionLab = { showVisionLab = true },
                            onOpenWizard = { showWizard = true },
                            onOpenSchedules = { showSchedules = true },
                            onOpenAdvancedSettings = { showAdvancedSettings = true },
                        )
                    }
                }
            }
        }
    }

    private fun openAccessibilitySettings() {
        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
    }

    private fun openOverlaySettings() {
        startActivity(
            Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName"),
            ),
        )
    }
}

@androidx.compose.runtime.Composable
private fun rememberScriptList(repository: ScriptRepository): androidx.compose.runtime.snapshots.SnapshotStateList<ScriptEntry> {
    val list = mutableStateListOf<ScriptEntry>()
    androidx.compose.runtime.LaunchedEffect(Unit) {
        list.clear()
        list.addAll(repository.listAll())
    }
    return list
}

private fun reloadScripts(
    list: androidx.compose.runtime.snapshots.SnapshotStateList<ScriptEntry>,
    repository: ScriptRepository,
) {
    list.clear()
    list.addAll(repository.listAll())
}

@androidx.compose.runtime.Composable
private fun rememberTemplateList(repository: ScriptRepository): androidx.compose.runtime.snapshots.SnapshotStateList<File> {
    val list = mutableStateListOf<File>()
    androidx.compose.runtime.LaunchedEffect(Unit) {
        list.clear()
        list.addAll(repository.listTemplates())
    }
    return list
}

private fun reloadTemplates(
    list: androidx.compose.runtime.snapshots.SnapshotStateList<File>,
    repository: ScriptRepository,
) {
    list.clear()
    list.addAll(repository.listTemplates())
}
