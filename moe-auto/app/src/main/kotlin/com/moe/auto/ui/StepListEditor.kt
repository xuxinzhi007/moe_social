package com.moe.auto.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ArrowDownward
import androidx.compose.material.icons.rounded.ArrowUpward
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.moe.auto.ScriptStep
import com.moe.auto.stepLabel

@Composable
fun StepListEditor(
    steps: List<ScriptStep>,
    onMoveUp: (Int) -> Unit,
    onMoveDown: (Int) -> Unit,
    onDelete: (Int) -> Unit,
    onEdit: ((Int) -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        if (steps.isEmpty()) {
            Text(
                "暂无步骤。在下方添加操作。",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            return
        }
        steps.forEachIndexed { index, step ->
            StepListRow(
                index = index,
                total = steps.size,
                label = stepLabel(step),
                onMoveUp = { onMoveUp(index) },
                onMoveDown = { onMoveDown(index) },
                onDelete = { onDelete(index) },
                onEdit = onEdit?.let { { it(index) } },
            )
        }
    }
}

@Composable
private fun StepListRow(
    index: Int,
    total: Int,
    label: String,
    onMoveUp: () -> Unit,
    onMoveDown: () -> Unit,
    onDelete: () -> Unit,
    onEdit: (() -> Unit)?,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "${index + 1}",
                modifier = Modifier.padding(horizontal = 8.dp),
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary,
            )
            Text(
                text = label,
                modifier = Modifier.weight(1f),
                style = MaterialTheme.typography.bodyMedium,
            )
            if (onEdit != null) {
                IconButton(onClick = onEdit) {
                    Icon(Icons.Rounded.Edit, contentDescription = "编辑")
                }
            }
            IconButton(onClick = onMoveUp, enabled = index > 0) {
                Icon(Icons.Rounded.ArrowUpward, contentDescription = "上移")
            }
            IconButton(onClick = onMoveDown, enabled = index < total - 1) {
                Icon(Icons.Rounded.ArrowDownward, contentDescription = "下移")
            }
            IconButton(onClick = onDelete) {
                Icon(Icons.Rounded.Delete, contentDescription = "删除")
            }
        }
    }
}

fun swapSteps(steps: MutableList<ScriptStep>, from: Int, to: Int) {
    if (from !in steps.indices || to !in steps.indices || from == to) return
    val item = steps.removeAt(from)
    steps.add(to, item)
}
