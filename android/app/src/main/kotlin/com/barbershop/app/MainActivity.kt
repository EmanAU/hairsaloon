package com.barbershop.app

import android.content.ActivityNotFoundException
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "hairsaloon/whatsapp_share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "shareToWhatsApp") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val phone = call.argument<String>("phone")?.trim().orEmpty()
                val text = call.argument<String>("text").orEmpty()
                val filePath = call.argument<String>("filePath")
                try {
                    shareToWhatsApp(phone = phone, text = text, filePath = filePath)
                    result.success(true)
                } catch (e: ActivityNotFoundException) {
                    result.error("NO_WHATSAPP", "WhatsApp is not installed.", null)
                } catch (e: Exception) {
                    result.error("SHARE_FAILED", e.message, null)
                }
            }
    }

    private fun shareToWhatsApp(phone: String, text: String, filePath: String?) {
        val intent = Intent(Intent.ACTION_SEND).apply {
            if (!filePath.isNullOrBlank()) {
                val file = File(filePath)
                if (!file.exists()) {
                    throw IllegalArgumentException("Receipt image file not found.")
                }
                val uri = FileProvider.getUriForFile(
                    this@MainActivity,
                    "${applicationContext.packageName}.fileprovider",
                    file,
                )
                type = "image/png"
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } else {
                type = "text/plain"
            }
            if (text.isNotBlank()) {
                putExtra(Intent.EXTRA_TEXT, text)
            }
            if (phone.isNotBlank()) {
                // Pre-select this chat when WhatsApp supports the jid extra.
                putExtra("jid", "$phone@s.whatsapp.net")
            }
        }

        try {
            intent.setPackage("com.whatsapp")
            startActivity(intent)
        } catch (_: ActivityNotFoundException) {
            intent.setPackage("com.whatsapp.w4b")
            startActivity(intent)
        }
    }
}
