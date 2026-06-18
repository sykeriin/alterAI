package com.example.alter

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import android.provider.CalendarContract
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

/**
 * Reads the device calendar via ContentResolver (no third-party plugin). On the
 * first call it requests READ_CALENDAR if needed and reports `granted=false`;
 * once the user allows it, the next call returns today's events.
 */
object CalendarReader {

    private const val PERMISSION_REQUEST = 9130

    fun handle(activity: Activity, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "todayEvents" -> result.success(todayEvents(activity))
            else -> result.notImplemented()
        }
    }

    private fun hasPermission(activity: Activity): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            activity.checkSelfPermission(Manifest.permission.READ_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun todayEvents(activity: Activity): Map<String, Any?> {
        if (!hasPermission(activity)) {
            try {
                activity.requestPermissions(
                    arrayOf(Manifest.permission.READ_CALENDAR),
                    PERMISSION_REQUEST,
                )
            } catch (_: Throwable) {
            }
            return mapOf("granted" to false, "events" to emptyList<Any?>())
        }

        val start = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val startMillis = start.timeInMillis
        val endMillis = startMillis + 24L * 60L * 60L * 1000L

        val projection = arrayOf(
            CalendarContract.Events.TITLE,
            CalendarContract.Events.DTSTART,
        )
        val selection =
            "${CalendarContract.Events.DTSTART} >= ? AND " +
                "${CalendarContract.Events.DTSTART} < ? AND " +
                "${CalendarContract.Events.DELETED} = 0"
        val args = arrayOf(startMillis.toString(), endMillis.toString())

        val events = mutableListOf<Map<String, Any?>>()
        try {
            activity.contentResolver.query(
                CalendarContract.Events.CONTENT_URI,
                projection,
                selection,
                args,
                "${CalendarContract.Events.DTSTART} ASC",
            )?.use { cursor ->
                val titleIdx = cursor.getColumnIndex(CalendarContract.Events.TITLE)
                val startIdx = cursor.getColumnIndex(CalendarContract.Events.DTSTART)
                while (cursor.moveToNext() && events.size < 12) {
                    events.add(
                        mapOf(
                            "title" to if (titleIdx >= 0) cursor.getString(titleIdx) else null,
                            "start" to if (startIdx >= 0) cursor.getLong(startIdx) else null,
                        ),
                    )
                }
            }
        } catch (_: Throwable) {
            return mapOf("granted" to true, "events" to emptyList<Any?>())
        }
        return mapOf("granted" to true, "events" to events)
    }
}
