package cn.edu.ubaa.ubaa_flutter

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint

internal data class WidgetSelection(
    val semester: WidgetSemester,
    val week: WidgetWeek,
)

internal data class WidgetAgendaItem(
    val date: String,
    val start: String,
    val end: String,
    val course: WidgetCourse,
)

/** RemoteViews 只负责容器；课表网格由一张按组件实际尺寸生成的图片承载。 */
internal fun renderScheduleWidget(selection: WidgetSelection, width: Int, height: Int): Bitmap {
    val week = selection.week
    if (width < 240 || height < 230) return renderCompactWeek(week, width, height)
    val scale = 2f
    val bitmap = Bitmap.createBitmap(width * scale.toInt(), height * scale.toInt(), Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap).apply { scale(scale, scale) }
    val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    val text = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.rgb(40, 58, 80)
        textSize = 10f
    }
    val sections = week.sections.ifEmpty {
        (1..12).map { WidgetSection(it, "--:--", "--:--") }
    }
    val left = 38f
    val top = 30f
    val column = (width - left) / 7f
    val row = (height - top) / sections.size.coerceAtLeast(1)
    val dates = weekDates(week)
    "一二三四五六日".forEachIndexed { index, day ->
        val center = left + column * (index + .5f)
        text.textAlign = Paint.Align.CENTER
        text.textSize = 10f
        canvas.drawText("周$day", center, 11f, text)
        canvas.drawText(dates.getOrNull(index).orEmpty(), center, 25f, text)
    }
    paint.color = Color.rgb(220, 229, 241)
    for (index in 0..sections.size) {
        canvas.drawLine(left, top + index * row, width.toFloat(), top + index * row, paint)
    }
    for (index in 0..7) {
        canvas.drawLine(left + index * column, top, left + index * column, height.toFloat(), paint)
    }
    sections.forEachIndexed { index, section ->
        val y = top + index * row
        text.textAlign = Paint.Align.CENTER
        text.textSize = 8f
        canvas.drawText(section.number.toString(), 5f, y + row * .6f, text)
        text.textSize = 7f
        canvas.drawText(section.start.ifEmpty { "--:--" }, 24f, y + row * .42f, text)
        canvas.drawText(section.end.ifEmpty { "--:--" }, 24f, y + row * .92f, text)
    }
    for (day in 1..7) {
        val courses = week.courses
            .filter { it.day == day && it.begin != null }
            .sortedBy { it.begin }
        val groups = mutableListOf<MutableList<WidgetCourse>>()
        var groupEnd = -1
        for (course in courses) {
            val end = course.end ?: course.begin!!
            if (groups.isEmpty() || course.begin!! > groupEnd) {
                groups.add(mutableListOf())
                groupEnd = end
            } else if (end > groupEnd) {
                groupEnd = end
            }
            groups.last() += course
        }
        for (group in groups) {
            group.forEachIndexed { lane, course ->
                drawCourse(
                    canvas = canvas,
                    paint = paint,
                    text = text,
                    course = course,
                    lane = lane,
                    lanes = group.size,
                    day = day,
                    sections = sections,
                    left = left,
                    top = top,
                    column = column,
                    row = row,
                )
            }
        }
    }
    if (week.courses.isEmpty()) {
        text.textAlign = Paint.Align.CENTER
        text.textSize = 14f
        canvas.drawText("本周没有已安排课程", width / 2f, height / 2f, text)
    }
    return bitmap
}

private fun drawCourse(
    canvas: Canvas,
    paint: Paint,
    text: TextPaint,
    course: WidgetCourse,
    lane: Int,
    lanes: Int,
    day: Int,
    sections: List<WidgetSection>,
    left: Float,
    top: Float,
    column: Float,
    row: Float,
) {
    val start = sections.indexOfFirst { it.number == course.begin }
    val end = sections.indexOfFirst { it.number == (course.end ?: course.begin) }
    if (start < 0 || end < start) return
    val laneWidth = column / lanes.coerceAtLeast(1)
    val rect = RectF(
        left + (day - 1) * column + lane * laneWidth + 1f,
        top + start * row + 1f,
        left + (day - 1) * column + (lane + 1) * laneWidth - 1f,
        top + (end + 1) * row - 1f,
    )
    paint.color = Color.rgb(222, 234, 253)
    canvas.drawRoundRect(rect, 4f, 4f, paint)
    drawWidgetText(
        canvas,
        "${course.title}\n${course.place.orEmpty()}",
        rect.left + 2f,
        rect.top + 2f,
        (rect.width() - 4f).toInt(),
        (rect.height() - 4f).toInt(),
        10f,
        Layout.Alignment.ALIGN_CENTER,
    )
}

