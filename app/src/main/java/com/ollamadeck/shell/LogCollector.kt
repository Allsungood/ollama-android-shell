package com.ollamadeck.shell

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import java.io.File

/** Collects app/runtime logs and shares them through the system download dialog. */
object LogCollector {
  fun export(ctx: Context, runtime: RuntimeManager): Boolean = try {
    val src = File(runtime.runtimePath, "ollama.log")
    if (!src.exists()) return false
    val dest = File(ctx.cacheDir, "ollamadeck-logs.txt")
    src.copyTo(dest, overwrite = true)
    val uri: Uri = FileProvider.getUriForFile(ctx, "${ctx.packageName}.fileprovider", dest)
    val share = Intent(Intent.ACTION_SEND).apply {
      type = "text/plain"
      putExtra(Intent.EXTRA_STREAM, uri)
      addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
      addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    ctx.startActivity(Intent.createChooser(share, "导出日志"))
    true
  } catch (e: Exception) {
    false
  }
}