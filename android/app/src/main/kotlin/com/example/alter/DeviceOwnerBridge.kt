package com.example.alter

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

object DeviceOwnerBridge {
    private const val ADMIN_COMPONENT =
        "com.example.alter/.AlterDeviceAdminReceiver"

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isDeviceOwner" -> result.success(isDeviceOwner(context))
            "isDeviceAdminActive" -> result.success(isDeviceAdminActive(context))
            "getDeviceOwnerComponent" -> result.success(getDeviceOwnerComponent(context))
            "requestDeviceAdminSetup" -> {
                requestDeviceAdminSetup(context)
                result.success(null)
            }
            "requestDeviceOwnerSetup" -> {
                requestDeviceAdminSetup(context)
                result.success(null)
            }
            "whitelistAccessibilityService" -> {
                whitelistAccessibilityService(context)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun isDeviceOwner(context: Context): Boolean {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        return dpm.isDeviceOwnerApp(context.packageName)
    }

    fun isDeviceAdminActive(context: Context): Boolean {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        return dpm.isAdminActive(adminComponent(context))
    }

    fun getDeviceOwnerComponent(context: Context): String? {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        if (!dpm.isDeviceOwnerApp(context.packageName)) return null
        return ADMIN_COMPONENT
    }

    fun requestDeviceAdminSetup(context: Context) {
        if (isDeviceAdminActive(context)) return

        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
            putExtra(
                DevicePolicyManager.EXTRA_DEVICE_ADMIN,
                adminComponent(context),
            )
            putExtra(
                DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                "ALTER needs device admin for policy features. This does not require device owner and works alongside other admin apps.",
            )
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    @Deprecated("Use requestDeviceAdminSetup", ReplaceWith("requestDeviceAdminSetup(context)"))
    fun requestDeviceOwnerSetup(context: Context) = requestDeviceAdminSetup(context)

    fun whitelistAccessibilityService(context: Context) {
        if (!isDeviceOwner(context)) return
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val component = ComponentName(context, AlterAccessibilityService::class.java).flattenToString()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            dpm.setPermittedAccessibilityServices(adminComponent(context), listOf(component))
        }
    }

    private fun adminComponent(context: Context): ComponentName {
        return ComponentName(context, AlterDeviceAdminReceiver::class.java)
    }
}
