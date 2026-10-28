package com.babyapp.baby_app

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.concurrent.futures.CallbackToFutureAdapter
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ListenableWorker
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.google.common.util.concurrent.ListenableFuture
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

/// Play build: no foreground service. WorkManager wakes the app about every
/// 15 minutes (its minimum) and the Dart side syncs with the paired phones.
object PeriodicSync {
    private const val NAME = "babylog_periodic_sync"

    fun schedule(context: Context) {
        val request = PeriodicWorkRequestBuilder<SyncWorker>(15, TimeUnit.MINUTES)
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
            .build()
        WorkManager.getInstance(context)
            .enqueueUniquePeriodicWork(NAME, ExistingPeriodicWorkPolicy.KEEP, request)
    }

    fun cancel(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(NAME)
    }
}

class SyncWorker(context: Context, params: WorkerParameters) : ListenableWorker(context, params) {
    override fun startWork(): ListenableFuture<Result> = CallbackToFutureAdapter.getFuture { completer ->
        val main = Handler(Looper.getMainLooper())
        var finished = false
        fun finish(result: Result) = main.post {
            if (!finished) {
                finished = true
                completer.set(result)
            }
        }

        // Dart may still be starting: ask again until it answers.
        fun ask(channel: MethodChannel, attempt: Int) {
            channel.invokeMethod("syncNow", null, object : MethodChannel.Result {
                override fun success(result: Any?) { finish(Result.success()) }
                override fun error(code: String, message: String?, details: Any?) { finish(Result.success()) }
                override fun notImplemented() {
                    if (attempt >= START_ATTEMPTS) finish(Result.success())
                    else main.postDelayed({ if (!finished) ask(channel, attempt + 1) }, START_DELAY)
                }
            })
        }

        main.post {
            try {
                val engine = Background.engine(applicationContext, headless = true)
                ask(MethodChannel(engine.dartExecutor.binaryMessenger, "babylog/background"), 1)
                main.postDelayed({ finish(Result.success()) }, TIMEOUT)
            } catch (e: Exception) {
                android.util.Log.w("BabyLog", "Background sync could not start", e)
                finish(Result.success())
            }
        }
        "background sync"
    }

    private companion object {
        const val START_ATTEMPTS = 30
        const val START_DELAY = 1_000L
        const val TIMEOUT = 2 * 60 * 1000L
    }
}
