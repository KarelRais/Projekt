package com.example.projekt

import android.net.Uri
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "andoped/saf"

    private fun candidateUris(uriOrPath: String): List<Uri> {
        val value = uriOrPath.trim()
        if (value.startsWith("content://")) {
            return listOf(Uri.parse(value))
        }
        if (value.startsWith("/document/")) {
            return listOf(
                Uri.parse("content://com.android.providers.downloads.documents$value"),
                Uri.parse("content://com.android.externalstorage.documents$value"),
                Uri.parse("content://com.android.providers.media.documents$value"),
            )
        }
        return listOf(Uri.parse(value))
    }

    private inline fun <T> firstSuccessfulUri(uriOrPath: String, block: (Uri) -> T): T {
        var lastError: Exception? = null
        for (uri in candidateUris(uriOrPath)) {
            try {
                return block(uri)
            } catch (e: Exception) {
                lastError = e
            }
        }
        throw lastError ?: IllegalStateException("No URI candidates for $uriOrPath")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "persistUri" -> {
                    val uriString = call.argument<String>("uri")
                    if (uriString == null) {
                        result.error("ARGUMENT_ERROR", "Missing uri", null)
                        return@setMethodCallHandler
                    }
                    try {
                        firstSuccessfulUri(uriString) { uri ->
                            val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                            contentResolver.takePersistableUriPermission(uri, flags)
                        }
                        result.success(true)
                    } catch (e: SecurityException) {
                        // Some providers don't allow persistable permissions; treat as non-fatal.
                        result.success(false)
                    } catch (e: Exception) {
                        result.error("PERSIST_FAILED", e.toString(), null)
                    }
                }

                "writeBytes" -> {
                    val uriString = call.argument<String>("uri")
                    val bytes = call.argument<ByteArray>("bytes")
                    if (uriString == null || bytes == null) {
                        result.error("ARGUMENT_ERROR", "Missing uri/bytes", null)
                        return@setMethodCallHandler
                    }
                    try {
                        firstSuccessfulUri(uriString) { uri ->
                            contentResolver.openOutputStream(uri, "wt").use { out ->
                                if (out == null) throw IllegalStateException("openOutputStream returned null")
                                out.write(bytes)
                                out.flush()
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WRITE_FAILED", e.toString(), null)
                    }
                }

                "readText" -> {
                    val uriString = call.argument<String>("uri")
                    if (uriString == null) {
                        result.error("ARGUMENT_ERROR", "Missing uri", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val text = firstSuccessfulUri(uriString) { uri ->
                            contentResolver.openInputStream(uri).use { input ->
                                if (input == null) throw IllegalStateException("openInputStream returned null")
                                input.bufferedReader(Charsets.UTF_8).readText()
                            }
                        }
                        result.success(text)
                    } catch (e: Exception) {
                        result.error("READ_FAILED", e.toString(), null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
