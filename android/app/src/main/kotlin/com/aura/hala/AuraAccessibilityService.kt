package com.aura.hala

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.util.Log

/**
 * Auto-accepts the Android "Screen pinned" dialog silently.
 * Detects the dialog by its OK button and auto-clicks it immediately.
 */
class AuraAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "AuraA11y"
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val root = rootInActiveWindow ?: return
        try {
            autoClickOk(root)
        } catch (_: Exception) {
        } finally {
            root.recycle()
        }
    }

    private fun autoClickOk(root: AccessibilityNodeInfo) {
        // The screen pinning dialog has "Screen pinned" text — verify before clicking
        val screenPinnedNodes = root.findAccessibilityNodeInfosByText("Screen pinned")
        val isScreenPinningDialog = screenPinnedNodes.isNotEmpty()
        screenPinnedNodes.forEach { it.recycle() }

        if (!isScreenPinningDialog) return

        // Find and click the OK button
        listOf("OK", "Ok", "ok").forEach { label ->
            val nodes = root.findAccessibilityNodeInfosByText(label)
            for (node in nodes) {
                try {
                    if (node.isClickable) {
                        node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                        Log.d(TAG, "[A11Y] Auto-accepted screen pinning dialog")
                        return
                    }
                    val parent = node.parent
                    if (parent != null && parent.isClickable) {
                        parent.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                        parent.recycle()
                        Log.d(TAG, "[A11Y] Auto-accepted via parent")
                        return
                    }
                } finally {
                    node.recycle()
                }
            }
        }
    }

    override fun onInterrupt() {}
}
