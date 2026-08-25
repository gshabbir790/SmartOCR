package com.gshabbir.ocrscanner

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val channelName = "smart_ocr/share"
    private var initialImages: ArrayList<String> = arrayListOf()
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel!!.setMethodCallHandler { call, result ->
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
            intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?.let { uris.add(it) }
        } else {
            intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.let { uris.addAll(it) }
        }
        if (uris.isEmpty()) return
        val copied = arrayListOf<String>()
        uris.distinct().forEach { uri ->
            try { copyToCache(uri)?.let(copied::add) } catch (_: Exception) { }
        }
        initialImages = copied
        if (notify && copied.isNotEmpty()) channel?.invokeMethod("sharedImages", copied)
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
        contentResolver.openInputStream(uri)?.use { input -> out.outputStream().use { input.copyTo(it) } } ?: return null
        return out.absolutePath
    }
}
