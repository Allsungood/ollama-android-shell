# Ollama Deck — 架构与桥协议（design.md）

## 进程与端口

```
┌──────────────────────────── 壳（com.ollamadeck.shell）────────────────────────────┐
│  MainActivity (WebView)  ── window.androidBridge ──► OllamaBridge (原生)          │
│      │  │                                                                          │
│      │  └─ fetch http://127.0.0.1:11434/…  ──► 选装运行时: ollama  (REST API)      │
│      └─ fetch http://127.0.0.1:8080   ──► 选装运行时: open-webui (Open WebUI)      │
│  BridgeService(前台 dataSync) ── 5s 看门狗 ──► OllamaProbe (11434/8080)            │
│  RuntimeManager —— 解压/校验 termux-runtime.tar.xz → filesDir                      │
│  BootstrapManager —— prefs/ollamadeck-config.json → OLLAMADECK_* env → 安装脚本     │
└──────────────────────────────────────────────────────────────────────────────────┘
```

- Ollama：`http://127.0.0.1:11434`（`/api/version /api/tags /api/pull /api/delete /api/chat`）
- Open WebUI：`http://127.0.0.1:8080`（对接 `OLLAMA_BASE_URL=http://127.0.0.1:11434`）

## 桥协议 v1（window.androidBridge）

| 方法 | 返回 | 语义 |
|---|---|---|
| `version()` | string | 版本（页面 feature-detect） |
| `checkEngine()` | JSON | Ollama 探活 `{running, latencyMs, version?, error?}` |
| `checkUi()` | JSON | Open WebUI 探活 |
| `ollamaBase()` / `openwebuiUrl()` | string | 页面应使用的基础 URL |
| `getLanguages()`/`setLanguage(code)` | JSON[] / void | 多语言 |
| `getMirrors()`/`setMirror(id)` | JSON[] / void | 多镜像源 |
| `modelSearchLocal(q)` | JSON | 本地已装模型过滤 `{ok, models:[{name,size}], error?}` |
| `startBootstrap()`/`bootstrapStatus()` | void / JSON | 一键部署触达与进度轮询 |
| `copyText/showNotification/keepScreenOn/setTextZoom` | … | 原生能力兜底 |
| `hasAllFilesAccess/requestAllFilesAccess` | bool / void | 全盘文件访问 |
| `downloadDebugLogs()` | void | 日志导出 |
| `restartEngine/shutdownToGuide/reloadWebUI/openConsole` | void | 壳控制 |

异步进度：`window.__deck.onProgress({progress, done})`（原生 `evaluateJavascript` 回调）。

## 安装脚本契约（assets/，运行于快照内 `/bin/sh`）

入参环境变量（BootstrapManager 注入）：`OLLAMADECK_RUNTIME`、`OLLAMADECK_BIN`、`OLLAMADECK_MIRROR`、`OLLAMADECK_LANG`。

1. `termux-env-setup.sh` —— 设 PATH/`TERMUX_PREFIX`、写 `etc/mirror.conf`、写 `root/.bash_profile`（locale 依语言）。
2. `ollama-setup.sh` —— （缺则安装）ollama → `OLLAMA_MODELS` → 后台 `ollama serve` → PID → 就绪探测。
3. `openwebui-setup.sh` —— （缺则 pip 安装）open-webui → `OLLAMA_BASE_URL` → `:8080` 后台服务。

任一失败即回退，下次启动重试（`markBootstrapDone` 仅全成功时写入）。

## 构建管线

`scripts/build-snapshot.mjs` 产 `termux-runtime.tar.xz`（不提交）→ `scripts/build-apk.mjs`：门禁(快照/脚本/sha256 非占位) → gradle `:app:assemble{Debug|Release}` → `out/`。

## ABI

真机选 **arm64**；模拟器选 **x86_64**。快照按 ABI 分别打包，匹配错误则引擎启动时 ELF 崩溃。