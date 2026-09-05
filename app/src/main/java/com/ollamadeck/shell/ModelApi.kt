package com.ollamadeck.shell

import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * Thin HTTP client for Ollama's REST API on the loopback. Installed-model search is
 * a local query the bridge can answer synchronously; deploy/list/remove are driven
 * from the page over fetch (they involve long-running server-side pulls).
 */
object ModelApi {
  fun tags(query: String): JSONArray {
    val body = get("${OllamaProbe.OLLAMA_HOST}:${OllamaProbe.OLLAMA_PORT}/api/tags") ?: return JSONArray()
    val arr = JSONObject(body).optJSONArray("models") ?: JSONArray()
    val q = query.trim()
    val out = JSONArray()
    for (i in 0 until arr.length()) {
      val name = arr.getJSONObject(i).optString("name")
      if (q.isEmpty() || name.contains(q, ignoreCase = true)) {
        out.put(JSONObject().put("name", name).put("size", arr.getJSONObject(i).optLong("size")))
      }
    }
    return out
  }

  /** Return a JSON payload for the bridge: {ok, models:[...], error?}. */
  fun queryTags(query: String): String = runCatching {
    if (!probeOk()) return runCatching {
      JSONObject().put("ok", false).put("error", "ollama-down").toString()
    }.getOrDefault("{}")
    JSONObject().put("ok", true).put("models", tags(query)).toString()
  }.getOrDefault(JSONObject().put("ok", false).put("error", "http-error").toString())

  private fun probeOk(): Boolean = OllamaProbe.check().running

  private fun get(hostPortPath: String): String? = try {
    val conn = URL("http://$hostPortPath").openConnection() as HttpURLConnection
    conn.connectTimeout = 2500
    conn.readTimeout = 2500
    if (conn.responseCode !in 200..299) null else conn.inputStream.bufferedReader().use { it.readText() }
  } catch (e: Exception) {
    null
  }
}