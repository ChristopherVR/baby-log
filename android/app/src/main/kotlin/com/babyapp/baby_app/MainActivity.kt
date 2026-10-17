package com.babyapp.baby_app

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import java.lang.ref.WeakReference

/// Uses the shared engine from [Background] so the Dart side (data + sync
/// server) outlives the activity while the sync service is running.
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        Background.engine(this)
        super.onCreate(savedInstanceState)
        current = WeakReference(this)
        showOverLockScreenForAlarm(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        showOverLockScreenForAlarm(intent)
    }

    override fun getCachedEngineId(): String = Background.ENGINE_ID

    /// Opened by a ringing alarm (its payload says "alarm":true): show over the
    /// lock screen and turn the screen on, like an alarm clock. Only then, so
    /// the log is never visible on a locked phone otherwise.
    private fun showOverLockScreenForAlarm(intent: Intent?) {
        val payload = intent?.getStringExtra("payload") ?: return
        if (!payload.contains("\"alarm\":true")) return
        setLockScreen(true)
    }

    fun setLockScreen(on: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(on)
            setTurnScreenOn(on)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (on) window.addFlags(flags) else window.clearFlags(flags)
        }
    }

    companion object {
        var current: WeakReference<MainActivity>? = null
    }
}
