package com.ollamadeck.shell

import android.content.Context
import android.util.Log
import org.apache.commons.compress.archivers.tar.TarArchiveInputStream
import org.tukaani.xz.XZInputStream
import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest

/**
 * Extracts the embedded Termux runtime snapshot (termux-runtime.tar.xz) into the
 * app-private filesDir and marks one-shot bootstrapping so the heavy Termux/Ollama
 * offline-prep runs only once. Mirrors SnapshotExtractor/EngineManager from the
 * reference shell; here the "engine" is a Termux runtime + ollama + open-webui.
 */
class RuntimeManager(private val context: Context) {
  private val runtimeDir: File = context.filesDir
  private val fingerprintFile = File(runtimeDir, ".runtime-fingerprint")
  private val bootstrapDoneFile = File(runtimeDir, ".ollama-bootstrap-done")
  val runtimePath: String get() = runtimeDir.absolutePath
  val binPath: String get() = File(runtimeDir, "usr/bin").absolutePath

  /** Snapshot present in assets (source projects must inject it; build gate enforces it). */
  fun snapshotPresentInAssets(): Boolean = runCatching {
    context.assets.open("termux-runtime.tar.xz").close()
    true
  }.getOrDefault(false)

  /** True once the snapshot has been extracted in a prior launch. */
  fun isRuntimeReady(): Boolean = fingerprintFile.exists()

  /** True the very first time (Termux bootstrap + Ollama install still pending). */
  fun needsBootstrap(): Boolean = !bootstrapDoneFile.exists()

  fun extractIfNeeded(onProgress: (String) -> Unit) {
    if (isRuntimeReady()) return
    onProgress("解压运行时快照（首次约需 2–4 分钟）…")
    extractSnapshot(onProgress)
  }

  private fun extractSnapshot(onProgress: (String) -> Unit) {
    val asset = context.assets.open("termux-runtime.tar.xz")
    val totalBytes = asset.available()
    var readBytes = 0L
    XZInputStream(asset).use { xz ->
      TarArchiveInputStream(xz).use { tar ->
        var entry = tar.nextTarEntry
        while (entry != null) {
          val target = File(runtimeDir, entry.name).apply { parentFile?.mkdirs() }
          if (entry.isFile) {
            target.outputStream().use { out -> tar.copyTo(out, 64 * 1024) }
            target.setExecutable(entry.mode and 0b1_000_000_000 != 0, false)
          }
          readBytes += entry.size
          onProgress("解压中 ${readBytes / (1 shl 20)} / ${totalBytes / (1 shl 20) + 1} MB…")
          entry = tar.nextTarEntry
        }
      }
    }
    fingerprintFile.writeText("extracted:${BuildConfig.VERSION_NAME}")
    Log.i(TAG, "runtime extracted -> $runtimeDir")
  }

  fun markBootstrapDone() {
    bootstrapDoneFile.writeText("ok")
  }

  companion object {
    private const val TAG = "RuntimeManager"

    fun sha256(file: File): String {
      val md = MessageDigest.getInstance("SHA-256")
      FileInputStream(file).use { ins ->
        val buf = ByteArray(64 * 1024)
        var n = ins.read(buf)
        while (n != -1) {
          md.update(buf, 0, n)
          n = ins.read(buf)
        }
      }
      return md.digest().joinToString("") { "%02x".format(it) }
    }
  }
}