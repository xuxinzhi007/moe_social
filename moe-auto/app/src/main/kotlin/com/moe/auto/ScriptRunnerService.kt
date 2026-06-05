package com.moe.auto

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.io.File

class ScriptRunnerService : Service() {

    companion object {
        private const val CHANNEL_ID = "moe_auto_runner"
        private const val NOTIFICATION_ID = 1001
        const val ACTION_STOP = "com.moe.auto.action.STOP_SCRIPT"
        const val EXTRA_ASSET_SCRIPT = "asset_script"
        const val EXTRA_FILE_SCRIPT = "file_script"

        @Volatile
        private var runningJob: Job? = null

        @Volatile
        private var executor: ScriptExecutor? = null

        fun startAsset(context: Context, assetScriptPath: String) {
            val intent = Intent(context, ScriptRunnerService::class.java).apply {
                putExtra(EXTRA_ASSET_SCRIPT, assetScriptPath)
            }
            startRunner(context, intent)
        }

        fun startFile(context: Context, scriptFile: File) {
            val intent = Intent(context, ScriptRunnerService::class.java).apply {
                putExtra(EXTRA_FILE_SCRIPT, scriptFile.absolutePath)
            }
            startRunner(context, intent)
        }

        private fun startRunner(context: Context, intent: Intent) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun requestStop(context: Context) {
            executor?.stopRequested = true
            runningJob?.cancel()
            context.stopService(Intent(context, ScriptRunnerService::class.java))
        }
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val scriptRepo by lazy { ScriptRepository(this) }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            requestStop(this)
            return START_NOT_STICKY
        }

        val jsonLoader: (() -> String)? = when {
            !intent?.getStringExtra(EXTRA_ASSET_SCRIPT).isNullOrBlank() -> {
                val path = intent?.getStringExtra(EXTRA_ASSET_SCRIPT) ?: ""
                { scriptRepo.readJson(ScriptSource.Asset(path)) }
            }
            !intent?.getStringExtra(EXTRA_FILE_SCRIPT).isNullOrBlank() -> {
                val path = intent?.getStringExtra(EXTRA_FILE_SCRIPT) ?: ""
                { File(path).readText() }
            }
            else -> null
        }

        if (jsonLoader == null) {
            stopSelf()
            return START_NOT_STICKY
        }

        val service = AutoBridge.accessibilityService
        if (service == null) {
            AutoBridge.appendLog("请先开启无障碍服务")
            stopSelf()
            return START_NOT_STICKY
        }

        createChannel()
        val nm = getSystemService(NotificationManager::class.java)
        AutoBridge.onNotificationUpdate = { text ->
            nm.notify(NOTIFICATION_ID, buildNotification(text))
        }
        AutoBridge.onOverlayStatusUpdate = { text ->
            ExecutionOverlayManager.updateControlStatus(text)
        }
        ExecutionOverlayManager.showControlConsole(this)
        startForeground(NOTIFICATION_ID, buildNotification("脚本运行中"))

        runningJob?.cancel()
        AutoBridge.setRunning(true)

        runningJob = scope.launch {
            try {
                val script = ScriptParser.parse(jsonLoader())
                val exec = ScriptExecutor(service, scriptRepo)
                executor = exec
                exec.run(script)
            } catch (e: Exception) {
                AutoBridge.appendLog("运行异常: ${e.message}")
            } finally {
                executor = null
                AutoBridge.onNotificationUpdate = null
                AutoBridge.onOverlayStatusUpdate = null
                ExecutionOverlayManager.hideStatus()
                AutoBridge.setRunning(false)
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }

        return START_NOT_STICKY
    }

    override fun onDestroy() {
        scope.cancel()
        AutoBridge.onOverlayStatusUpdate = null
        ExecutionOverlayManager.hideStatus()
        AutoBridge.setRunning(false)
        super.onDestroy()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Moe Auto",
                NotificationManager.IMPORTANCE_LOW,
            )
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun buildNotification(content: String): Notification {
        val stopIntent = Intent(this, ScriptRunnerService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPending = PendingIntent.getService(
            this,
            0,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val openIntent = PendingIntent.getActivity(
            this,
            1,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Moe Auto")
            .setContentText(content)
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setContentIntent(openIntent)
            .addAction(android.R.drawable.ic_media_pause, "停止", stopPending)
            .setOngoing(true)
            .build()
    }
}
