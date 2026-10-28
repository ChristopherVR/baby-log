package com.babyapp.baby_app

import android.content.Context

/// The GitHub build syncs through its foreground service (see SyncService.kt).
object PeriodicSync {
    fun schedule(context: Context) {}

    fun cancel(context: Context) {}
}
