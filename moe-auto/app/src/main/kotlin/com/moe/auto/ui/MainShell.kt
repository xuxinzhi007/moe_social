package com.moe.auto.ui

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.moe.auto.ScriptEntry

@Composable
fun MainShell(
    scripts: List<ScriptEntry>,
    a11yEnabled: Boolean,
    overlayGranted: Boolean,
    serviceConnected: Boolean,
    appVersion: String,
    scriptsDirHint: String,
    onOpenAccessibilitySettings: () -> Unit,
    onOpenOverlaySettings: () -> Unit,
    onCreateScript: () -> Unit,
    onImportScript: () -> Unit,
    onEditScript: (ScriptEntry) -> Unit,
    onDeleteScript: (ScriptEntry) -> Unit,
    onRunScript: (ScriptEntry) -> Unit,
    onStopScript: () -> Unit,
    onOpenVisionLab: () -> Unit,
    onOpenWizard: () -> Unit,
    onOpenSchedules: () -> Unit,
    onOpenAdvancedSettings: () -> Unit,
) {
    var selectedTab by rememberSaveable { mutableStateOf(AppTab.Scripts) }

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        containerColor = MaterialTheme.colorScheme.background,
        bottomBar = {
            NavigationBar {
                AppTab.entries.forEach { tab ->
                    NavigationBarItem(
                        selected = selectedTab == tab,
                        onClick = { selectedTab = tab },
                        icon = { Icon(tab.icon, contentDescription = tab.label) },
                        label = { Text(tab.label) },
                    )
                }
            }
        },
    ) { padding ->
        when (selectedTab) {
            AppTab.Scripts -> ScriptsTabScreen(
                modifier = Modifier.padding(padding),
                scripts = scripts,
                a11yEnabled = a11yEnabled,
                onCreateScript = onCreateScript,
                onImportScript = onImportScript,
                onEditScript = onEditScript,
                onDeleteScript = onDeleteScript,
                onRunScript = {
                    onRunScript(it)
                    selectedTab = AppTab.Run
                },
                onOpenWizard = onOpenWizard,
                onOpenSchedules = onOpenSchedules,
            )
            AppTab.Run -> RunTabScreen(
                modifier = Modifier.padding(padding),
                onStopScript = onStopScript,
            )
            AppTab.Profile -> ProfileTabScreen(
                modifier = Modifier.padding(padding),
                a11yEnabled = a11yEnabled,
                overlayGranted = overlayGranted,
                serviceConnected = serviceConnected,
                appVersion = appVersion,
                scriptsDirHint = scriptsDirHint,
                onOpenAccessibilitySettings = onOpenAccessibilitySettings,
                onOpenOverlaySettings = onOpenOverlaySettings,
                onOpenVisionLab = onOpenVisionLab,
                onOpenAdvancedSettings = onOpenAdvancedSettings,
            )
        }
    }
}
