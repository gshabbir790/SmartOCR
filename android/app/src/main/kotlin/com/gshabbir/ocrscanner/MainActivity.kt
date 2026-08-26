package com.gshabbir.ocrscanner

import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val channelName = "smart_ocr/share"
    private var initialImages = arrayListOf<String>()
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        )

        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialImages" -> result.success(initialImages)
                else -> result.notImplemented()
            }
        }

        handleIntent(intent, false)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent, true)
    }

    private fun handleIntent(intent: Intent?, notify: Boolean) {
        if (intent == null) return

        val action = intent.action ?: return
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) return

        val uris = ArrayList<Uri>()

        if (action == Intent.ACTION_SEND) {
            val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            }
            uri?.let { uris.add(it) }
        } else {
            val uriList = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
            }
            uriList?.let { uris.addAll(it) }
        }

        // Some gallery/file-manager apps put the shared image in ClipData or
        // data instead of EXTRA_STREAM. Accept all common Android share forms.
        intent.clipData?.let { clip ->
            for (i in 0 until clip.itemCount) {
                clip.getItemAt(i).uri?.let(uris::add)
            }
        }
        intent.data?.let { uris.add(it) }

        val distinctUris = uris.distinct()
        if (distinctUris.isEmpty()) return

        Thread {
            val copied = arrayListOf<String>()
            distinctUris.forEach { uri ->
                try {
                    copyToCache(uri)?.let(copied::add)
                } catch (_: Exception) {
                    // Ignore invalid/unreadable shared URI and continue with
                    // the remaining shared images.
                }
            }

            runOnUiThread {
                initialImages = copied
                if (notify && copied.isNotEmpty()) {
                    channel?.invokeMethod("sharedImages", copied)
                }
            }
        }.start()
    }

    private fun copyToCache(uri: Uri): String? {
        val mime = contentResolver.getType(uri) ?: "image/*"
        if (!mime.startsWith("image/")) return null

        val ext = when (mime.lowercase()) {
            "image/png" -> ".png"
            "image/webp" -> ".webp"
            "image/heic", "image/heif" -> ".heic"
            else -> ".jpg"
        }

        val out = File(cacheDir, "shared_${System.nanoTime()}$ext")
        contentResolver.openInputStream(uri)?.use { input ->
            out.outputStream().use { output -> input.copyTo(output) }
        } ?: return null

        return out.absolutePath
    }
}
