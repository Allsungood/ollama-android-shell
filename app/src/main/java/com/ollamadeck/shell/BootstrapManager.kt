package com.ollamadeck.shell

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import org.json.JSONObject
import java.io.File

/**
 * One-shot bootstrap: after the runtime snapshot is extracted it (a) writes the
 * user-chosen config (language + mirror), (b) runs the embedded setup scripts that
 * point Termux/pkg at the selected mirror, configure shell env, launch ollama and
 * open open-webui, then (c) marks the run done so it is skipped on later launches.
 * Streaming progress is delivered to the page through a callback for the guide screen.
 */
class BootstrapManager(context: Context) {
  private val ctx = context
  private val prefs: SharedPreferences = context.getSharedPreferences("ollamadeck", Context.MODE_PRIVATE)

  var isRunning = false
    private set

  var lastError: String? = null
    private set

  /** Which setup scripts/assets to copy into the runtime and run in order. */
  private val bootstrapSteps = listOf(
    ScriptStep("termux-env-setup.sh", "初始化 Termux 环境"),
    ScriptStep("ollama-setup.sh", "配置 Ollama 引擎与镜像源"),
    ScriptStep("openwebui-setup.sh", "部署 Open WebUI 网页界面"),
  )

  /** Persist the chosen mirror + language so the runtime can re-read it. */
  fun persistConfig(mirror: String, language: String) {
    val cfg = JSONObject()
      .put("mirror", mirror)
      .put("language", language)
      .put("ollamaShellhttp", true)
    val cfgFile = File(prefsDir, "ollamadeck-config.json")
    cfgFile.writeText(cfg.toString())
    prefs.edit().putString("mirror", mirror).putString("language", language).apply()
  }

  fun loadConfig(): JSONObject = runCatching {
    JSONObject(File(prefsDir, "ollamadeck-config.json").readText())
  }.getOrDefault(JSONObject().put("mirror", "auto").put("language", "zh-Hans"))

  private val prefsDir: File
    get() = File(ctx.filesDir, "prefs").apply { mkdirs() }

  /** Run the full bootstrap pipeline. Must be called off the main thread. */
  fun run(runtime: RuntimeManager, onProgress: (String) -> Unit): Boolean {
    if (isRunning) return true
    isRunning = true
    lastError = null
    val env = buildMap {
      put("OLLAMADECK_MIRROR", loadConfig().optString("mirror", "auto"))
      put("OLLAMADECK_LANG", loadConfig().optString("language", "zh-Hans"))
      put("OLLAMADECK_RUNTIME", runtime.runtimePath)
      put("OLLAMADECK_BIN", runtime.binPath)
    }
    try {
      for ((name, label) in bootstrapSteps) {
        onProgress("$label …")
        val script = writeScript(runtime, name)
        val result = Exec.run(runtime.binPath, env, "sh", script.absolutePath)
        if (result.exitCode != 0) {
          lastError = (result.stderr ?: result.stdout ?: "").takeLast(1200)
          Log.e(TAG, "$name failed:\n$lastError")
          return false
        }
      }
      // Mark done only on the happy path; a later relaunch retries the failed step.
      runtime.markBootstrapDone()
      return true
    } finally {
      isRunning = false
    }
  }

  private fun writeScript(runtime: RuntimeManager, name: String): File {
    val target = File(runtime.runtimePath, "bootstrap-scripts/$name").apply { parentFile?.mkdirs() }
    ctx.assets.open(name).use { ins -> target.outputStream().use { ins.copyTo(it) } }
    target.setExecutable(true, true)
    return target
  }

  /**
   * Ensure ollama (and keep open-webui entrypoints available) inside the runtime.
   * ollama-setup.sh already starts the daemon; this is a safe idempotent re-ensure
   * using an absolute binary path so it works regardless of the process cwd.
   */
  fun startServices(runtime: RuntimeManager, onLog: (String) -> Unit) {
    val cfg = loadConfig()
    val ollamaBin = File(runtime.binPath, "ollama").absolutePath
    val logFile = File(runtime.runtimePath, "ollama.log").absolutePath
    val env = buildMap {
      put("OLLAMA_HOST", "127.0.0.1")
      put("OLLAMA_PORT", "11434")
    }
    Exec.run(runtime.binPath, env, "sh", "-c",
      "if ! $ollamaBin --version >/dev/null 2>&1; then echo 'ollama missing'; exit 1; fi;" +
        " if ! pgrep -f 'ollama serve' >/dev/null 2>&1; then" +
        " nohup \"$ollamaBin\" serve >>\"$logFile\" 2>&1 & fi; echo started")
    onLog("Ollama: ${cfg.optString("mirror", "auto")} 镜像 / ${cfg.optString("language", "zh-Hans")} 语言")
  }

  data class ScriptStep(val name: String, val label: String) {
    operator fun component1() = name
    operator fun component2() = label
  }

  companion object {
    private const val TAG = "BootstrapManager"
  }
}

/** Minimal process runner returning exit code + stdout/stderr. */
object Exec {
  data class Result(val exitCode: Int, val stdout: String?, val stderr: String?)

  fun run(runtimeBin: String, env: Map<String, String> = emptyMap(), vararg cmd: String): Result {
    return try {
      val pb = ProcessBuilder(*cmd)
      pb.environment().putAll(env)
      pb.redirectErrorStream(false)
      val p = pb.start()
      val out = p.inputStream.bufferedReader().use { it.readText() }
      val err = p.errorStream.bufferedReader().use { it.readText() }
      Result(p.waitFor(), out, err)
    } catch (e: Exception) {
      Result(-1, null, e.message)
    }
  }
}