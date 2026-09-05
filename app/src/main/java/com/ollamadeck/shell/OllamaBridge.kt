package com.ollamadeck.shell

import android.net.Uri
import android.webkit.JavascriptInterface
import org.json.JSONArray
import org.json.JSONObject

/**
 * JS bridge exposed to the WebView as window.androidBridge. The WebView talks
 * directly to Ollama's REST API on 127.0.0.1:11434 via fetch; this bridge covers
 * what JS cannot do natively (config persistence, clipboard, notifications, probe).
 *
 * Models the reference shell's protocol, but the "engine probe" targets ollama and
 * the config surface is mirror(multi-source) + language(multi-language), plus
 * bridge-mediated model operations.
 */
class OllamaBridge(
  private val onKeepScreen: (enable: Boolean) -> Unit,
  private val onNotify: (title: String, text: String) -> Unit,
  private val onAllFilesAccessRequest: () -> Unit,
  private val onDebugLogsRequest: () -> Unit,
  private val onSetTextZoomRequest: (percent: Int) -> Unit,
  private val onCopyTextRequest: (text: String) -> Boolean,
  private val onRestartEngine: () -> Unit,
  private val onShutdownToGuide: () -> Unit,
  private val onReloadWebUI: () -> Unit,
  private val onOpenConsole: () -> Unit,
  private val onStartBootstrap: () -> Unit = {},
  private val onBootstrapStatus: () -> String = { """{"done":false,"running":false}""" },
  private val config: ConfigProvider,
) {

  @JavascriptInterface
  fun version(): String = BuildConfig.VERSION_NAME

  @JavascriptInterface
  fun getSystemDark(): Boolean =
    (android.content.res.Configuration.UI_MODE_NIGHT_MASK and
      android.content.res.Configuration.UI_MODE_NIGHT_YES) ==
      android.content.res.Configuration.UI_MODE_NIGHT_YES

  /** Ollama engine probe -> JSON {running, latencyMs, version?, error?}. */
  @JavascriptInterface
  fun checkEngine(): String = toJson(OllamaProbe.check())

  /** Open WebUI probe -> JSON {running, latencyMs, error?}. */
  @JavascriptInterface
  fun checkUi(): String {
    val (running, error) = OllamaProbe.checkUi()
    return JSONObject().put("running", running).put("error", error).toString()
  }

  /** Base URL the page should use for the Ollama REST API. */
  @JavascriptInterface
  fun ollamaBase(): String =
    "http://${OllamaProbe.OLLAMA_HOST}:${OllamaProbe.OLLAMA_PORT}"

  /** Open WebUI entry URL (the mounted web interface). */
  @JavascriptInterface
  fun openwebuiUrl(): String =
    "http://${OllamaProbe.OLLAMA_HOST}:${OllamaProbe.OPENWEBUI_PORT}"

  // ---- multi-language ----
  @JavascriptInterface
  fun getLanguages(): String = Registry.languages().toString()

  @JavascriptInterface
  fun getLanguage(): String = config.language()

  @JavascriptInterface
  fun setLanguage(code: String) {
    config.setLanguage(code)
  }

  // ---- multi-mirror ----
  @JavascriptInterface
  fun getMirrors(): String = Registry.mirrors().toString()

  @JavascriptInterface
  fun getMirror(): String = config.mirror()

  @JavascriptInterface
  fun setMirror(name: String) {
    config.setMirror(name)
  }

  /** Kick off the one-shot Termux/Ollama/Open-WebUI bootstrap (async, streamed to page). */
  @JavascriptInterface
  fun startBootstrap() = onStartBootstrap()

  /** Bootstrap progress status -> JSON {done, running, error?, progress?}. */
  @JavascriptInterface
  fun bootstrapStatus(): String = onBootstrapStatus()

  /** Match an installed model by name substring against /api/tags. */
  @JavascriptInterface
  fun modelSearchLocal(query: String): String {
    val probe = OllamaProbe.check()
    if (!probe.running) return JSONObject().put("ok", false).put("error", "ollama-down").toString()
    return ModelApi.queryTags(query)
  }

  // ---- system ----
  @JavascriptInterface
  fun keepScreenOn(enable: Boolean) = onKeepScreen(enable)

  @JavascriptInterface
  fun showNotification(title: String, text: String) = onNotify(title, text)

  @JavascriptInterface
  fun setTextZoom(percent: Int) = onSetTextZoomRequest(percent)

  @JavascriptInterface
  fun copyText(text: String): Boolean = onCopyTextRequest(text)

  @JavascriptInterface
  fun hasAllFilesAccess(): Boolean =
    android.os.Build.VERSION.SDK_INT >= 30 && android.os.Environment.isExternalStorageManager()

  @JavascriptInterface
  fun requestAllFilesAccess() = onAllFilesAccessRequest()

  @JavascriptInterface
  fun downloadDebugLogs() = onDebugLogsRequest()

  @JavascriptInterface
  fun restartEngine() = onRestartEngine()

  @JavascriptInterface
  fun shutdownToGuide() = onShutdownToGuide()

  @JavascriptInterface
  fun reloadWebUI() = onReloadWebUI()

  @JavascriptInterface
  fun openConsole() = onOpenConsole()

  companion object {
    fun toJson(r: OllamaProbe.Result): String =
      JSONObject()
        .put("running", r.running)
        .put("latencyMs", r.latencyMs)
        .put("version", r.version ?: JSONObject.NULL)
        .put("error", r.error ?: JSONObject.NULL)
        .toString()
  }
}

/** Bridge-accessible persisted config (backed by BootstrapManager). */
interface ConfigProvider {
  fun mirror(): String
  fun setMirror(name: String)
  fun language(): String
  fun setLanguage(code: String)
}

/** Static registry of supported languages and Ollama/model mirrors (pure, testable). */
object Registry {
  fun languages(): JSONArray = JSONArray()
    .put(JSONObject().put("code", "zh-Hans").put("label", "简体中文"))
    .put(JSONObject().put("code", "zh-Hant").put("label", "繁體中文"))
    .put(JSONObject().put("code", "en").put("label", "English"))
    .put(JSONObject().put("code", "ja").put("label", "日本語"))

  fun mirrors(): JSONArray = JSONArray()
    .put(JSONObject().put("id", "auto").put("label", "自动选择").put("url", ""))
    .put(JSONObject().put("id", "official").put("label", "Ollama 官方").put("url", "https://ollama.com"))
    .put(JSONObject().put("id", "github").put("label", "GitHub Releases").put("url", "https://github.com/ollama/ollama/releases"))
    .put(JSONObject().put("id", "hf-mirror").put("label", "HF-Mirror (国内)").put("url", "https://hf-mirror.com"))
    .put(JSONObject().put("id", "modelscope").put("label", "ModelScope (魔搭)").put("url", "https://modelscope.cn"))
}