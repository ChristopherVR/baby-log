package com.babyapp.baby_app

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

object AppUpdates {
    fun register(context: Context, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "babylog/updates").setMethodCallHandler { call, result ->
            if (call.method != "install") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                val activity = MainActivity.current?.get() ?: error("Open the app to update")
                val file = File(call.arguments as? String ?: error("Missing APK")).canonicalFile
                val expected = File(context.cacheDir, "updates/update.apk").canonicalFile
                require(file == expected && file.isFile) { "Invalid update file" }
                verify(context, file)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !context.packageManager.canRequestPackageInstalls()) {
                    activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:${context.packageName}")))
                    result.success(false)
                } else {
                    val uri = FileProvider.getUriForFile(context, "${context.packageName}.updates", file)
                    activity.startActivity(Intent(Intent.ACTION_VIEW)
                        .setDataAndType(uri, "application/vnd.android.package-archive")
                        .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
                    result.success(true)
                }
            } catch (e: Exception) {
                result.error("UPDATE_FAILED", e.message, null)
            }
        }
    }

    /// Verify identity, increasing build code and the existing signing key.
    @Suppress("DEPRECATION")
    private fun verify(context: Context, file: File) {
        val pm = context.packageManager
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
            PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
        val update = pm.getPackageArchiveInfo(file.path, flags) ?: error("Invalid APK")
        val installed = pm.getPackageInfo(context.packageName, flags)
        require(update.packageName == context.packageName) { "Wrong app" }
        val newer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
            update.longVersionCode > installed.longVersionCode else update.versionCode > installed.versionCode
        require(newer) { "Update must have a newer build code" }
        val incoming = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
            update.signingInfo?.apkContentsSigners else update.signatures
        val current = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
            installed.signingInfo?.apkContentsSigners else installed.signatures
        require(!incoming.isNullOrEmpty() && !current.isNullOrEmpty() &&
            incoming.toSet() == current.toSet()) { "Update signing key does not match" }
    }
}
