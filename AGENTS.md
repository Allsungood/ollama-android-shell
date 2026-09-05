# AGENTS.md — Ollama Deck 开发/维护约定

> 目标：让接手此仓库的 agent/human 不改坏「壳 ↔ 网页 ↔ 安装脚本」三端契约。
> 参考：`dsh-mobile-apk`（本工程是其 Ollama 端复刻）。端口/桥协议是硬约束。

## 项目定位

安卓「壳 APK」：`WebView(壳 UI/Open WebUI) + window.androidBridge(原生桥) + 内嵌 Termux 快照 + 前台保活服务`。
关键差异 vs 参考壳：引擎不是 DeepSeek Harness，而是 **Ollama（127.0.0.1:11434）+ Open WebUI（127.0.0.1:8080）**。

## 目录速览

```
app/src/main/java/com/ollamadeck/shell/
  MainActivity      WebView + 桥接线 + 引导分支
  OllamaBridge      window.androidBridge 实现（三端契约核心）
  RuntimeManager    解压/校验 termux-runtime.tar.xz（指纹文件 .runtime-fingerprint）
  BootstrapManager  写配置(prefs JSON)→OLLAMADECK_* env→安装脚本；markBootstrapDone 记录
  BridgeService     前台 dataSync + 5s 看门狗（OllamaProbe）
  OllamaProbe       探活 11434/8080；ModelApi 走 ollama /api/* 
  assets/*.sh       安装脚本；assets/webui/*.html 壳内嵌 UI
scripts/            build-snapshot.mjs / build-apk.mjs；gradle 门禁强制快照存在
```

## 硬约束（改动前必读）

1. **端口不可变**：Ollama `11434`、Open WebUI `8080`。改它们会同时破坏
   `OllamaProbe`、`OllamaBridge.ollamaBase/openwebuiUrl`、`assets/*.sh`、`assets/webui/*.html`。
2. **桥协议 v1**（页面 feature-detect：`androidBridge.version()` 存在与否）：
   `checkEngine/checkUi/ollamaBase/openwebuiUrl/getLanguages/setLanguage/getMirrors/setMirror/
   modelSearchLocal/startBootstrap/bootstrapStatus/copyText/showNotification/keepScreenOn/
   setTextZoom/hasAllFilesAccess/requestAllFilesAccess/downloadDebugLogs/
   restartEngine/shutdownToGuide/reloadWebUI/openConsole`。
   改动桥上任何方法，必须同步 `assets/webui/index.html` 与 `docs/design.md` + 本文件。
3. **配置链路**：`BootstrapManager.persistConfig(mirror,language)` → `prefs/ollamadeck-config.json`
   → 安装脚本读 `OLLAMADECK_*`。桥面 get/set 必须落同一来源，禁止另起存储。
4. **targetSdk 固定 34**；快照/`xxx.tar.xz` 不提交仓库（禁 `androidResources.noCompress xz` 之外压缩）。
5. **一键部署只在首次**：`BootstrapManager` 仅当 `usr/bin/sh`+`python` 就绪且脚本全成功才
   `markBootstrapDone`；失败回退、下次重试。

## 构建与测试

```bash
# 快照（需预置 Termux rootfs + python + ollama + open-webui venv）
node scripts/build-snapshot.mjs --src out/bootstrap-root --arch arm64
# 打包（需 JDK17+ / Android SDK）
node scripts/build-apk.mjs --arch arm64            # 或 x86_64 / --debug
# 纯逻辑单测（webui 共享模块）
node --test app/src/main/assets/webui/deck-logic.test.js
```

## 验证清单（改动后）

- [x] `sh -n app/src/main/assets/*.sh`；`node --test deck-logic.test.js`（14/14 通过）
- [ ] 桥方法在 `OllamaBridge` / `webui/index.html` / `docs/design.md` 三处一致
- [x] 语言 chips：以 `it.id || it.code` 取 key，仅镜像项显示 URL（修复 Registry code/id 不一致）
- [x] 换镜像/语言后，`bootstrapStatus` 与安装脚本 `OLLAMADECK_*` 读到一致值
- [x] `startServices` 使用绝对 ollama 路径 + `pgrep` 幂等防重（修复相对路径/端口冲突）
- [ ] `gradle :app:assembleDebug`（有 SDK）通过；`adb install -r -t` 覆盖安装 OK

> 运维指南见 `docs/USAGE.md`。