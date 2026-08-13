package com.callwhisper.call_whisper

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder

/** Keeps the process at foreground priority during long local transcription. */
class TranscriptionForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createChannel(this)
        startForeground(notificationId, notification(this, intent?.getStringExtra("status") ?: "전사 준비 중"))
        return START_NOT_STICKY
    }

    companion object {
        private const val channelId = "transcription_progress"
        private const val notificationId = 7101

        fun start(context: Context) {
            val intent = Intent(context, TranscriptionForegroundService::class.java).putExtra("status", "오프라인 전사 실행 중")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(intent) else context.startService(intent)
        }
        fun update(context: Context, status: String) {
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.notify(notificationId, notification(context, status))
        }
        fun stop(context: Context) { context.stopService(Intent(context, TranscriptionForegroundService::class.java)) }

        private fun createChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.getSystemService(NotificationManager::class.java).createNotificationChannel(
                    NotificationChannel(channelId, "오프라인 전사", NotificationManager.IMPORTANCE_LOW)
                )
            }
        }
        private fun notification(context: Context, status: String): android.app.Notification {
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                android.app.Notification.Builder(context, channelId)
            } else {
                @Suppress("DEPRECATION") android.app.Notification.Builder(context)
            }
            return builder.setSmallIcon(android.R.drawable.ic_btn_speak_now)
                .setContentTitle("Call Whisper")
                .setContentText(status)
                .setOngoing(true)
                .build()
        }
    }
}
