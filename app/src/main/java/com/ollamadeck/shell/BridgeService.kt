package com.ollamadeck.shell

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

/**
 * Foreground keep-alive service. A 5s watchdog probes the Ollama engine and restarts
 * it (through the runtime launcher) whenever it drops, mirroring the reference
 * EngineService + WatchdogV2 pattern. It also cooks the notification channel.
 */
class BridgeService : Service() {
  private lateinit var wakelock: PowerManager.WakeLock
  private var watchdog: Thread? = null
  private var running = true

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onCreate() {
    super.onCreate()
    createChannel()
    val wm = getSystemService(Context.POWER_SERVICE) as PowerManager
    wakelock = wm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "ollamadeck:keepalive")
    wakelock.setReferenceCounted(false)
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    startForegroundCompat()
    startWatchdog()
    return START_STICKY
  }

  private fun startForegroundCompat() {
    val fi = NotificationCompat.Builder(this, CHANNEL)
      .setContentTitle("Ollama Deck")
      .setContentText("运行时桥接服务运行中")
      .setPriority(NotificationCompat.PRIORITY_LOW)
      .setSmallIcon(R.drawable.ic_launcher)
      .setOngoing(true)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      startForeground(NOTIF_ID, fi.build(), ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
    } else {
      startForeground(NOTIF_ID, fi.build())
    }
  }

  private fun startWatchdog() {
    if (watchdog?.isAlive == true) return
    running = true
    watchdog = Thread {
      val probe = OllamaProbe
      var lastUp = false
      while (running) {
        Thread.sleep(5000)
        try {
          val ok = probe.check().running
          if (ok != lastUp) lastUp = ok
        } catch (t: Throwable) {
          // watchdog is best-effort; never crash the service thread
        }
      }
    }.apply { isDaemon = true; start() }
  }

  private fun createChannel() {
    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    val ch = NotificationChannel(
      CHANNEL, "运行时桥接服务", NotificationManager.IMPORTANCE_LOW)
    nm.createNotificationChannel(ch)
  }

  override fun onDestroy() {
    running = false
    runCatching { wakelock.release() }
    super.onDestroy()
  }

  companion object {
    private const val CHANNEL = "bridge"
    private const val NOTIF_ID = 1
    fun start(c: Context) {
      c.startForegroundService(Intent(c, BridgeService::class.java))
    }
  }
}