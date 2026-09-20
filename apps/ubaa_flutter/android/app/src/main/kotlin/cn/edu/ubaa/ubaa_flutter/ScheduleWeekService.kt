package cn.edu.ubaa.ubaa_flutter

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.graphics.Bitmap
import android.widget.RemoteViews
import android.widget.RemoteViewsService

internal const val WEEK_SECTION_HEIGHT = 52
internal const val WEEK_HEADER_HEIGHT = 30

/** Keep course geometry across rows while the launcher scrolls the viewport. */
class ScheduleWeekService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory = WeekFactory(intent)

    private inner class WeekFactory(intent: Intent) : RemoteViewsFactory {
        private val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1)
        private var image: Bitmap? = null
        private var selection: WidgetSelection? = null
        private var rows = 0
        override fun onCreate() = Unit
        override fun onDataSetChanged() {
            image = null
            rows = 0
            selection = null
            val preferences = getSharedPreferences("schedule_widgets", MODE_PRIVATE)
            val term = preferences.getString("$id-term", null)
            val weekNumber = preferences.getInt("$id-week", -1)
            val semester = ScheduleWidgetSnapshot.read(this@ScheduleWeekService)?.semesters?.firstOrNull { it.term == term } ?: return
            val week = semester.weeks.firstOrNull { it.number == weekNumber } ?: return
            val selected = WidgetSelection(semester, week)
            val width = AppWidgetManager.getInstance(this@ScheduleWeekService).getAppWidgetOptions(id)
                .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 320).coerceIn(110, 700) - 16
            val style = WidgetStyle(preferences.getInt("$id-font", 1).coerceIn(0, 2),
                preferences.getBoolean("$id-timeline", true), preferences.getBoolean("$id-weekends", true))
            rows = week.sections.size.takeIf { it > 0 } ?: 12
            image = renderScheduleWidget(selected, width, WEEK_HEADER_HEIGHT + rows * WEEK_SECTION_HEIGHT, style)
            selection = selected
        }
        override fun onDestroy() { image = null; selection = null }
        override fun getCount() = rows
        override fun getViewAt(position: Int): RemoteViews? {
            val full = image ?: return null
            val selected = selection ?: return null
            if (position !in 0 until rows) return null
            val crop = Bitmap.createBitmap(full, 0, (WEEK_HEADER_HEIGHT + position * WEEK_SECTION_HEIGHT) * 2,
                full.width, WEEK_SECTION_HEIGHT * 2)
            return RemoteViews(packageName, R.layout.schedule_week_row).apply {
                setImageViewBitmap(R.id.widget_week_row, crop)
                val section = selected.week.sections.getOrNull(position)
                setContentDescription(R.id.widget_week_row, buildString {
                    append("第${section?.number ?: position + 1}节 ${section?.start.orEmpty()} ${section?.end.orEmpty()}。")
                    selected.week.courses.filter { course ->
                        val number = section?.number ?: position + 1
                        course.begin != null && number >= course.begin && number <= (course.end ?: course.begin)
                    }.forEach { append("周${it.day} ${it.title} ${it.place.orEmpty()}；") }
                })
                setOnClickFillInIntent(R.id.widget_week_row, Intent()
                    .putExtra(MainActivity.EXTRA_WIDGET_TERM, selected.semester.term)
                    .putExtra(MainActivity.EXTRA_WIDGET_WEEK, selected.week.number))
            }
        }
        override fun getLoadingView(): RemoteViews? = null
        override fun getViewTypeCount() = 1
        override fun getItemId(position: Int) = position.toLong()
        override fun hasStableIds() = true
    }
}
