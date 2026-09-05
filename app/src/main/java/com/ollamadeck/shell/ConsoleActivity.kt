package com.ollamadeck.shell

import android.app.Activity
import android.content.Intent
import android.content.pm.ActivityInfo
import android.os.Bundle
import android.webkit.WebView
import android.webkit.WebViewClient

/** Built-in Termux console (bundled assets/console.html) for diagnostics. */
class ConsoleActivity : Activity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
    val wv = WebView(this)
    wv.settings.javaScriptEnabled = true
    wv.settings.domStorageEnabled = true
    wv.settings.allowFileAccess = true
    wv.webViewClient = object : WebViewClient() {}
    setContentView(wv)
    wv.loadUrl("file:///android_asset/console.html")
  }

  companion object {
    fun open(ctx: Activity) {
      ctx.startActivity(Intent(ctx, ConsoleActivity::class.java))
    }
  }
}