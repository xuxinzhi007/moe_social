package com.moe.auto

import android.content.Context
import android.graphics.PixelFormat
import android.view.Gravity
import android.view.WindowManager
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.unit.dp
import com.moe.auto.ui.MoeAutoTheme
import com.moe.auto.ui.NormRect
import com.moe.auto.ui.TouchRectSelector
import com.moe.auto.ui.TouchSelectMode

object RegionPickerOverlay {
    private var composeView: ComposeView? = null

    fun show(
        context: Context,
        onConfirm: (NormRect) -> Unit,
        onCancel: () -> Unit,
    ) {
        if (!PermissionHelper.canDrawOverlays(context)) {
            onCancel()
            return
        }
        dismiss(context)
        val app = context.applicationContext
        val wm = app.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val dm = app.resources.displayMetrics

        val view = ComposeView(app).apply {
            setContent {
                var rect by remember { mutableStateOf(NormRect.smallCenter()) }
                MoeAutoTheme {
                    Surface(color = MaterialTheme.colorScheme.surface.copy(alpha = 0.01f)) {
                        Box(modifier = Modifier.fillMaxSize()) {
                            TouchRectSelector(
                                modifier = Modifier.fillMaxSize(),
                                imageWidth = dm.widthPixels,
                                imageHeight = dm.heightPixels,
                                rect = rect,
                                onRectChange = { rect = it },
                                mode = TouchSelectMode.CropRect,
                            )
                            Row(
                                modifier = Modifier
                                    .align(Alignment.BottomCenter)
                                    .padding(16.dp),
                            ) {
                                OutlinedButton(onClick = {
                                    dismiss(app)
                                    onCancel()
                                }) { Text("取消") }
                                Button(
                                    onClick = {
                                        val r = rect
                                        dismiss(app)
                                        onConfirm(r)
                                    },
                                    modifier = Modifier.padding(start = 8.dp),
                                ) { Text("确定") }
                            }
                        }
                    }
                }
            }
        }
        composeView = view
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }
        try {
            wm.addView(view, params)
        } catch (_: Exception) {
            onCancel()
        }
    }

    fun dismiss(context: Context) {
        val view = composeView ?: return
        val wm = context.applicationContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        try {
            wm.removeView(view)
        } catch (_: Exception) {
        }
        composeView = null
    }
}
