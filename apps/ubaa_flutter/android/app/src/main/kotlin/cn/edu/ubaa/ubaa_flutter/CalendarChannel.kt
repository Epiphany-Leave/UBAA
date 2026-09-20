package cn.edu.ubaa.ubaa_flutter

import android.Manifest
import android.app.Activity
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.CalendarContract
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar
import java.util.TimeZone
import java.util.concurrent.Executors

/** Device calendar only; never stores or logs event data. */
class CalendarChannel(private val activity: Activity) {
    private val worker = Executors.newSingleThreadExecutor()
    private var permission: MethodChannel.Result? = null
    private var closed = false
    private fun readable() = activity.checkSelfPermission(Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED

    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        if (!call.method.startsWith("calendar.")) return false
        when (call.method) {
            "calendar.capability" -> result.success(true)
            "calendar.requestRead" -> when {
                readable() -> result.success(true)
                permission != null -> result.error("calendar_busy", "日历授权正在进行", null)
                else -> {
                    permission = result
                    activity.requestPermissions(arrayOf(Manifest.permission.READ_CALENDAR), REQUEST)
                }
            }
            "calendar.read" -> read(call, result)
            "calendar.edit" -> edit(call, result)
            else -> result.notImplemented()
        }
        return true
    }

    fun onRequestPermissionsResult(request: Int): Boolean {
        if (request != REQUEST) return false
        permission?.success(readable())
        permission = null
        return true
    }

    private fun read(call: MethodCall, result: MethodChannel.Result) {
        val start = call.argument<Number>("startMs")?.toLong()
        val end = call.argument<Number>("endMs")?.toLong()
        if (start == null || end == null || start < 0 || end <= start || end > 253402300799000L || end - start > 366L * DAY) {
            result.error("calendar_time", "课程时间无效，未完成检测", null)
            return
        }
        if (!readable()) {
            result.error("calendar_denied", "未获得日历读取权限，未完成检测", null)
            return
        }
        worker.execute {
            try {
                val uri = CalendarContract.Instances.CONTENT_URI.buildUpon()
                // All-day instances use UTC dates; pad for conversion to local dates.
                ContentUris.appendId(uri, start - DAY)
                ContentUris.appendId(uri, end + DAY)
                val columns = arrayOf(
                    CalendarContract.Instances.BEGIN, CalendarContract.Instances.END,
                    CalendarContract.Events.TITLE, CalendarContract.Events.EVENT_LOCATION,
                    CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
                    CalendarContract.Events.ALL_DAY, CalendarContract.Events.AVAILABILITY,
                    CalendarContract.Events.STATUS,
                )
                val events = mutableListOf<Map<String, Any>>()
                activity.contentResolver.query(uri.build(), columns, null, null, "begin ASC")?.use { cursor ->
                    while (cursor.moveToNext()) {
                        if (!cursor.isNull(7) && cursor.getInt(7) == CalendarContract.Events.STATUS_CANCELED) continue
                        check(events.size < 10000)
                        val allDay = cursor.getInt(5) == 1
                        fun time(index: Int): Long {
                            val raw = cursor.getLong(index)
                            if (!allDay) return raw
                            val utc = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { timeInMillis = raw }
                            return Calendar.getInstance().apply {
                                clear()
                                set(utc.get(Calendar.YEAR), utc.get(Calendar.MONTH), utc.get(Calendar.DAY_OF_MONTH))
                            }.timeInMillis
                        }
                        events.add(mapOf(
                            "startMs" to time(0), "endMs" to time(1),
                            "title" to (cursor.getString(2) ?: "未命名日程"),
                            "location" to (cursor.getString(3) ?: ""),
                            "calendar" to (cursor.getString(4) ?: "日历"),
                            "allDay" to allDay,
                            "free" to (!cursor.isNull(6) && cursor.getInt(6) == CalendarContract.Events.AVAILABILITY_FREE),
                        ))
                    }
                } ?: error("calendar unavailable")
                activity.runOnUiThread {
                    if (!closed) {
                        if (readable()) result.success(events)
                        else result.error("calendar_denied", "日历权限已撤销，未完成检测", null)
                    }
                }
            } catch (_: Exception) {
                activity.runOnUiThread {
                    if (!closed) result.error("calendar_read", "日历读取失败，未完成检测", null)
                }
            }
        }
    }

    private fun edit(call: MethodCall, result: MethodChannel.Result) {
        try {
            val start = call.argument<Number>("startMs")!!.toLong()
            val end = call.argument<Number>("endMs")!!.toLong()
            val title = call.argument<String>("title")!!
            require(start >= 0 && end > start && end <= 253402300799000L && title.isNotBlank())
            activity.startActivity(Intent(Intent.ACTION_INSERT, CalendarContract.Events.CONTENT_URI).apply {
                putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, start)
                putExtra(CalendarContract.EXTRA_EVENT_END_TIME, end)
                putExtra(CalendarContract.Events.TITLE, title)
                putExtra(CalendarContract.Events.EVENT_LOCATION, call.argument<String>("location"))
                putExtra(CalendarContract.Events.DESCRIPTION, call.argument<String>("description"))
            })
            // ACTION_INSERT has no portable save acknowledgement or reminder extra.
            result.success("opened")
        } catch (_: Exception) {
            result.error("calendar_edit", "无法打开系统日历，请确认已启用日历应用", null)
        }
    }

    fun close() {
        closed = true
        permission?.success(false)
        permission = null
        worker.shutdownNow()
    }

    companion object {
        private const val REQUEST = 8242
        private const val DAY = 86400000L
    }
}
