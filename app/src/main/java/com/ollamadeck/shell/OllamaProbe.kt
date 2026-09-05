package com.ollamadeck.shell

import java.net.HttpURLConnection
import java.net.URL

/**
 * Local runtime probe. ollama serves its REST API on 127.0.0.1:11434 and
 * open-webui on 127.0.0.1:8080; both are reachable from the WebView over the
 * loopback. Mirrors EngineProbe.kt from the reference shell.
 */
object OllamaProbe {
  const val OLLAMA_HOST = "127.0.0.1"
  const val OLLAMA_PORT = 11434
  const val OPENWEBUI_PORT = 8080

  data class Result(val running: Boolean, val latencyMs: Long, val error: String?, val version: String?)

  fun check(url: String = "http://$OLLAMA_HOST:$OLLAMA_PORT/api/version"): Result {
    val t0 = System.currentTimeMillis()
    return try {
      val conn = URL(url).openConnection() as HttpURLConnection
      conn.connectTimeout = 1200
      conn.readTimeout = 1200
      conn.requestMethod = "GET"
      val body = conn.inputStream.bufferedReader().use { it.readText() }
      val ms = System.currentTimeMillis() - t0
      val ver = regexVersion.find(body)?.groupValues?.get(1)
      Result(running = true, latencyMs = ms, error = null, version = ver)
    } catch (e: Exception) {
      val ms = System.currentTimeMillis() - t0
      Result(running = false, latencyMs = ms, error = e.message, version = null)
    }
  }

  /** Check open-webui specifically (diagnostic only). */
  fun checkUi(): Pair<Boolean, String> = try {
    val body = URL("http://$OLLAMA_HOST:$OPENWEBUI_PORT/health").openConnection().let {
      (it as HttpURLConnection).connectTimeout = 1200
      it.readTimeout = 1200
      it.inputStream.bufferedReader().use { r -> r.readText() }.trim()
    }
    true to body
  } catch (e: Exception) {
    false to (e.message ?: "down")
  }

  private val regexVersion = Regex("\"version\"\\s*:\\s*\"([^\"]+)\"")
}