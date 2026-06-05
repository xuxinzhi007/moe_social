package com.moe.auto

import android.view.accessibility.AccessibilityNodeInfo

object UiFinder {
    fun findByText(root: AccessibilityNodeInfo, text: String): AccessibilityNodeInfo? {
        val nodeText = root.text?.toString()
        if (nodeText != null && nodeText.contains(text, ignoreCase = true)) {
            return root
        }
        val desc = root.contentDescription?.toString()
        if (desc != null && desc.contains(text, ignoreCase = true)) {
            return root
        }
        for (i in 0 until root.childCount) {
            val child = root.getChild(i) ?: continue
            val found = findByText(child, text)
            if (found != null) {
                if (found !== child) {
                    child.recycle()
                }
                return found
            }
            child.recycle()
        }
        return null
    }

    fun findEditable(root: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (root.isEditable || root.className?.toString()?.contains("EditText") == true) {
            return root
        }
        for (i in 0 until root.childCount) {
            val child = root.getChild(i) ?: continue
            val found = findEditable(child)
            if (found != null) {
                if (found !== child) {
                    child.recycle()
                }
                return found
            }
            child.recycle()
        }
        return null
    }

    fun containsText(root: AccessibilityNodeInfo, text: String): Boolean {
        return findByText(root, text) != null
    }
}
