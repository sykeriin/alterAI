package com.example.alter

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

object DeviceControlBridge {
    fun handle(activity: Activity, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAccessibilityEnabled" -> result.success(AlterAccessibilityService.isEnabled())
            "openAccessibilitySettings" -> result.success(
                openSettingsIntent(activity, Settings.ACTION_ACCESSIBILITY_SETTINGS),
            )
            "openApp" -> result.success(openApp(activity, call))
            "openSettings" -> result.success(openSettings(activity, call.stringArg("screen")))
            "openDialer" -> result.success(openDialer(activity, call.stringArg("number")))
            "openBrowserSearch" -> result.success(openBrowserSearch(activity, call.stringArg("query")))
            "openSmsDraft" -> result.success(
                openSmsDraft(
                    activity,
                    call.stringArg("number"),
                    call.stringArg("text"),
                ),
            )
            "getDeviceAdminStatus" -> result.success(deviceAdminStatus(activity))
            "openDeviceAdmin" -> result.success(openDeviceAdminActivation(activity))
            "lockDevice" -> result.success(lockDevice(activity))
            "executeAccessibilityAction" -> result.success(executeAccessibilityAction(call))
            "readScreen" -> result.success(AlterAccessibilityService.readScreen())
            else -> result.notImplemented()
        }
    }

    private fun executeAccessibilityAction(call: MethodCall): Map<String, Any?> {
        if (!AlterAccessibilityService.isEnabled()) {
            return failure("Accessibility is not enabled. Open Android Accessibility settings first.")
        }

        val action = call.stringArg("action")
        val ok = when (action) {
            "back", "home", "recents", "notifications", "quick_settings" ->
                AlterAccessibilityService.globalAction(action)
            "tap" -> AlterAccessibilityService.tap(call.floatArg("x"), call.floatArg("y"))
            "swipe" -> AlterAccessibilityService.swipe(
                call.floatArg("startX"),
                call.floatArg("startY"),
                call.floatArg("endX"),
                call.floatArg("endY"),
                call.longArg("durationMs", 420L),
            )
            "click_text" -> AlterAccessibilityService.clickText(call.stringArg("text"))
            "type_text" -> AlterAccessibilityService.typeText(call.stringArg("text"))
            "scroll" -> AlterAccessibilityService.scroll(call.stringArg("direction"))
            else -> false
        }

        return if (ok) success("Executed accessibility action: $action")
        else failure("Could not execute accessibility action: $action")
    }

    private fun openApp(activity: Activity, call: MethodCall): Map<String, Any?> {
        val packageName = call.stringArg("packageName").ifEmpty {
            packageForAppName(call.stringArg("appName"))
        }
        if (packageName.isEmpty()) {
            return failure("Give ALTER an app name it knows or an Android package name.")
        }

        val launch = activity.packageManager.getLaunchIntentForPackage(packageName)
            ?: return failure("Could not find app package: $packageName")
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            activity.startActivity(launch)
            success("Opened $packageName.")
        } catch (error: Throwable) {
            failure("Could not open $packageName: ${error.message}")
        }
    }

    private fun openSettings(activity: Activity, screen: String): Map<String, Any?> {
        val action = when (screen.lowercase()) {
            "accessibility" -> Settings.ACTION_ACCESSIBILITY_SETTINGS
            "wifi" -> Settings.ACTION_WIFI_SETTINGS
            "bluetooth" -> Settings.ACTION_BLUETOOTH_SETTINGS
            "notification", "notifications" -> Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS
            "app", "apps" -> Settings.ACTION_APPLICATION_SETTINGS
            "battery" -> Settings.ACTION_BATTERY_SAVER_SETTINGS
            "privacy" -> Settings.ACTION_PRIVACY_SETTINGS
            else -> Settings.ACTION_SETTINGS
        }
        return openSettingsIntent(activity, action)
    }

    private fun openSettingsIntent(activity: Activity, action: String): Map<String, Any?> {
        return try {
            activity.startActivity(Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            success("Opened Android settings.")
        } catch (error: Throwable) {
            failure("Could not open settings: ${error.message}")
        }
    }

    private fun openDialer(activity: Activity, number: String): Map<String, Any?> {
        val clean = number.replace(Regex("[^\\d+]"), "")
        return try {
            activity.startActivity(
                Intent(Intent.ACTION_DIAL, Uri.parse("tel:$clean"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            success("Opened dialer for $clean.")
        } catch (error: Throwable) {
            failure("Could not open dialer: ${error.message}")
        }
    }

    private fun openBrowserSearch(activity: Activity, query: String): Map<String, Any?> {
        if (query.isBlank()) return failure("Search query is empty.")
        return try {
            val intent = Intent(Intent.ACTION_WEB_SEARCH)
                .putExtra("query", query)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            activity.startActivity(intent)
            success("Opened browser search for $query.")
        } catch (error: Throwable) {
            val uri = Uri.parse(
                "https://www.google.com/search?q=${Uri.encode(query)}",
            )
            try {
                activity.startActivity(
                    Intent(Intent.ACTION_VIEW, uri)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
                success("Opened browser search for $query.")
            } catch (fallbackError: Throwable) {
                failure("Could not open browser search: ${fallbackError.message}")
            }
        }
    }

    private fun openSmsDraft(
        activity: Activity,
        number: String,
        text: String,
    ): Map<String, Any?> {
        val clean = number.replace(Regex("[^\\d+]"), "")
        return try {
            val intent = Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:$clean"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                .putExtra("sms_body", text)
            activity.startActivity(intent)
            success("Opened SMS draft for $clean.")
        } catch (error: Throwable) {
            failure("Could not open SMS draft: ${error.message}")
        }
    }

    private fun deviceAdminStatus(activity: Activity): Map<String, Any?> {
        val manager = devicePolicyManager(activity)
        val packageName = activity.packageName
        val active = manager.isAdminActive(deviceAdminComponent(activity))
        val owner = manager.isDeviceOwnerApp(packageName)
        val profileOwner = manager.isProfileOwnerApp(packageName)
        return mapOf(
            "ok" to true,
            "message" to when {
                owner -> "ALTER is Device Owner on this Android profile."
                profileOwner -> "ALTER is Profile Owner on this Android profile."
                active -> "ALTER is active Device Admin."
                else -> "ALTER is not active Device Admin yet."
            },
            "adminActive" to active,
            "deviceOwner" to owner,
            "profileOwner" to profileOwner,
        )
    }

    private fun openDeviceAdminActivation(activity: Activity): Map<String, Any?> {
        return try {
            val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                .putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, deviceAdminComponent(activity))
                .putExtra(
                    DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                    "Enable ALTER as a managed-device admin for explicit test and control workflows.",
                )
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            activity.startActivity(intent)
            success("Opened Android Device Admin activation.")
        } catch (error: Throwable) {
            failure("Could not open Device Admin activation: ${error.message}")
        }
    }

    private fun lockDevice(activity: Activity): Map<String, Any?> {
        val manager = devicePolicyManager(activity)
        val component = deviceAdminComponent(activity)
        if (!manager.isAdminActive(component) && !manager.isDeviceOwnerApp(activity.packageName)) {
            return failure("Device Admin is not enabled. Activate ALTER Device Admin first.")
        }
        return try {
            manager.lockNow()
            success("Locked the device.")
        } catch (error: Throwable) {
            failure("Could not lock device: ${error.message}")
        }
    }

    private fun devicePolicyManager(activity: Activity): DevicePolicyManager {
        return activity.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    }

    private fun deviceAdminComponent(activity: Activity): ComponentName {
        return ComponentName(activity, AlterDeviceAdminReceiver::class.java)
    }

    private fun packageForAppName(appName: String): String {
        val key = appName.lowercase().replace(Regex("[^a-z0-9]"), "")
        return commonPackages[key].orEmpty()
    }

    private fun MethodCall.stringArg(name: String): String {
        return (argument<String>(name) ?: "").trim()
    }

    private fun MethodCall.floatArg(name: String): Float {
        val value = argument<Any>(name)
        return (value as? Number)?.toFloat() ?: 0f
    }

    private fun MethodCall.longArg(name: String, fallback: Long): Long {
        val value = argument<Any>(name)
        return (value as? Number)?.toLong() ?: fallback
    }

    private fun success(message: String): Map<String, Any?> {
        return mapOf("ok" to true, "message" to message)
    }

    private fun failure(message: String): Map<String, Any?> {
        return mapOf("ok" to false, "message" to message)
    }

    private val commonPackages = mapOf(
        "whatsapp" to "com.whatsapp",
        "whatsappbusiness" to "com.whatsapp.w4b",
        "messages" to "com.google.android.apps.messaging",
        "sms" to "com.google.android.apps.messaging",
        "gmail" to "com.google.android.gm",
        "chrome" to "com.android.chrome",
        "youtube" to "com.google.android.youtube",
        "instagram" to "com.instagram.android",
        "facebook" to "com.facebook.katana",
        "messenger" to "com.facebook.orca",
        "telegram" to "org.telegram.messenger",
        "linkedin" to "com.linkedin.android",
        "x" to "com.twitter.android",
        "twitter" to "com.twitter.android",
        "maps" to "com.google.android.apps.maps",
        "calendar" to "com.google.android.calendar",
        "photos" to "com.google.android.apps.photos",
        "phone" to "com.google.android.dialer",
        "dialer" to "com.google.android.dialer",
        "contacts" to "com.google.android.contacts",
        "playstore" to "com.android.vending",
        "store" to "com.android.vending",
        "settings" to "com.android.settings",
    )
}
