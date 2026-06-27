package com.vi5hnu.pdf_craft

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Receives files opened into the app from other apps:
 *  - ACTION_VIEW          ("Open with PDF Craft")
 *  - ACTION_SEND          (share a single file)
 *  - ACTION_SEND_MULTIPLE (share multiple files)
 *
 * Incoming content:// URIs are copied into the app cache so the Dart layer can
 * read them as plain files. Implemented with no third-party plugin to keep the
 * APK small and the behaviour fully under our control:
 *  - a MethodChannel returns the file(s) that cold-started the app, and
 *  - an EventChannel streams files delivered while the app is already running.
 */
class MainActivity : FlutterActivity() {
    private val methodChannelName = "com.vi5hnu.pdf_craft/incoming_files"
    private val eventChannelName = "com.vi5hnu.pdf_craft/incoming_files_events"

    private var eventSink: EventChannel.EventSink? = null

    // File paths from the intent that launched the app (consumed once by Dart).
    private var initialPaths: List<String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "getInitialFiles") {
                    result.success(initialPaths)
                    initialPaths = null
                } else {
                    result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        // The intent that started this Activity (cold start).
        initialPaths = extractPaths(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val paths = extractPaths(intent)
        if (paths.isNotEmpty()) eventSink?.success(paths)
    }

    /** Resolves the file paths carried by a VIEW/SEND/SEND_MULTIPLE intent. */
    private fun extractPaths(intent: Intent?): List<String> {
        if (intent == null) return emptyList()
        val uris: List<Uri> = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data?.let { listOf(it) } ?: emptyList()
            Intent.ACTION_SEND -> getStreamExtra(intent)?.let { listOf(it) } ?: emptyList()
            Intent.ACTION_SEND_MULTIPLE -> getStreamExtras(intent)
            else -> emptyList()
        }
        return uris.mapNotNull { copyUriToCache(it) }
    }

    @Suppress("DEPRECATION")
    private fun getStreamExtra(intent: Intent): Uri? =
        intent.getParcelableExtra(Intent.EXTRA_STREAM)

    @Suppress("DEPRECATION")
    private fun getStreamExtras(intent: Intent): List<Uri> =
        intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM) ?: emptyList()

    /** Copies a content/file URI into cache and returns the local path. */
    private fun copyUriToCache(uri: Uri): String? {
        return try {
            if (uri.scheme == "file") return uri.path
            val name = queryDisplayName(uri) ?: "shared_${System.currentTimeMillis()}"
            val outFile = File(cacheDir, name)
            contentResolver.openInputStream(uri)?.use { input ->
                outFile.outputStream().use { output -> input.copyTo(output) }
            } ?: return null
            outFile.absolutePath
        } catch (e: Exception) {
            null
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && cursor.moveToFirst()) return cursor.getString(index)
        }
        return null
    }
}
