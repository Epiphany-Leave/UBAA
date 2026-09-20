package cn.edu.ubaa.ubaa_flutter

import android.content.Intent
import android.os.Bundle
import android.os.Build
import android.net.Uri
import android.system.Os
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private external fun initializeTls(context: Any)
    private var widgetChannel: MethodChannel? = null
    private var photoChannel: PhotoChannel? = null
    private var appInformationChannel: MethodChannel? = null
    private var pendingScheduleTarget: Map<String, Any>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        Os.setenv("UBAA_CONFIG_DIR", File(filesDir, "UBAA").absolutePath, true)
        System.loadLibrary("ubaa_flutter_bridge")
        initializeTls(applicationContext)
        pendingScheduleTarget = scheduleTarget(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        photoChannel = PhotoChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        appInformationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "cn.edu.ubaa/app_information",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "version" -> runCatching {
                        val info = packageManager.getPackageInfo(packageName, 0)
                        val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            info.longVersionCode
                        } else {
                            @Suppress("DEPRECATION")
                            info.versionCode.toLong()
                        }
                        "${info.versionName}+$code"
                    }.onSuccess { result.success(it) }
                        .onFailure { result.error("app_version", "Cannot read installed version", null) }
                    "openProject" -> result.success(runCatching {
                        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://github.com/BUAASubnet/UBAA")))
                    }.isSuccess)
                    else -> result.notImplemented()
                }
            }
        }
        widgetChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WIDGET_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "selectTerm" -> {
                        getSharedPreferences("schedule_widgets", MODE_PRIVATE).edit()
                            .putString("activeTerm", call.arguments as? String).apply()
                        ScheduleWidgetProvider.requestRefresh(this)
                        result.success(null)
                    }
                    "syncSchedule" -> runCatching {
                        ScheduleWidgetSnapshot.save(this, call.arguments)
                        ScheduleWidgetProvider.requestRefresh(this)
                    }.onSuccess {
                        result.success(null)
                    }.onFailure { error ->
                        result.error("widget_snapshot", error.message, null)
                    }
                    "consumeLaunchTarget" -> {
                        result.success(pendingScheduleTarget)
                        pendingScheduleTarget = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        scheduleTarget(intent)?.let { target ->
            val channel = widgetChannel
            if (channel == null) {
                pendingScheduleTarget = target
            } else {
                channel.invokeMethod("openSchedule", target)
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (photoChannel?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        photoChannel?.close()
        photoChannel = null
        appInformationChannel?.setMethodCallHandler(null)
        appInformationChannel = null
        widgetChannel?.setMethodCallHandler(null)
        widgetChannel = null
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (photoChannel?.onRequestPermissionsResult(requestCode) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    private fun scheduleTarget(intent: Intent?): Map<String, Any>? {
        val term = intent?.getStringExtra(EXTRA_WIDGET_TERM)?.trim().orEmpty()
        val week = intent?.getIntExtra(EXTRA_WIDGET_WEEK, -1) ?: -1
        return if (term.isEmpty() || week <= 0) null else mapOf("term" to term, "week" to week)
    }

    companion object {
        const val EXTRA_WIDGET_TERM = "cn.edu.ubaa.ubaa_flutter.widget.TERM"
        const val EXTRA_WIDGET_WEEK = "cn.edu.ubaa.ubaa_flutter.widget.WEEK"
        private const val WIDGET_CHANNEL = "cn.edu.ubaa/widget_schedule"
    }
}
