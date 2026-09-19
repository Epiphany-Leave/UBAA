package cn.edu.ubaa.ubaa_flutter

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
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
            listOf("anchor", "term", "week").forEach { editor.remove("$id-$it") }
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
                else -> 0
            }
            val preferences = context.getSharedPreferences(WIDGET_PREFERENCES, Context.MODE_PRIVATE)
            val today = widgetToday()
            val anchor = widgetDate(today)
            val keepSelection = agendaDays == 0 &&
                step != 0 &&
                preferences.getString("$id-anchor", null) == anchor
            val schedule = ScheduleWidgetSnapshot.read(context)
            var selected = schedule?.selectWeek(
                today,
                if (keepSelection) preferences.getString("$id-term", null) else null,
                if (keepSelection) preferences.getInt("$id-week", -1) else null,
            )
            if (selected != null && agendaDays == 0 && (step == -1 || step == 1)) {
                val current = selected ?: return
                val weeks = current.semester.weeks
                val index = weeks.indexOfFirst { it.number == current.week.number }
                selected = weeks.getOrNull(index + step)?.let { WidgetSelection(current.semester, it) } ?: current
            }
            val layout = when (agendaDays) {
                1 -> R.layout.schedule_today_widget
                3 -> R.layout.schedule_upcoming_widget
                else -> R.layout.schedule_widget
            }
            val views = RemoteViews(context.packageName, layout)
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
            val showNavigation = agendaDays == 0
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
                    .apply()
                renderScheduleWidget(
                    context = context,
                    manager = manager,
                    id = id,
                    views = views,
                    selected = selected,
                    schedule = schedule,
                    today = today,
                    agendaDays = agendaDays,
                )
            }
            manager.updateAppWidget(id, views)
        }

        private fun renderEmptyWidget(views: RemoteViews, missingSnapshot: Boolean, agendaDays: Int) {
            views.setViewVisibility(R.id.widget_grid, View.GONE)
            views.setImageViewBitmap(R.id.widget_grid, null)
            views.setViewVisibility(R.id.widget_message, View.VISIBLE)
            views.setTextViewText(R.id.widget_title, when (agendaDays) {
                1 -> "UBAA 今日课程"
                3 -> "UBAA 近日课程"
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
        ) {
            val options = manager.getAppWidgetOptions(id)
            val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 320).coerceIn(110, 700) - 16
            val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 400).coerceIn(100, 900) - 48
            if (agendaDays == 0 && width < 220) views.setViewVisibility(R.id.widget_current, View.GONE)
            val title = when (agendaDays) {
                1 -> "今日课程 · ${widgetDate(today).takeLast(5)}"
                3 -> "近日课程 · 今天起三天"
                else -> "周课表 · ${selected.week.name}"
            }
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_footer, "本地课表 · 更新于 ${selected.semester.updatedAt}")
            views.setViewVisibility(R.id.widget_message, View.GONE)
            views.setViewVisibility(R.id.widget_grid, View.VISIBLE)
            val image = if (agendaDays == 0) {
                cn.edu.ubaa.ubaa_flutter.renderScheduleWidget(selected, width, height)
            } else {
                renderAgendaWidget(schedule?.agenda(today, agendaDays).orEmpty(), width, height)
            }
            views.setImageViewBitmap(R.id.widget_grid, image)
            views.setContentDescription(
                R.id.widget_grid,
                buildString {
                    append("$title，点击打开周课表。")
                    if (agendaDays > 0) {
                        schedule?.agenda(today, agendaDays).orEmpty().forEach {
                            append("${it.date} ${it.start} ${it.course.title} ${it.course.place.orEmpty()}；")
                        }
                    } else selected.week.courses
                        .filter { it.day != null && it.day in 1..7 }
                        .sortedWith(compareBy({ it.day }, { it.begin }))
                        .forEach { append("周${it.day} ${it.title} ${it.place.orEmpty()}；") }
                },
            )
            val weeks = selected.semester.weeks
            views.setBoolean(R.id.widget_previous, "setEnabled", selected.week != weeks.firstOrNull())
            views.setBoolean(R.id.widget_next, "setEnabled", selected.week != weeks.lastOrNull())
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
        selected.week.courses.filter { it.day == weekday }.forEach { course ->
            val start = selected.week.sections.firstOrNull { it.number == course.begin }?.start.orEmpty()
            val end = selected.week.sections.firstOrNull { it.number == (course.end ?: course.begin) }?.end.orEmpty()
            add(WidgetAgendaItem(widgetDate(date).takeLast(5), start, end, course))
        }
    }
}.sortedWith(compareBy({ it.date }, { it.start }, { it.course.title }))
