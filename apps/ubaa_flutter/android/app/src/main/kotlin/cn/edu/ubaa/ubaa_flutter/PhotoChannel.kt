package cn.edu.ubaa.ubaa_flutter

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** System camera/gallery only. No account, network, or school protocol access. */
class PhotoChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "cn.edu.buaa.ubaa/platform")
    private var pending: MethodChannel.Result? = null
    private var capture: File? = null
    private var dialog: AlertDialog? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "photo.capability" -> result.success(true)
                // System pickers grant access only to the item chosen by the user.
                "permission.request" -> result.success(
                    if (call.arguments == "photos" || call.arguments == "files") "granted" else "unavailable"
                )
                "photo.pick" -> {
                    if (pending != null) {
                        result.error("photo_busy", "Photo selection is already open", null)
                    } else {
                        pending = result
                        dialog = AlertDialog.Builder(activity)
                            .setTitle("添加打卡照片")
                            .setItems(arrayOf("拍照", "从相册选择")) { _, index -> launch(index == 0) }
                            .setOnCancelListener { finish(null) }
                            .show()
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun launch(camera: Boolean) {
        try {
            val intent = if (camera) {
                val directory = File(activity.cacheDir, "photo_capture").apply { mkdirs() }
                val file = File.createTempFile("capture-", ".jpg", directory)
                capture = file
                val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.photos", file)
                Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
                    putExtra(MediaStore.EXTRA_OUTPUT, uri)
                    clipData = android.content.ClipData.newRawUri("photo", uri)
                    addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
            } else {
                Intent(Intent.ACTION_GET_CONTENT).apply {
                    type = "image/*"
                    addCategory(Intent.CATEGORY_OPENABLE)
                    putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/jpeg", "image/png", "image/webp"))
                }
            }
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, REQUEST)
        } catch (_: Exception) {
            pending?.error("photo_unavailable", "Cannot open camera or gallery", null)
            cleanup()
        }
    }

    fun onActivityResult(request: Int, code: Int, data: Intent?): Boolean {
        if (request != REQUEST) return false
        if (pending == null) return true
        if (code != Activity.RESULT_OK) {
            finish(null)
            return true
        }
        try {
            val file = capture
            val uri = data?.data
            val mime = if (file != null) "image/jpeg" else uri?.let { activity.contentResolver.getType(it) }
            val extension = when (mime) {
                "image/jpeg" -> "jpg"
                "image/png" -> "png"
                "image/webp" -> "webp"
                else -> throw IllegalArgumentException()
            }
            val stream = file?.inputStream() ?: uri?.let { activity.contentResolver.openInputStream(it) }
                ?: throw IllegalArgumentException()
            val bytes = stream.use { input ->
                val output = java.io.ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    if (output.size() + count > MAX_BYTES) throw IllegalArgumentException()
                    output.write(buffer, 0, count)
                }
                output.toByteArray()
            }
            require(bytes.isNotEmpty())
            finish(mapOf("bytes" to bytes, "fileName" to "photo.$extension", "mimeType" to mime))
        } catch (_: Exception) {
            pending?.error("photo_invalid", "Cannot read photo (maximum 10 MiB)", null)
            cleanup()
        }
        return true
    }

    private fun finish(value: Any?) {
        pending?.success(value)
        cleanup()
    }

    private fun cleanup() {
        pending = null
        capture?.delete()
        capture = null
    }

    fun close() {
        dialog?.dismiss()
        dialog = null
        finish(null)
        channel.setMethodCallHandler(null)
    }

    companion object {
        private const val REQUEST = 8241
        private const val MAX_BYTES = 10 * 1024 * 1024
    }
}
