package cn.edu.ubaa.ubaa_flutter

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

private const val WIDGET_SNAPSHOT_PREFERENCES = "schedule_widget_snapshot"
private const val WIDGET_SNAPSHOT_KEY = "snapshot"
private const val WIDGET_SNAPSHOT_SCHEMA = 1
private const val MAX_SNAPSHOT_CHARS = 1_000_000

internal data class WidgetSchedule(val semesters: List<WidgetSemester>)

internal data class WidgetSemester(
    val term: String,
    val updatedAt: String,
    val weeks: List<WidgetWeek>,
)

internal data class WidgetWeek(
    val number: Int,
    val name: String,
    val start: String?,
    val end: String?,
    val sections: List<WidgetSection>,
    val courses: List<WidgetCourse>,
)

internal data class WidgetSection(val number: Int, val start: String, val end: String)

internal data class WidgetCourse(
    val title: String,
    val place: String?,
    val day: Int?,
    val begin: Int?,
    val end: Int?,
)

/** Flutter 写入的公开桌面课表快照；它不复用 Rust 的私有会话缓存格式。 */
internal object ScheduleWidgetSnapshot {
    fun save(context: Context, raw: Any?) {
        val editor = preferences(context).edit()
        if (raw == null) {
            check(editor.remove(WIDGET_SNAPSHOT_KEY).commit()) { "无法清除桌面课表" }
            return
        }
        val map = raw as? Map<*, *> ?: throw IllegalArgumentException("课表快照格式错误")
        val value = JSONObject(map).toString()
        require(value.length <= MAX_SNAPSHOT_CHARS) { "课表快照过大" }
        check(editor.putString(WIDGET_SNAPSHOT_KEY, value).commit()) { "无法保存桌面课表" }
    }

    fun read(context: Context): WidgetSchedule? = runCatching {
        val raw = preferences(context).getString(WIDGET_SNAPSHOT_KEY, null) ?: return null
        parse(JSONObject(raw))
    }.getOrNull()

    private fun preferences(context: Context) = context.applicationContext.getSharedPreferences(
        WIDGET_SNAPSHOT_PREFERENCES,
        Context.MODE_PRIVATE,
    )

    private fun parse(root: JSONObject): WidgetSchedule? {
        if (root.optInt("schema") != WIDGET_SNAPSHOT_SCHEMA) return null
        val semesters = root.optJSONArray("semesters") ?: return null
        if (semesters.length() > 32) return null
        return WidgetSchedule(
            List(semesters.length()) { index -> parseSemester(semesters.optJSONObject(index)) }
                .filterNotNull(),
        )
    }

    private fun parseSemester(value: JSONObject?): WidgetSemester? {
        value ?: return null
        val term = value.requiredString("term") ?: return null
        val weeks = value.optJSONArray("weeks") ?: return null
        if (weeks.length() > 128) return null
        return WidgetSemester(
            term = term,
            updatedAt = value.optionalString("updatedAt").orEmpty(),
            weeks = List(weeks.length()) { index -> parseWeek(weeks.optJSONObject(index)) }
                .filterNotNull()
                .sortedBy { it.number },
        )
    }

    private fun parseWeek(value: JSONObject?): WidgetWeek? {
        value ?: return null
        val number = value.optionalInt("number") ?: return null
        if (number <= 0) return null
        val sections = value.optJSONArray("sections") ?: return null
        val courses = value.optJSONArray("courses") ?: return null
        if (sections.length() > 32 || courses.length() > 512) return null
        return WidgetWeek(
            number = number,
            name = value.optionalString("name").takeUnless { it.isNullOrEmpty() } ?: "第 $number 周",
            start = value.optionalString("start"),
            end = value.optionalString("end"),
            sections = List(sections.length()) { index -> parseSection(sections.optJSONObject(index)) }
                .filterNotNull()
                .sortedBy { it.number },
            courses = List(courses.length()) { index -> parseCourse(courses.optJSONObject(index)) }
                .filterNotNull(),
        )
    }

    private fun parseSection(value: JSONObject?): WidgetSection? {
        value ?: return null
        val number = value.optionalInt("number") ?: return null
        if (number <= 0) return null
        return WidgetSection(
            number,
            value.optionalString("start").orEmpty(),
            value.optionalString("end").orEmpty(),
        )
    }

    private fun parseCourse(value: JSONObject?): WidgetCourse? {
        value ?: return null
        val title = value.requiredString("title") ?: return null
        return WidgetCourse(
            title = title,
            place = value.optionalString("place"),
            day = value.optionalInt("day"),
            begin = value.optionalInt("begin"),
            end = value.optionalInt("end"),
        )
    }

    private fun JSONObject.requiredString(name: String): String? = optionalString(name)

    private fun JSONObject.optionalString(name: String): String? = opt(name)
        .takeUnless { it == null || it == JSONObject.NULL }
        ?.toString()
        ?.trim()
        ?.takeIf { it.isNotEmpty() }

    private fun JSONObject.optionalInt(name: String): Int? = when (val value = opt(name)) {
        is Number -> value.toInt()
        is String -> value.toIntOrNull()
        else -> null
    }
}
