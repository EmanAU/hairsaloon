package com.barbershop.app

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "hairsaloon/whatsapp_share"
    private val mainHandler = Handler(Looper.getMainLooper())

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

    private fun resolveWhatsAppPackage(): String? {
        val candidates = listOf("com.whatsapp", "com.whatsapp.w4b")
        return candidates.firstOrNull { pkg ->
            try {
                packageManager.getPackageInfo(pkg, 0)
                true
            } catch (_: PackageManager.NameNotFoundException) {
                false
            }
        }
    }

    private fun shareToWhatsApp(phone: String, text: String, filePath: String?) {
        val pkg = resolveWhatsAppPackage() ?: throw ActivityNotFoundException()

        // Text-only: Click-to-Chat works for numbers that are not saved contacts.
        if (filePath.isNullOrBlank()) {
            val encoded = Uri.encode(text)
            val url = if (phone.isNotBlank()) {
                "https://api.whatsapp.com/send?phone=$phone&text=$encoded"
            } else {
                "https://api.whatsapp.com/send?text=$encoded"
            }
            startActivity(
                Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                    setPackage(pkg)
                },
            )
            return
        }

        val file = File(filePath)
        if (!file.exists()) {
            throw IllegalArgumentException("Receipt image file not found.")
        }
        val uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            file,
        )
        grantUriPermission(pkg, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)

        if (phone.isBlank()) {
            startActivity(buildImageShareIntent(pkg, uri, text, jidPhone = null))
            return
        }

        // Unsaved WhatsApp numbers often open an empty chat when ACTION_SEND+jid
        // runs alone. Seed the thread via Click-to-Chat, then send the image to
        // the same jid — same end state as a saved contact.
        try {
            startActivity(
                Intent(
                    Intent.ACTION_VIEW,
                    Uri.parse("https://api.whatsapp.com/send?phone=$phone"),
                ).apply {
                    setPackage(pkg)
                },
            )
        } catch (_: Exception) {
            // Still attempt the image share below.
        }

        mainHandler.postDelayed({
            try {
                startActivity(buildImageShareIntent(pkg, uri, text, jidPhone = phone))
            } catch (_: Exception) {
                // Seed chat already opened; avoid crashing the activity.
            }
        }, 700)
    }

    private fun buildImageShareIntent(
        pkg: String,
        uri: Uri,
        text: String,
        jidPhone: String?,
    ): Intent {
        return Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, uri)
            if (text.isNotBlank()) {
                putExtra(Intent.EXTRA_TEXT, text)
            }
            if (!jidPhone.isNullOrBlank()) {
                putExtra("jid", "$jidPhone@s.whatsapp.net")
            }
            setPackage(pkg)
            clipData = ClipData.newUri(contentResolver, "receipt", uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
    }
}
