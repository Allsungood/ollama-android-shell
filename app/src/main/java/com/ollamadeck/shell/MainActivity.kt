package com.ollamadeck.shell

import android.Manifest
import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.View
import android.view.ViewGroup
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import org.json.JSONObject
import java.util.concurrent.Executors

/**
 * Shell activity. Hosts the WebView that renders either the onboarding/guide UI
 * (assets/webui/index.html) before bootstrap, or the Open WebUI mount once the
 * engine is up. Injects the [OllamaBridge] as window.androidBridge.
 *
 * Mirrors MainActivity.kt from the reference shell; the runtime here is
 * Termux + ollama + open-webui instead of a DeepSeek Harness snapshot.
 */
class MainActivity : Activity() {
  private lateinit var webView: WebView
  private lateinit var runtime: RuntimeManager
  private lateinit var bootstrap: BootstrapManager
  private val executor = Executors.newSingleThreadExecutor()

  // Bootstrap progress pushed to the page on the main thread.
  @Volatile private var bootstrapProgress: String? = null
  @Volatile private var bootstrapRunning = false
  @Volatile private var bootstrapDone = false
  @Volatile private var bootstrapError: String? = null

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    runtime = RuntimeManager(this)
    bootstrap = BootstrapManager(this)
    createdWebView()
    requestPermissions()
    BridgeService.start(this)
    runtime.extractIfNeeded { bootstrapProgress = it }
    if (runtime.needsBootstrap()) showGuide() else openUi()
  }

  private fun createdWebView() {
    webView = WebView(this)
    webView.layoutParams = FrameLayout.LayoutParams(
      ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
    setContentView(webView)
    setUpWebView()
    wireBridge()
  }

  private fun setUpWebView() {
    val ws = webView.settings
    ws.javaScriptEnabled = true
    ws.domStorageEnabled = true
    ws.allowFileAccess = true
    ws.allowContentAccess = true
    ws.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
    ws.setSupportZoom(true)
    ws.builtInZoomControls = true
    ws.displayZoomControls = false
    webView.webViewClient = object : WebViewClient() { /* keep page inside the shell */ }
  }

  private fun bridge(): OllamaBridge = OllamaBridge(
    onKeepScreen = { on ->
      val flag = android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
      if (on) window.addFlags(flag) else window.clearFlags(flag)
    },
    onNotify = { t, x -> NotifyCenter.show(this, t, x) },
    onAllFilesAccessRequest = { grantAllFiles() },
    onDebugLogsRequest = { LogCollector.export(this, runtime) },
    onSetTextZoomRequest = { webView.settings.textZoom = it },
    onCopyTextRequest = { t -> copyText(t, this) },
    onRestartEngine = { restart() },
    onShutdownToGuide = { showGuide() },
    onReloadWebUI = { webView.post { openUi() } },
    onOpenConsole = { ConsoleActivity.open(this) },
    onStartBootstrap = { startBootstrap() },
    onBootstrapStatus = { bootstrapStatusJson() },
    config = object : ConfigProvider {
      override fun mirror(): String = bootstrap.loadConfig().optString("mirror", "auto")
      override fun setMirror(name: String) = bootstrap.persistConfig(name, language())
      override fun language(): String = bootstrap.loadConfig().optString("language", "zh-Hans")
      override fun setLanguage(code: String) = bootstrap.persistConfig(mirror(), code)
    },
  )

  private fun wireBridge() {
    webView.addJavascriptInterface(bridge(), "androidBridge")
  }

  private fun startBootstrap() {
    bootstrapRunning = true
    bootstrapDone = false
    bootstrapError = null
    executor.execute {
      val ok = bootstrap.run(runtime) { msg ->
        bootstrapProgress = msg
        pushProgress(msg)
      }
      bootstrapRunning = false
      bootstrapDone = ok
      if (ok) {
        bootstrap.startServices(runtime) { bootstrapProgress = it }
        runOnUiThread { openUi() }
      }
    }
  }

  private fun pushProgress(msg: String) {
    runOnUiThread {
      val json = JSONObject().let { o ->
        o.put("progress", msg)
        o.put("done", false).put("running", true)
        o.toString()
      }
      webView.evaluateJavascript("window.__deck?.onProgress?.(${json})", null)
    }
  }

  private fun bootstrapStatusJson(): String = JSONObject()
    .put("done", bootstrapDone)
    .put("running", bootstrapRunning)
    .put("error", bootstrapError ?: JSONObject.NULL)
    .put("progress", bootstrapProgress ?: JSONObject.NULL)
    .toString()

  /** Open Web UI entry (the mounted web interface). */
  private fun openUi() {
    val start = System.currentTimeMillis()
    webView.post {
      if (OllamaProbe.check().running) {
        webView.loadUrl("http://127.0.0.1:8080")
      } else {
        // engine still coming up; fall back to the bundled UI which shows a spinner
        webView.loadUrl("file:///android_asset/webui/index.html?bootstrapping=1")
      }
      val _ = start
    }
  }

  private fun showGuide() {
    webView.post { webView.loadUrl("file:///android_asset/webui/index.html") }
  }

  private fun restart() { runtime.markBootstrapDone() /* re-run setup on demand */ }

  private fun grantAllFiles() {
    if (Build.VERSION.SDK_INT >= 30) {
      startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
    }
  }

  override fun onResume() {
    super.onResume()
    // After returning from the All-Files-Access settings page, refresh page state.
    if (::webView.isInitialized) webView.post { openUi() }
  }

  private fun requestPermissions() {
    if (Build.VERSION.SDK_INT >= 33 &&
      ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
      != PackageManager.PERMISSION_GRANTED) {
      ActivityCompat.requestPermissions(
        this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
    }
  }

  override fun onBackPressed() {
    if (webView.canGoBack()) webView.goBack() else super.onBackPressed()
  }

  override fun onDestroy() {
    executor.shutdownNow()
    super.onDestroy()
  }

  companion object {
    fun copyText(text: String, ctx: Context): Boolean = try {
      val cm = ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
      cm.setPrimaryClip(ClipData.newPlainText("ollamadeck", text))
      true
    } catch (e: Exception) {
      false
    }
  }
}