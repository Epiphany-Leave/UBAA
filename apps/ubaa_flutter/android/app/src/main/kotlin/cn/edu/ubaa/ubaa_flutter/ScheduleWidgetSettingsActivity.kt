package cn.edu.ubaa.ubaa_flutter

import android.app.Activity
import android.app.AlertDialog
import android.appwidget.AppWidgetManager
import android.os.Bundle
import android.widget.ArrayAdapter
import android.widget.CheckBox
import android.widget.LinearLayout
import android.widget.Spinner
import android.widget.TextView

/** Only edits display preferences for this widget; never reads sessions or requests school data. */
class ScheduleWidgetSettingsActivity : Activity() {
    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1)
        val provider = AppWidgetManager.getInstance(this).getAppWidgetInfo(id)?.provider
        if (provider?.packageName != packageName) { finish(); return }
        val preferences = getSharedPreferences("schedule_widgets", MODE_PRIVATE)
        val semesters = ScheduleWidgetSnapshot.read(this)?.semesters.orEmpty()
        val terms = listOf("") + semesters.map { it.term }
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 12, 32, 8)
        }
        fun picker(label: String, choices: List<String>, index: Int): Spinner {
            content.addView(TextView(this).apply { text = label; setPadding(0, 20, 0, 4) })
            return Spinner(this).also {
                it.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, choices)
                it.setSelection(index.coerceIn(0, choices.lastIndex))
                content.addView(it)
            }
        }
        val term = picker("显示课表", listOf("跟随 App 当前课表") + semesters.map { it.name }, terms.indexOf(preferences.getString("$id-fixedTerm", "")))
        val background = picker("背景", listOf("纯白", "暖色", "透明"), preferences.getInt("$id-background", 0))
        val font = picker("课程字号", listOf("小", "标准", "大"), preferences.getInt("$id-font", 1))
        fun toggle(label: String, key: String) = CheckBox(this).apply {
            text = label
            isChecked = preferences.getBoolean("$id-$key", true)
            content.addView(this)
        }
        val timeline = toggle("显示课程时间", "timeline")
        val weekends = if (provider.className == ScheduleWidgetProvider::class.java.name) toggle("显示周末", "weekends") else null
        AlertDialog.Builder(this).setTitle("小组件设置").setView(content)
            .setNegativeButton("取消") { _, _ -> finish() }
            .setPositiveButton("保存") { _, _ ->
                preferences.edit().putString("$id-fixedTerm", terms[term.selectedItemPosition])
                    .putInt("$id-background", background.selectedItemPosition)
                    .putInt("$id-font", font.selectedItemPosition)
                    .putBoolean("$id-timeline", timeline.isChecked)
                    .putBoolean("$id-weekends", weekends?.isChecked ?: true)
                    .remove("$id-anchor").remove("$id-offset").apply()
                ScheduleWidgetProvider.requestRefresh(this)
                finish()
            }.setOnCancelListener { finish() }.show()
    }
}
