package com.babyapp.baby_app

import android.content.Context
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** The Play variant has no APK installation code or installation provider. */
object AppUpdates {
    fun register(context: Context, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "babylog/updates").setMethodCallHandler { call, result ->
            if (call.method != "openStore") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                val activity = MainActivity.current?.get() ?: error("Open the app first")
                try {
                    activity.startActivity(Intent(Intent.ACTION_VIEW,
                        Uri.parse("market://details?id=${context.packageName}")))
                } catch (_: android.content.ActivityNotFoundException) {
                    activity.startActivity(Intent(Intent.ACTION_VIEW,
                        Uri.parse("https://play.google.com/store/apps/details?id=${context.packageName}")))
                }
                result.success(null)
            } catch (e: Exception) {
                result.error("STORE_FAILED", "Could not open Google Play", null)
            }
        }
    }
}