private fun renderCompactWeek(week: WidgetWeek, width: Int, height: Int): Bitmap {
    val bitmap = Bitmap.createBitmap(width * 2, height * 2, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap).apply { scale(2f, 2f) }
    val column = width / 2
    val row = height / 4
    for (day in 1..7) {
        val courses = week.courses.filter { it.day == day }.sortedBy { it.begin }
        val label = "周${"一二三四五六日"[day - 1]} · ${courses.size}门\n" +
            courses.joinToString(" / ") { "${it.title} ${it.place.orEmpty()}" }.ifEmpty { "无课" }
        drawWidgetText(
            canvas,
            label,
            ((day - 1) % 2 * column + 2).toFloat(),
            ((day - 1) / 2 * row).toFloat(),
            column - 6,
            row - 2,
            10f,
            Layout.Alignment.ALIGN_NORMAL,
        )
    }
    drawWidgetText(
        canvas,
        "点击查看整周\n拉高显示时间网格",
        (column + 2).toFloat(),
        (row * 3).toFloat(),
        column - 6,
        row - 2,
        10f,
        Layout.Alignment.ALIGN_NORMAL,
    )
    return bitmap
}

internal fun renderAgendaWidget(items: List<WidgetAgendaItem>, width: Int, height: Int): Bitmap {
    val bitmap = Bitmap.createBitmap(width * 2, height * 2, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap).apply { scale(2f, 2f) }
    if (items.isEmpty()) {
        drawWidgetText(canvas, "没有已安排课程", 4f, 8f, width - 8, height - 8, 13f, Layout.Alignment.ALIGN_NORMAL)
        return bitmap
    }
    val rows = ((height - 16) / 44).coerceAtLeast(1)
    items.take(rows).forEachIndexed { index, item ->
        drawWidgetText(
            canvas,
            "${item.date} ${item.start}–${item.end}\n${item.course.title}  ${item.course.place.orEmpty()}",
            4f,
            (index * 44).toFloat(),
            width - 8,
            42,
            12f,
            Layout.Alignment.ALIGN_NORMAL,
        )
    }
    if (items.size > rows) {
        drawWidgetText(
            canvas,
            "另 ${items.size - rows} 门 · 点击查看",
            4f,
            (height - 15).toFloat(),
            width - 8,
            15,
            10f,
            Layout.Alignment.ALIGN_NORMAL,
        )
    }
    return bitmap
}

private fun drawWidgetText(
    canvas: Canvas,
    value: String,
    x: Float,
    y: Float,
    width: Int,
    height: Int,
    size: Float,
    alignment: Layout.Alignment,
) {
    if (width <= 0 || height <= 0) return
    val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.rgb(35, 57, 82)
        textSize = size
    }
    @Suppress("DEPRECATION")
    val layout = StaticLayout(value, paint, width, alignment, 1f, 0f, false)
    canvas.save()
    canvas.clipRect(x, y, x + width, y + height)
    canvas.translate(x, y)
    layout.draw(canvas)
    canvas.restore()
}

private fun weekDates(week: WidgetWeek): List<String> {
    val start = parseWidgetDate(week.start) ?: return List(7) { "" }
    return List(7) { offset ->
        val value = (start.clone() as java.util.Calendar).apply { add(java.util.Calendar.DAY_OF_MONTH, offset) }
        "%02d/%02d".format(value.get(java.util.Calendar.MONTH) + 1, value.get(java.util.Calendar.DAY_OF_MONTH))
    }
}
