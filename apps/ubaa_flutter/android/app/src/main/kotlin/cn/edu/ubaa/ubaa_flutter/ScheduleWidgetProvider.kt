package cn.edu.ubaa.ubaa_flutter

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

open class ScheduleWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { update(context, manager, it) }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        options: Bundle,
    ) {
        update(context, manager, id)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_REFRESH -> refreshAll(context)
            ACTION_WEEK -> {
                val manager = AppWidgetManager.getInstance(context)
                val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1)
                if (providerClasses.any { it.name == manager.getAppWidgetInfo(id)?.provider?.className }) {
                    update(context, manager, id, intent.getIntExtra(EXTRA_WEEK_STEP, 0))
                }
            }
        }
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        val editor = context.getSharedPreferences(WIDGET_PREFERENCES, Context.MODE_PRIVATE).edit()
        ids.forEach { id ->
            listOf("anchor", "term", "week", "fixedTerm", "background", "font", "timeline", "weekends", "offset").forEach { editor.remove("$id-$it") }
        }
        editor.apply()
    }

    companion object {
        private const val ACTION_WEEK = "cn.edu.ubaa.ubaa_flutter.widget.WEEK"
        private const val ACTION_REFRESH = "cn.edu.ubaa.ubaa_flutter.widget.REFRESH"
        private const val EXTRA_WEEK_STEP = "step"
        private const val WIDGET_PREFERENCES = "schedule_widgets"
        private val providerClasses = listOf(
            ScheduleWidgetProvider::class.java,
            TodayScheduleWidgetProvider::class.java,
            UpcomingScheduleWidgetProvider::class.java,
            DayScheduleWidgetProvider::class.java,
        )

        fun requestRefresh(context: Context) {
            context.sendBroadcast(
                Intent(context, ScheduleWidgetProvider::class.java).setAction(ACTION_REFRESH),
            )
        }

        private fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            providerClasses.forEach { provider ->
                manager.getAppWidgetIds(ComponentName(context, provider)).forEach { id ->
                    update(context, manager, id)
                }
            }
        }

        private fun update(
            context: Context,
            manager: AppWidgetManager,
            id: Int,
            step: Int? = null,
        ) {
            val provider = manager.getAppWidgetInfo(id)?.provider ?: return
            val agendaDays = when (provider.className) {
                TodayScheduleWidgetProvider::class.java.name -> 1
                UpcomingScheduleWidgetProvider::class.java.name -> 3
                DayScheduleWidgetProvider::class.java.name -> -1
                else -> 0
            }
            val preferences = context.getSharedPreferences(WIDGET_PREFERENCES, Context.MODE_PRIVATE)
            val today = widgetToday()
            val anchor = widgetDate(today)
            val dayView = agendaDays == -1
            var offset = if (preferences.getString("$id-anchor", null) == anchor) preferences.getInt("$id-offset", 0) else 0
            if (dayView && step != null) offset = if (step == 0) 0 else (offset + step).coerceIn(-366, 366)
            val fixedTerm = if (agendaDays <= 0) preferences.getString("$id-fixedTerm", null)?.takeIf { it.isNotBlank() } else null
            val activeTerm = fixedTerm ?: preferences.getString("activeTerm", null)
            val keepSelection = agendaDays == 0 &&
                step != 0 &&
                preferences.getString("$id-anchor", null) == anchor
            val snapshot = ScheduleWidgetSnapshot.read(context)
            // A pinned term must never silently show another semester's classes.
            val schedule = if (activeTerm.isNullOrBlank()) snapshot else snapshot?.copy(semesters = snapshot.semesters.filter { it.term == activeTerm })
            val baseDate = if (dayView && fixedTerm != null && schedule?.weekAt(today) == null)
                parseWidgetDate(schedule?.semesters?.firstOrNull()?.weeks?.firstOrNull()?.start) ?: today else today
            val displayDate = (baseDate.clone() as Calendar).apply { if (dayView) add(Calendar.DAY_OF_MONTH, offset) }
            var selected = schedule?.selectWeek(
                displayDate,
                if (keepSelection) preferences.getString("$id-term", null) else null,
                if (keepSelection) preferences.getInt("$id-week", -1) else null,
            )
            if (selected != null && agendaDays == 0 && (step == -1 || step == 1)) {
                val current = selected ?: return
                val weeks = current.semester.weeks
                val index = weeks.indexOfFirst { it.number == current.week.number }
                selected = weeks.getOrNull(index + step)?.let { WidgetSelection(current.semester, it) } ?: current
            }
            val views = RemoteViews(context.packageName, R.layout.schedule_widget)
            val style = WidgetStyle(
                font = preferences.getInt("$id-font", 1).coerceIn(0, 2),
                timeline = preferences.getBoolean("$id-timeline", true),
                weekends = preferences.getBoolean("$id-weekends", true),
            )
            views.setInt(R.id.widget_root, "setBackgroundResource", when (preferences.getInt("$id-background", 0)) {
                1 -> R.drawable.schedule_widget_warm
                2 -> android.R.color.transparent
                else -> R.drawable.schedule_widget_background
            })
            views.setViewVisibility(R.id.widget_settings, if (agendaDays <= 0) View.VISIBLE else View.GONE)
            views.setOnClickPendingIntent(R.id.widget_settings, PendingIntent.getActivity(context, id,
                Intent(context, ScheduleWidgetSettingsActivity::class.java).setData(Uri.parse("ubaa-widget://settings/$id"))
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            views.setOnClickPendingIntent(
                R.id.widget_root,
                PendingIntent.getActivity(
                    context,
                    id,
                    openIntent(context, selected),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
            listOf(R.id.widget_previous to -1, R.id.widget_next to 1, R.id.widget_current to 0).forEach { (view, delta) ->
                val intent = Intent(context, providerClasses.first { it.name == provider.className })
                    .setAction(ACTION_WEEK)
                    .setData(Uri.parse("ubaa-widget://week/$id/$delta"))
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                    .putExtra(EXTRA_WEEK_STEP, delta)
                views.setOnClickPendingIntent(
                    view,
                    PendingIntent.getBroadcast(
                        context,
                        id,
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    ),
                )
            }
            val showNavigation = agendaDays <= 0
            if (dayView) {
                views.setContentDescription(R.id.widget_previous, "前一天")
                views.setContentDescription(R.id.widget_next, "后一天")
                views.setTextViewText(R.id.widget_current, "今天")
                views.setContentDescription(R.id.widget_current, "回到今天")
            }
            views.setViewVisibility(R.id.widget_previous, if (showNavigation) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.widget_next, if (showNavigation) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.widget_current, if (showNavigation) View.VISIBLE else View.GONE)
            if (selected == null) {
                renderEmptyWidget(views, schedule == null, agendaDays)
            } else {
                preferences.edit()
                    .putString("$id-anchor", anchor)
                    .putString("$id-term", selected.semester.term)
                    .putInt("$id-week", selected.week.number)
                    .putInt("$id-offset", offset)
                    .apply()
                renderScheduleWidget(
                    context = context,
                    manager = manager,
                    id = id,
                    views = views,
                    selected = selected,
                    schedule = schedule,
                    today = displayDate,
                    agendaDays = agendaDays,
                    style = style,
                )
            }
            manager.updateAppWidget(id, views)
            if (agendaDays == 0) manager.notifyAppWidgetViewDataChanged(id, R.id.widget_week_list)
        }

        private fun renderEmptyWidget(views: RemoteViews, missingSnapshot: Boolean, agendaDays: Int) {
            views.setViewVisibility(R.id.widget_grid, View.GONE)
            views.setViewVisibility(R.id.widget_week_header, View.GONE)
            views.setViewVisibility(R.id.widget_week_list, View.GONE)
            views.setImageViewBitmap(R.id.widget_grid, null)
            views.setViewVisibility(R.id.widget_message, View.VISIBLE)
            views.setTextViewText(R.id.widget_title, when (agendaDays) {
                1 -> "UBAA 今日课程"
                3 -> "UBAA 近日课程"
                -1 -> "UBAA 日视图"
                else -> "UBAA 周课表"
            })
            views.setTextViewText(R.id.widget_footer, "本地课表 · 点击打开应用")
            views.setContentDescription(R.id.widget_grid, "暂无本地课表")
            views.setBoolean(R.id.widget_previous, "setEnabled", false)
            views.setBoolean(R.id.widget_next, "setEnabled", false)
            views.setTextViewText(
                R.id.widget_message,
                if (missingSnapshot) "请先打开 UBAA，登录并本地化课表" else "暂无已安排课表，请打开应用本地化课表",
            )
        }

        private fun renderScheduleWidget(
            context: Context,
            manager: AppWidgetManager,
            id: Int,
            views: RemoteViews,
            selected: WidgetSelection,
            schedule: WidgetSchedule?,
            today: Calendar,
            agendaDays: Int,
            style: WidgetStyle,
        ) {
            val options = manager.getAppWidgetOptions(id)
            val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 320).coerceIn(110, 700) - 16
            val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 400).coerceIn(100, 900) - 64
            if (agendaDays == 0 && width < 220) views.setViewVisibility(R.id.widget_current, View.GONE)
            val title = when (agendaDays) {
                1 -> "今日课程 · ${widgetDate(today).takeLast(5)}"
                3 -> "近日课程 · 今天起三天"
                -1 -> "日视图 · ${widgetDate(today).takeLast(5)}"
                else -> "一周课程 · ${selected.week.name}"
            }
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_footer, selected.semester.name)
            views.setViewVisibility(R.id.widget_message, View.GONE)
            views.setViewVisibility(R.id.widget_grid, if (agendaDays == 0) View.GONE else View.VISIBLE)
            views.setViewVisibility(R.id.widget_week_header, if (agendaDays == 0) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.widget_week_list, if (agendaDays == 0) View.VISIBLE else View.GONE)
            if (agendaDays == 0) {
                views.setImageViewBitmap(R.id.widget_grid, null)
                views.setImageViewBitmap(R.id.widget_week_header,
                    cn.edu.ubaa.ubaa_flutter.renderScheduleWidget(selected, width, WEEK_HEADER_HEIGHT, style, headerOnly = true))
                views.setRemoteAdapter(R.id.widget_week_list, Intent(context, ScheduleWeekService::class.java)
                    .setData(Uri.parse("ubaa-widget://rows/$id"))
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id))
                // A collection needs a mutable, explicitly targeted template for row fill-in extras.
                views.setPendingIntentTemplate(R.id.widget_week_list, PendingIntent.getActivity(context, id,
                    openIntent(context, selected).setData(Uri.parse("ubaa-widget://open/$id")),
                    PendingIntent.FLAG_UPDATE_CURRENT or if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0))
            } else {
                views.setImageViewBitmap(R.id.widget_grid, renderAgendaWidget(schedule?.agenda(today, if (agendaDays == -1) 1 else agendaDays).orEmpty(), width, height,
                    days = if (agendaDays == 3) 3 else 1, filled = agendaDays == -1, style = style, today = today))
            }
            views.setContentDescription(
                R.id.widget_grid,
                buildString {
                    append("$title，点击打开周课表。")
                    if (agendaDays != 0) {
                        schedule?.agenda(today, if (agendaDays == -1) 1 else agendaDays).orEmpty().forEach {
                            append("${it.date} ${it.start} ${it.course.title} ${it.course.place.orEmpty()}；")
                        }
                    } else selected.week.courses
                        .filter { it.day != null && it.day in 1..7 }
                        .sortedWith(compareBy({ it.day }, { it.begin }))
                        .forEach { append("周${it.day} ${it.title} ${it.place.orEmpty()}；") }
                },
            )
            val weeks = selected.semester.weeks
            views.setBoolean(R.id.widget_previous, "setEnabled", agendaDays == -1 || selected.week != weeks.firstOrNull())
            views.setBoolean(R.id.widget_next, "setEnabled", agendaDays == -1 || selected.week != weeks.lastOrNull())
        }

        private fun openIntent(context: Context, selected: WidgetSelection?): Intent = Intent(
            context,
            MainActivity::class.java,
        ).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            if (selected != null) {
                putExtra(MainActivity.EXTRA_WIDGET_TERM, selected.semester.term)
                putExtra(MainActivity.EXTRA_WIDGET_WEEK, selected.week.number)
            }
        }
    }
}

