package com.example.alter

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.graphics.Rect
import android.os.Bundle
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class AlterAccessibilityService : AccessibilityService() {
    override fun onServiceConnected() {
        super.onServiceConnected()
        activeService = this
    }

    override fun onDestroy() {
        if (activeService == this) activeService = null
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) = Unit

    override fun onInterrupt() = Unit

    companion object {
        private var activeService: AlterAccessibilityService? = null

        fun isEnabled(): Boolean = activeService != null

        fun globalAction(name: String): Boolean {
            val service = activeService ?: return false
            val action = when (name.lowercase()) {
                "back" -> GLOBAL_ACTION_BACK
                "home" -> GLOBAL_ACTION_HOME
                "recents" -> GLOBAL_ACTION_RECENTS
                "notifications" -> GLOBAL_ACTION_NOTIFICATIONS
                "quick_settings" -> GLOBAL_ACTION_QUICK_SETTINGS
                else -> return false
            }
            return service.performGlobalAction(action)
        }

        fun tap(x: Float, y: Float): Boolean {
            val path = Path().apply { moveTo(x, y) }
            return dispatch(path, 0L, 80L)
        }

        fun swipe(
            startX: Float,
            startY: Float,
            endX: Float,
            endY: Float,
            durationMs: Long,
        ): Boolean {
            val path = Path().apply {
                moveTo(startX, startY)
                lineTo(endX, endY)
            }
            return dispatch(path, 0L, durationMs.coerceAtLeast(120L))
        }

        fun clickText(query: String): Boolean {
            val service = activeService ?: return false
            val root = service.rootInActiveWindow ?: return false
            val target = findNode(root) { node ->
                val text = node.text?.toString().orEmpty()
                val desc = node.contentDescription?.toString().orEmpty()
                text.contains(query, ignoreCase = true) ||
                    desc.contains(query, ignoreCase = true)
            } ?: return false
            return performClick(target)
        }

        fun typeText(text: String): Boolean {
            val service = activeService ?: return false
            val root = service.rootInActiveWindow ?: return false
            val focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
            val target = focused ?: findNode(root) { it.isEditable }
            if (target != null) {
                val args = Bundle().apply {
                    putCharSequence(
                        AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                        text,
                    )
                }
                if (target.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)) {
                    return true
                }
            }
            return false
        }

        fun scroll(direction: String): Boolean {
            val service = activeService ?: return false
            val root = service.rootInActiveWindow ?: return false
            val scrollable = findNode(root) { it.isScrollable } ?: root
            val action = when (direction.lowercase()) {
                "backward", "up", "left" -> AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
                else -> AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
            }
            return scrollable.performAction(action)
        }

        fun readScreen(): Map<String, Any?> {
            val service = activeService
            val root = service?.rootInActiveWindow
            if (service == null || root == null) {
                return mapOf(
                    "ok" to false,
                    "message" to "Accessibility service is not enabled.",
                    "nodes" to emptyList<Map<String, Any?>>(),
                    "text" to "",
                )
            }

            val nodes = mutableListOf<Map<String, Any?>>()
            collectNodes(root, nodes, maxNodes = 80)
            val text = nodes.joinToString("\n") { it["text"].toString() }
            return mapOf(
                "ok" to true,
                "message" to "Read ${nodes.size} visible nodes.",
                "packageName" to root.packageName?.toString().orEmpty(),
                "className" to root.className?.toString().orEmpty(),
                "nodes" to nodes,
                "text" to text,
            )
        }

        private fun dispatch(path: Path, startTimeMs: Long, durationMs: Long): Boolean {
            val service = activeService ?: return false
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, startTimeMs, durationMs))
                .build()
            return service.dispatchGesture(gesture, null, null)
        }

        private fun performClick(node: AccessibilityNodeInfo): Boolean {
            var current: AccessibilityNodeInfo? = node
            while (current != null) {
                if (current.isClickable &&
                    current.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                ) {
                    return true
                }
                current = current.parent
            }
            val bounds = Rect()
            node.getBoundsInScreen(bounds)
            return if (!bounds.isEmpty) tap(bounds.exactCenterX(), bounds.exactCenterY()) else false
        }

        private fun findNode(
            node: AccessibilityNodeInfo,
            predicate: (AccessibilityNodeInfo) -> Boolean,
        ): AccessibilityNodeInfo? {
            if (node.isVisibleToUser && predicate(node)) return node
            for (index in 0 until node.childCount) {
                val child = node.getChild(index) ?: continue
                val found = findNode(child, predicate)
                if (found != null) return found
            }
            return null
        }

        private fun collectNodes(
            node: AccessibilityNodeInfo,
            output: MutableList<Map<String, Any?>>,
            maxNodes: Int,
        ) {
            if (output.size >= maxNodes) return
            if (node.isVisibleToUser) {
                val text = node.text?.toString()?.trim().orEmpty()
                val desc = node.contentDescription?.toString()?.trim().orEmpty()
                val label = when {
                    text.isNotEmpty() && desc.isNotEmpty() -> "$text $desc"
                    text.isNotEmpty() -> text
                    else -> desc
                }.trim()

                if (label.isNotEmpty()) {
                    val bounds = Rect()
                    node.getBoundsInScreen(bounds)
                    output += mapOf(
                        "nodeId" to output.size,
                        "text" to label,
                        "className" to node.className?.toString().orEmpty(),
                        "viewId" to node.viewIdResourceName.orEmpty(),
                        "clickable" to node.isClickable,
                        "editable" to node.isEditable,
                        "scrollable" to node.isScrollable,
                        "bounds" to mapOf(
                            "left" to bounds.left,
                            "top" to bounds.top,
                            "right" to bounds.right,
                            "bottom" to bounds.bottom,
                        ),
                    )
                }
            }

            for (index in 0 until node.childCount) {
                val child = node.getChild(index) ?: continue
                collectNodes(child, output, maxNodes)
                if (output.size >= maxNodes) return
            }
        }
    }
}
