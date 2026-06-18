package com.example.alter

import android.Manifest
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingPermissionKey: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, WAKE_SERVICE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startWakeService" -> {
                    val missingPermissionMessage = requestWakePermissionsIfNeeded()
                    if (missingPermissionMessage != null) {
                        result.error("permissions_required", missingPermissionMessage, null)
                        return@setMethodCallHandler
                    }

                    val intent = Intent(this, HeyAlterWakeService::class.java)
                        .setAction(HeyAlterWakeService.ACTION_START)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }

                "stopWakeService" -> {
                    stopService(
                        Intent(this, HeyAlterWakeService::class.java)
                            .setAction(HeyAlterWakeService.ACTION_STOP),
                    )
                    result.success(true)
                }

                "isOnDeviceWakeAvailable" -> {
                    val available = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                        android.speech.SpeechRecognizer.isOnDeviceRecognitionAvailable(this)
                    result.success(available)
                }

                "isSpeechRecognitionAvailable" -> {
                    result.success(android.speech.SpeechRecognizer.isRecognitionAvailable(this))
                }

                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, WAKE_EVENTS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    HeyAlterWakeEvents.attach(events)
                }

                override fun onCancel(arguments: Any?) {
                    HeyAlterWakeEvents.detach()
                }
            },
        )

        MethodChannel(messenger, DEVICE_CONTROL_CHANNEL).setMethodCallHandler { call, result ->
            DeviceControlBridge.handle(this, call, result)
        }

        MethodChannel(messenger, AUDIO_CAPTURE_CHANNEL).setMethodCallHandler { call, result ->
            NativeAudioBridge.handle(this, call, result)
        }

        MethodChannel(messenger, NFC_HCE_CHANNEL).setMethodCallHandler { call, result ->
            AlterHceBridge.handle(this, call, result)
        }

        MethodChannel(messenger, CALENDAR_CHANNEL).setMethodCallHandler { call, result ->
            CalendarReader.handle(this, call, result)
        }

        MethodChannel(messenger, BUBBLE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isOverlayGranted" -> result.success(Settings.canDrawOverlays(this))
                "isRunning" -> result.success(AlterBubbleService.active)
                "requestOverlay" -> {
                    try {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName"),
                            ),
                        )
                    } catch (_: Throwable) {
                    }
                    result.success(Settings.canDrawOverlays(this))
                }
                "start" -> {
                    if (!Settings.canDrawOverlays(this)) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val intent = Intent(this, AlterBubbleService::class.java)
                        .setAction(AlterBubbleService.ACTION_START)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stop" -> {
                    startService(
                        Intent(this, AlterBubbleService::class.java)
                            .setAction(AlterBubbleService.ACTION_STOP),
                    )
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, PERMISSIONS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPermissionStatuses" -> result.success(permissionStatuses())
                "requestPermission" -> requestHubPermission(
                    call.argument<String>("permission").orEmpty(),
                    result,
                )
                "openAppSettings" -> {
                    openAppSettings()
                    result.success(permissionStatuses())
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, DEVICE_OWNER_CHANNEL).setMethodCallHandler { call, result ->
            DeviceOwnerBridge.handle(this, call, result)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != HUB_PERMISSION_REQUEST) return
        val result = pendingPermissionResult
        pendingPermissionResult = null
        pendingPermissionKey = null
        result?.success(permissionStatuses())
    }

    private fun requestWakePermissionsIfNeeded(): String? {
        val permissions = mutableListOf<String>()
        if (!hasPermission(Manifest.permission.RECORD_AUDIO)) {
            permissions += Manifest.permission.RECORD_AUDIO
        }
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            !hasPermission(Manifest.permission.POST_NOTIFICATIONS)
        ) {
            permissions += Manifest.permission.POST_NOTIFICATIONS
        }

        if (permissions.isEmpty()) return null
        requestPermissions(permissions.toTypedArray(), WAKE_PERMISSION_REQUEST)
        return "Approve microphone permission, then start Hey Alter again."
    }

    private fun hasPermission(permission: String): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestHubPermission(
        key: String,
        result: MethodChannel.Result,
    ) {
        when (key) {
            "device_admin" -> {
                DeviceOwnerBridge.requestDeviceAdminSetup(this)
                result.success(permissionStatuses())
            }
            "accessibility" -> {
                startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                result.success(permissionStatuses())
            }
            "notification_listener" -> {
                startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                result.success(permissionStatuses())
            }
            "device_admin" -> {
                openDeviceAdminActivation()
                result.success(permissionStatuses())
            }
            "notifications" -> {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                    result.success(permissionStatuses())
                    return
                }
                requestRuntimePermission(key, result)
            }
            else -> {
                requestRuntimePermission(key, result)
            }
        }
    }

    private fun requestRuntimePermission(
        key: String,
        result: MethodChannel.Result,
    ) {
        val androidPermission = androidPermissionFor(key)
        if (androidPermission == null) {
            result.error("unknown_permission", "Unknown permission: $key", null)
            return
        }
        if (hasPermission(androidPermission)) {
            result.success(permissionStatuses())
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            result.success(permissionStatuses())
            return
        }
        if (pendingPermissionResult != null) {
            result.error("permission_request_active", "Another permission request is active.", null)
            return
        }
        pendingPermissionResult = result
        pendingPermissionKey = key
        requestPermissions(arrayOf(androidPermission), HUB_PERMISSION_REQUEST)
    }

    private fun permissionStatuses(): Map<String, Any?> {
        return mapOf(
            "device_admin" to permissionStatus(
                granted = DeviceOwnerBridge.isDeviceAdminActive(this),
                systemManaged = true,
            ),
            "microphone" to permissionStatus(
                granted = hasPermission(Manifest.permission.RECORD_AUDIO),
                systemManaged = false,
            ),
            "notifications" to permissionStatus(
                granted = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                    hasPermission(Manifest.permission.POST_NOTIFICATIONS),
                systemManaged = false,
            ),
            "camera" to permissionStatus(
                granted = hasPermission(Manifest.permission.CAMERA),
                systemManaged = false,
            ),
            "contacts" to permissionStatus(
                granted = hasPermission(Manifest.permission.READ_CONTACTS),
                systemManaged = false,
            ),
            "accessibility" to permissionStatus(
                granted = isAlterAccessibilityEnabled(),
                systemManaged = true,
            ),
            "notification_listener" to permissionStatus(
                granted = isNotificationListenerEnabled(),
                systemManaged = true,
            ),
            "device_admin" to permissionStatus(
                granted = isDeviceAdminEnabled(),
                systemManaged = true,
            ),
        )
    }

    private fun permissionStatus(
        granted: Boolean,
        systemManaged: Boolean,
    ): Map<String, Any?> {
        return mapOf(
            "granted" to granted,
            "systemManaged" to systemManaged,
        )
    }

    private fun androidPermissionFor(key: String): String? {
        return when (key) {
            "microphone" -> Manifest.permission.RECORD_AUDIO
            "notifications" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                Manifest.permission.POST_NOTIFICATIONS
            } else {
                null
            }
            "camera" -> Manifest.permission.CAMERA
            "contacts" -> Manifest.permission.READ_CONTACTS
            else -> null
        }
    }

    private fun isAlterAccessibilityEnabled(): Boolean {
        val enabled = Settings.Secure.getInt(
            contentResolver,
            Settings.Secure.ACCESSIBILITY_ENABLED,
            0,
        ) == 1
        if (!enabled) return false
        val expected = ComponentName(this, AlterAccessibilityService::class.java).flattenToString()
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ).orEmpty()
        return enabledServices.split(':').any { service ->
            service.equals(expected, ignoreCase = true)
        }
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val enabledListeners = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners",
        ).orEmpty()
        return enabledListeners.split(':').any { listener ->
            listener.contains(packageName, ignoreCase = true)
        }
    }

    private fun isDeviceAdminEnabled(): Boolean {
        val manager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        return manager.isAdminActive(deviceAdminComponent()) ||
            manager.isDeviceOwnerApp(packageName)
    }

    private fun openDeviceAdminActivation() {
        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
            .putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, deviceAdminComponent())
            .putExtra(
                DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                "Enable ALTER as a managed-device admin for explicit test and control workflows.",
            )
        startActivity(intent)
    }

    private fun deviceAdminComponent(): ComponentName {
        return ComponentName(this, AlterDeviceAdminReceiver::class.java)
    }

    private fun openAppSettings() {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.parse("package:$packageName"),
        )
        startActivity(intent)
    }

    companion object {
        private const val WAKE_SERVICE_CHANNEL = "alter.ai/wake_service"
        private const val WAKE_EVENTS_CHANNEL = "alter.ai/wake_events"
        private const val DEVICE_CONTROL_CHANNEL = "alter.ai/device_control"
        private const val AUDIO_CAPTURE_CHANNEL = "alter.ai/audio_capture"
        private const val NFC_HCE_CHANNEL = "alter.ai/nfc_hce"
        private const val CALENDAR_CHANNEL = "alter.ai/calendar"
        private const val BUBBLE_CHANNEL = "alter.ai/bubble"
        private const val PERMISSIONS_CHANNEL = "alter.ai/permissions"
        private const val DEVICE_OWNER_CHANNEL = "alter.ai/device_owner"
        private const val WAKE_PERMISSION_REQUEST = 9124
        private const val HUB_PERMISSION_REQUEST = 9125
    }
}
