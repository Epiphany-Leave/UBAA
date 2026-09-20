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

internal data class WidgetStyle(val font: Int = 1, val timeline: Boolean = true, val weekends: Boolean = true)
private val coursePalette = intArrayOf(0xFFF3ACBC.toInt(), 0xFFB8AFE6.toInt(), 0xFFA6D8E9.toInt(), 0xFFF5CB9D.toInt(), 0xFFACD8C2.toInt())
private fun courseColor(course: WidgetCourse) = coursePalette[Math.floorMod(course.title.hashCode(), coursePalette.size)]

/** RemoteViews 只负责容器；课表网格由一张按组件实际尺寸生成的图片承载。 */
internal fun renderScheduleWidget(selection: WidgetSelection, width: Int, height: Int, style: WidgetStyle = WidgetStyle(), headerOnly: Boolean = false): Bitmap {
    val week = selection.week
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
    val left = if (style.timeline) 38f else 16f
    val top = 30f
    val dayCount = if (style.weekends) 7 else 5
    val column = (width - left) / dayCount
    val row = (height - top) / sections.size.coerceAtLeast(1)
    val dates = weekDates(week)
    "一二三四五六日".take(dayCount).forEachIndexed { index, day ->
        val center = left + column * (index + .5f)
        text.textAlign = Paint.Align.CENTER
        text.textSize = 10f
        canvas.drawText("周$day", center, 11f, text)
        canvas.drawText(dates.getOrNull(index).orEmpty(), center, 25f, text)
    }
    if (headerOnly) return bitmap
    paint.color = Color.rgb(220, 229, 241)
    for (index in 0..sections.size) {
        canvas.drawLine(left, top + index * row, width.toFloat(), top + index * row, paint)
    }
    for (index in 0..dayCount) {
        canvas.drawLine(left + index * column, top, left + index * column, height.toFloat(), paint)
    }
    sections.forEachIndexed { index, section ->
        val y = top + index * row
        text.textAlign = Paint.Align.CENTER
        text.textSize = 8f
        canvas.drawText(section.number.toString(), 5f, y + row * .6f, text)
        text.textSize = 7f
        if (style.timeline) {
            text.textSize = (row * .32f).coerceIn(4f, 7f)
            canvas.drawText(section.start.ifEmpty { "--:--" }, 24f, y + row * .42f, text)
            canvas.drawText(section.end.ifEmpty { "--:--" }, 24f, y + row * .92f, text)
        }
    }
    for (day in 1..dayCount) {
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
                    fontSize = (7 + style.font * 2).toFloat(),
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
    fontSize: Float,
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
    paint.color = courseColor(course)
    canvas.drawRoundRect(rect, 4f, 4f, paint)
    drawWidgetText(
        canvas,
        "${course.title}\n${course.place.orEmpty()}",
        rect.left + 2f,
        rect.top + 2f,
        (rect.width() - 4f).toInt(),
        (rect.height() - 4f).toInt(),
        fontSize,
        Layout.Alignment.ALIGN_CENTER,
    )
}

internal fun renderAgendaWidget(items: List<WidgetAgendaItem>, width: Int, height: Int,
    days: Int, filled: Boolean, style: WidgetStyle, today: java.util.Calendar): Bitmap {
    val bitmap = Bitmap.createBitmap(width * 2, height * 2, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap).apply { scale(2f, 2f) }
    val columns = if (days > 1 && width >= 240) days else 1
    val columnWidth = width / columns
    val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    val font = (if (columns > 1) 9 else 12) + style.font
    for (column in 0 until columns) {
        val date = (today.clone() as java.util.Calendar).apply { add(java.util.Calendar.DAY_OF_MONTH, column) }
        val dayItems = if (columns == 1) items else items.filter { it.date == widgetDate(date).takeLast(5) }
        val left = (column * columnWidth + 4).toFloat()
        val top = if (columns > 1) 20 else 0
        if (columns > 1) drawWidgetText(canvas, listOf("今天", "明天", "后天")[column], left, 0f, columnWidth - 8, 18, 10f, Layout.Alignment.ALIGN_NORMAL)
        if (dayItems.isEmpty()) drawWidgetText(canvas, "暂无课程", left, top + 8f, columnWidth - 8, 40, 12f, Layout.Alignment.ALIGN_NORMAL)
        val rowHeight = if (height < 180 || columns > 1) 48 else 76
        val rows = ((height - top - 12) / rowHeight).coerceAtLeast(1)
        dayItems.take(rows).forEachIndexed { index, item ->
            val y = (top + index * rowHeight).toFloat()
            paint.color = courseColor(item.course)
            canvas.drawRoundRect(RectF(left, y + 2, left + (if (filled) columnWidth - 8 else 4).toFloat(), y + rowHeight - 6), 4f, 4f, paint)
            val prefix = if (days > 1 && columns == 1) "${item.date} " else ""
            val titleHeight = if (rowHeight == 48) 16 else 32
            drawWidgetText(canvas, prefix + item.course.title, left + 10, y + 2, columnWidth - 22, titleHeight, font.toFloat() + 1, Layout.Alignment.ALIGN_NORMAL, bold = true)
            drawWidgetText(canvas, item.course.place.orEmpty(), left + 10, y + titleHeight + 2, columnWidth - 22, 14, font.toFloat() - 1, Layout.Alignment.ALIGN_NORMAL)
            if (style.timeline) drawWidgetText(canvas, "${item.start}–${item.end}", left + 10, y + titleHeight + 16, columnWidth - 22, 14, font.toFloat() - 2, Layout.Alignment.ALIGN_NORMAL)
        }
        if (dayItems.size > rows) drawWidgetText(canvas, "另 ${dayItems.size - rows} 门 · 点击查看", left, (height - 15).toFloat(), columnWidth - 8, 15, 9f, Layout.Alignment.ALIGN_NORMAL)
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
    bold: Boolean = false,
) {
    if (width <= 0 || height <= 0) return
    val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.rgb(35, 57, 82)
        textSize = size
        isFakeBoldText = bold
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