class TodayScheduleWidgetProvider : ScheduleWidgetProvider()

class UpcomingScheduleWidgetProvider : ScheduleWidgetProvider()
class DayScheduleWidgetProvider : ScheduleWidgetProvider()

private val chinaTimeZone: TimeZone = TimeZone.getTimeZone("Asia/Shanghai")

internal fun widgetToday(): Calendar = Calendar.getInstance(chinaTimeZone).apply {
    set(Calendar.HOUR_OF_DAY, 0)
    set(Calendar.MINUTE, 0)
    set(Calendar.SECOND, 0)
    set(Calendar.MILLISECOND, 0)
}

internal fun parseWidgetDate(value: String?): Calendar? {
    if (value.isNullOrBlank()) return null
    return runCatching {
        val formatter = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply {
            isLenient = false
            timeZone = chinaTimeZone
        }
        Calendar.getInstance(chinaTimeZone).apply {
            time = formatter.parse(value) ?: return null
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
    }.getOrNull()
}

internal fun widgetDate(value: Calendar): String = String.format(
    Locale.US,
    "%04d-%02d-%02d",
    value.get(Calendar.YEAR),
    value.get(Calendar.MONTH) + 1,
    value.get(Calendar.DAY_OF_MONTH),
)

private fun WidgetSchedule.selectWeek(
    today: Calendar,
    term: String?,
    number: Int?,
): WidgetSelection? {
    if (!term.isNullOrBlank() && number != null && number > 0) {
        semesters.firstOrNull { it.term == term }
            ?.weeks
            ?.firstOrNull { it.number == number }
            ?.let { week -> return WidgetSelection(semesters.first { it.term == term }, week) }
    }
    return weekAt(today) ?: semesters.firstNotNullOfOrNull { semester ->
        semester.weeks.firstOrNull()?.let { WidgetSelection(semester, it) }
    }
}

private fun WidgetSchedule.weekAt(date: Calendar): WidgetSelection? = semesters.firstNotNullOfOrNull { semester ->
    semester.weeks.firstOrNull { it.contains(date) }?.let { WidgetSelection(semester, it) }
}

private fun WidgetWeek.contains(date: Calendar): Boolean {
    val start = parseWidgetDate(start) ?: return false
    val end = parseWidgetDate(end) ?: return false
    return !date.before(start) && !date.after(end)
}

private fun WidgetSchedule.agenda(today: Calendar, days: Int): List<WidgetAgendaItem> = buildList {
    repeat(days) { offset ->
        val date = (today.clone() as Calendar).apply { add(Calendar.DAY_OF_MONTH, offset) }
        val selected = weekAt(date) ?: return@repeat
        val weekday = when (date.get(Calendar.DAY_OF_WEEK)) {
            Calendar.MONDAY -> 1
            Calendar.TUESDAY -> 2
            Calendar.WEDNESDAY -> 3
            Calendar.THURSDAY -> 4
            Calendar.FRIDAY -> 5
            Calendar.SATURDAY -> 6
            else -> 7
        }
        selected.week.courses.filter { it.day == weekday }.sortedBy { it.begin }.forEach { course ->
            val start = selected.week.sections.firstOrNull { it.number == course.begin }?.start.orEmpty()
            val end = selected.week.sections.firstOrNull { it.number == (course.end ?: course.begin) }?.end.orEmpty()
            add(WidgetAgendaItem(widgetDate(date).takeLast(5), start, end, course))
        }
    }
}
