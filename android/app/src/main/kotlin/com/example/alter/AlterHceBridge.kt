package com.example.alter

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.nfc.NfcAdapter
import android.nfc.cardemulation.CardEmulation
import android.util.Base64
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges the Flutter NFC controller to [AlterHceService]: it turns the user's
 * profile JSON into an NDEF message, caches it for the HCE service to serve,
 * and makes ALTER the preferred card-emulation service while sharing so the
 * other phone routes to us on tap.
 */
object AlterHceBridge {

    fun handle(activity: Activity, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isHceSupported" -> result.success(isSupported(activity))
            "enableSharing" -> {
                val mimeType = call.argument<String>("mimeType").orEmpty()
                val json = call.argument<String>("json").orEmpty()
                result.success(enable(activity, mimeType, json))
            }
            "disableSharing" -> {
                disable(activity)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun isSupported(context: Context): Boolean {
        return context.packageManager
            .hasSystemFeature(PackageManager.FEATURE_NFC_HOST_CARD_EMULATION)
    }

    private fun enable(activity: Activity, mimeType: String, json: String): Boolean {
        if (!isSupported(activity) || mimeType.isBlank() || json.isBlank()) {
            return false
        }
        val record = NdefRecord.createMime(mimeType, json.toByteArray(Charsets.UTF_8))
        val bytes = NdefMessage(arrayOf(record)).toByteArray()
        AlterHceService.cachedNdef = bytes
        activity
            .getSharedPreferences(AlterHceService.PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(AlterHceService.KEY_NDEF, Base64.encodeToString(bytes, Base64.NO_WRAP))
            .apply()

        // Best-effort: prefer our service so taps route here while the app is up.
        return try {
            val adapter = NfcAdapter.getDefaultAdapter(activity) ?: return false
            CardEmulation.getInstance(adapter).setPreferredService(
                activity,
                ComponentName(activity, AlterHceService::class.java),
            )
            true
        } catch (_: Throwable) {
            // Payload is still set; routing falls back to the default service.
            true
        }
    }

    private fun disable(activity: Activity) {
        try {
            val adapter = NfcAdapter.getDefaultAdapter(activity) ?: return
            CardEmulation.getInstance(adapter).unsetPreferredService(activity)
        } catch (_: Throwable) {
        }
    }
}
