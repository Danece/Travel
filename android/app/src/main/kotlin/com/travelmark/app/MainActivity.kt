package com.travelmark.app

import android.content.ContentValues
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.travelmark.app/downloads"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveToDownloads" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val filename = call.argument<String>("filename")
                        if (bytes == null || filename == null) {
                            result.error("INVALID_ARGS", "bytes 和 filename 不可為空", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val path = saveToDownloads(bytes, filename)
                            result.success(path)
                        } catch (e: Exception) {
                            result.error("SAVE_ERROR", e.message, null)
                        }
                    }
                    "readFileBytes" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("INVALID_ARGS", "path 不可為空", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val bytes = readFileBytes(path)
                            result.success(bytes)
                        } catch (e: Exception) {
                            result.error("READ_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun readFileBytes(path: String): ByteArray {
        // 1. 先讀取（content URI 或一般路徑）
        val bytes = readRaw(path)

        // 2. 若結果是 PDF（雲端 Document Provider 回傳預覽版），改從本機 Downloads 讀取
        if (bytes.isPdf()) {
            android.util.Log.d("TravelMark", "Got PDF bytes, trying local Downloads fallback")
            val filename = path.substringAfterLast("/").substringAfterLast("%2F")
            val downloadsPath = "${Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)}/$filename"
            android.util.Log.d("TravelMark", "Trying local path: $downloadsPath")
            val localFile = File(downloadsPath)
            if (localFile.exists()) {
                val localBytes = localFile.readBytes()
                if (!localBytes.isPdf()) return localBytes
            }
        }

        return bytes
    }

    private fun readRaw(path: String): ByteArray {
        if (path.startsWith("content://")) {
            val uri = Uri.parse(path)
            // 先嘗試從 document ID 解析真正的磁碟路徑
            val realPath = resolveRealPath(uri)
            if (realPath != null) {
                val f = File(realPath)
                if (f.exists()) {
                    val b = f.readBytes()
                    if (!b.isPdf()) return b
                }
            }
            return contentResolver.openInputStream(uri)?.use { it.readBytes() }
                ?: throw Exception("無法開啟 content URI 串流：$path")
        }
        return File(path).readBytes()
    }

    private fun resolveRealPath(uri: Uri): String? {
        return try {
            val docId = android.provider.DocumentsContract.getDocumentId(uri)
            when {
                docId.startsWith("raw:") -> docId.removePrefix("raw:")
                docId.startsWith("primary:") ->
                    "/storage/emulated/0/${docId.removePrefix("primary:")}"
                else -> null
            }
        } catch (_: Exception) { null }
    }

    private fun ByteArray.isPdf() = size >= 4 &&
            this[0] == 0x25.toByte() && this[1] == 0x50.toByte() &&
            this[2] == 0x44.toByte() && this[3] == 0x46.toByte()

    private fun saveToDownloads(bytes: ByteArray, filename: String): String {
        val mimeType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+：透過 MediaStore 寫入公開 Downloads 資料夾
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, filename)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw Exception("無法建立 Downloads 項目")

            resolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw Exception("無法開啟輸出串流")

            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)

            "${Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)}/$filename"
        } else {
            // Android 9 以下：直接寫入 Downloads 目錄
            val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!downloadsDir.exists()) downloadsDir.mkdirs()
            val file = File(downloadsDir, filename)
            FileOutputStream(file).use { it.write(bytes) }
            file.absolutePath
        }
    }
}
