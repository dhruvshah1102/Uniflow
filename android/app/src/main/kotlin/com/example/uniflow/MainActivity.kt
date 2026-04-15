package com.example.uniflow

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val attendanceExportChannel = "uniflow/attendance_export"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, attendanceExportChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveAttendanceExcel" -> {
                        try {
                            val fileName = call.argument<String>("fileName")
                            val bytes = call.argument<ByteArray>("bytes")

                            if (fileName.isNullOrBlank()) {
                                result.error("INVALID_ARGUMENT", "Missing fileName", null)
                                return@setMethodCallHandler
                            }
                            if (bytes == null || bytes.isEmpty()) {
                                result.error("INVALID_ARGUMENT", "Missing file bytes", null)
                                return@setMethodCallHandler
                            }

                            val savedPath = saveToDownloads(fileName, bytes)
                            result.success(savedPath)
                        } catch (e: Exception) {
                            result.error("SAVE_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun saveToDownloads(fileName: String, bytes: ByteArray): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return saveToDownloadsScoped(fileName, bytes)
        }
        return saveToDownloadsLegacy(fileName, bytes)
    }

    private fun saveToDownloadsScoped(fileName: String, bytes: ByteArray): String {
        val relativePath = "${Environment.DIRECTORY_DOWNLOADS}${File.separator}Uniflow"
        val resolver = applicationContext.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
            put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }

        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("Unable to create download entry")

        resolver.openOutputStream(uri)?.use { output ->
            output.write(bytes)
            output.flush()
        } ?: throw IllegalStateException("Unable to open output stream")

        values.clear()
        values.put(MediaStore.MediaColumns.IS_PENDING, 0)
        resolver.update(uri, values, null, null)

        return "Downloads/Uniflow/$fileName"
    }

    private fun saveToDownloadsLegacy(fileName: String, bytes: ByteArray): String {
        val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        val targetDir = File(downloadsDir, "Uniflow")
        if (!targetDir.exists()) {
            targetDir.mkdirs()
        }

        val file = File(targetDir, fileName)
        FileOutputStream(file).use { output ->
            output.write(bytes)
            output.flush()
        }

        return file.absolutePath
    }
}
