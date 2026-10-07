package com.vi5hnu.pdf_craft

import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.util.Log
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

    // URIs from the intent that launched the app, consumed once by Dart. Held as URIs rather
    // than copied paths because copying is file I/O: doing it in configureFlutterEngine put the
    // whole copy on the main thread before the first frame, so sharing a large PDF stalled the
    // app's start. The copy now happens on a worker when Dart asks.
    private var initialUris: List<Uri>? = null

    private val io = java.util.concurrent.Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "getInitialFiles") {
                    val uris = initialUris
                    initialUris = null
                    if (uris.isNullOrEmpty()) {
                        result.success(report(emptyList(), 0))
                    } else {
                        io.execute {
                            val paths = uris.mapNotNull { copyUriToCache(it) }
                            main.post { result.success(report(paths, uris.size)) }
                        }
                    }
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

        // The intent that started this Activity (cold start). Only the URIs are read here; the
        // copying is deferred to the worker above.
        initialUris = extractUris(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val uris = extractUris(intent)
        if (uris.isEmpty()) return
        // Off the main thread for the same reason as the cold-start path: a shared file can be
        // large, and this runs while the user is looking at the app.
        io.execute {
            val paths = uris.mapNotNull { copyUriToCache(it) }
            // Sent even when nothing could be copied: "we were handed files and could read none
            // of them" is the case the user most needs told, and it used to be indistinguishable
            // from "nothing was shared".
            main.post { eventSink?.success(report(paths, uris.size)) }
        }
    }

    override fun onDestroy() {
        io.shutdown()
        super.onDestroy()
    }

    /**
     * What Dart receives: the paths that were successfully copied, and how many files the intent
     * actually carried. The difference between the two is what lets the app say "that file could
     * not be read" instead of silently doing nothing.
     */
    private fun report(paths: List<String>, attempted: Int): Map<String, Any> =
        mapOf("paths" to paths, "attempted" to attempted)

    /** The URIs carried by a VIEW/SEND/SEND_MULTIPLE intent. No I/O. */
    private fun extractUris(intent: Intent?): List<Uri> {
        if (intent == null) return emptyList()
        return when (intent.action) {
            Intent.ACTION_VIEW -> intent.data?.let { listOf(it) } ?: emptyList()
            Intent.ACTION_SEND -> getStreamExtra(intent)?.let { listOf(it) } ?: emptyList()
            Intent.ACTION_SEND_MULTIPLE -> getStreamExtras(intent)
            else -> emptyList()
        }
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
            // Was a bare `null`. A failed copy then looked exactly like "nothing was shared", so
            // the Dart side could not tell the user anything and the file vanished without trace.
            Log.w("PdfCraft", "Could not copy shared file $uri into cache", e)
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
