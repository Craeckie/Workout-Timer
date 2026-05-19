package com.craeckie.workouttimer

import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.craeckie.workouttimer/saf",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "writeToTree" -> {
                    val treeUriStr = call.argument<String>("treeUri")
                    val bytes = call.argument<ByteArray>("bytes")
                    val fileName = call.argument<String>("fileName")
                    val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                    try {
                        if (treeUriStr == null || bytes == null || fileName == null) {
                            result.error("INVALID_ARGS", "treeUri, bytes, and fileName are required", null)
                            return@setMethodCallHandler
                        }
                        val treeUri = Uri.parse(treeUriStr)
                        val treeDoc = DocumentFile.fromTreeUri(this, treeUri)
                            ?: throw Exception("Cannot open tree: $treeUriStr")
                        val existing = treeDoc.findFile(fileName)
                        val fileDoc = if (existing != null && existing.exists()) {
                            existing
                        } else {
                            treeDoc.createFile(mimeType, fileName)
                                ?: throw Exception("Cannot create file in tree")
                        }
                        contentResolver.openOutputStream(fileDoc.uri, "wt")?.use { stream ->
                            stream.write(bytes)
                        } ?: throw Exception("Cannot open output stream")
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("WRITE_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
