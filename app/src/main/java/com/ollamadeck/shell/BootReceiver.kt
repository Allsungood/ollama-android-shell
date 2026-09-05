package com.ollamadeck.shell

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Restore the foreground bridge service after a reboot, respecting the prior state. */
class BootReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
      BridgeService.start(context)
    }
  }
}