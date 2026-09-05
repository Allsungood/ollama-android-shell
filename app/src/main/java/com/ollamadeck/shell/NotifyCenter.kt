package com.ollamadeck.shell

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import androidx.core.app.NotificationCompat

/** Task-completion / status notifications surfaced from the page (POST_NOTIFICATIONS). */
object NotifyCenter {
  private const val CHANNEL = "tasks"

  fun show(ctx: Context, title: String, text: String) {
    val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    nm.createNotificationChannel(NotificationChannel(CHANNEL, "任务通知", NotificationManager.IMPORTANCE_DEFAULT))
    val id = (System.currentTimeMillis() % Int.MAX_VALUE).toInt()
    val n = NotificationCompat.Builder(ctx, CHANNEL)
      .setContentTitle(title)
      .setContentText(text)
      .setSmallIcon(R.drawable.ic_launcher)
      .setAutoCancel(true)
      .build()
    runCatching { nm.notify(id, n) }
  }
}