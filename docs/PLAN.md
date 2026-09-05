# Ollama Deck — 产品与技术规划

> archcore:plan (product track) — 在 /workspace/dsh-mobile-apk 参考壳架构之上，产出一个对称的「Ollama 安卓客户端」。
> 交付物形态：可随 SDK 编译的完整源码工程 + 打包脚本 + Web UI + 测试；本环境无 Android SDK，最终 APK 需在有 SDK 的机器或 CI 上执行 `scripts/build-apk.mjs` 产出。

## 1. Goal

做一个安卓端 **Ollama 客户端**，参照参考 APK 的“壳 + 内嵌 Termux 运行时 + WebView 桥 + 前台服务 + 引导页 + 构建管线”运行模式，实现：

- 自动配置 **Termux 系统环境**（PATH / locale / 镜像源）。
- 自动安装并配置 **Ollama** 引擎本身（二进制、模型目录、`127.0.0.1:11434` 守护、健康探测）。
- **多种语言**（界面/终端 locale）与**多镜像源**（官方 / GitHub / HF-Mirror / ModelScope）可视化选择。
- **图形化模型搜索与部署**：搜索已装模型、一键 `ollama pull`、删除；推荐模型面板。
- 使用 **Open WebUI** 作为网页对话/管理界面，一键挂载入口。

## 2. 参考架构映射（来自 dsh-mobile-apk）

| 参考件 | 作用 | 本项目的对称实现 |
|---|---|---|
| `SnapshotExtractor/EngineManager` | 解压/校验内嵌运行时 | `RuntimeManager`（解压 `termux-runtime.tar.xz`，指纹校验） |
| `EngineService/WatchdogV2` | 前台保活 + 探活重启 | `BridgeService`（5s 看门狗探测 Ollama/OpenWebUI） |
| `EngineProbe` | `127.0.0.1:3080` 探活 | `OllamaProbe`（`127.0.0.1:11434` / `:8080`） |
| `AndroidBridge`（`window.androidBridge`） | JS↔原生桥 | `OllamaBridge`（多语言/多镜像/模型搜索/部署探活） |
| `MainActivity` + 引导页 | WebView + 首次部署引导 | `MainActivity` + `assets/webui/index.html` |
| `scripts/build-apk.mjs` | 注入快照 → 门禁 → gradle | `scripts/build-apk.mjs`（同管线） |

## 3. 关键设计决策

1. **Web 与原生解耦守桥**：WebView 直接 `fetch` Ollama REST（`/api/tags`、`/api/pull`、`/api/delete`、`/api/chat`）完成图形化搜索/部署/对话；仅原生做不到的事走桥（剪贴板、通知、镜像/语言持久化、All-Files 授权、探活）。
2. **多语言/多镜像 = 壳层配置 + 安装脚本入参**：`BootstrapManager.persistConfig(mirror,language)` 写入 `prefs/ollamadeck-config.json`，安装脚本经 `OLLAMADECK_*` 环境变量读取，实现 Termux/Ollama/OpenWebUI 三端一致。
3. **运行时来源**：`termux-runtime.tar.xz`（Termux 工具链 + 预置 python + ollama）不提交仓库，由 `scripts/build-snapshot.mjs` 构建，构建门禁强制存在——与参考一致的不可提交大文件策略。
4. **targetSdk=34**：沿用参考决策，避免 Android 15+ 对 app-data ELF 执行的限制。

## 4. Tasks（分阶段）

- **M1 工程骨架 ✅**：Gradle/Manifest/res、Kotlin 壳（MainActivity/OllamaBridge/RuntimeManager/BootstrapManager/BridgeService/OllamaProbe/ModelApi/NotifyCenter/LogCollector/ConsoleActivity/BootReceiver）、安装脚本、Web UI。
- **M2 快照与打包**：`scripts/build-snapshot.mjs`（Termux+bootstrap+ollama+python 快照）→ `scripts/build-apk.mjs`（门禁→注入→gradle）。**待办**
- **M3 端到端验证**：真机/模拟器安装、首次部署走通、Open WebUI 挂载、镜像/语言切换生效。**待办（需设备）**
- **M4 加固与发布**：崩溃回滚门、日志导出、覆盖安装签名一致性、GitHub Actions 双 ABI。**待办**

## 5. Acceptance Criteria

1. 首次启动引导页可选**语言**与**镜像源**，一键部署 Termux+Ollama+Open WebUI。
2. `OllamaProbe` 返回 `127.0.0.1:11434` 在线，Web UI 能列出/搜索/拉取/删除模型。
3. 切换镜像或语言后，安装脚本与桥返回一致的新值；终端 locale 与界面文案同步。
4. 打开 Open WebUI 直达对话界面，其 `OLLAMA_BASE_URL` 指向本地 Ollama。
5. `gradle :app:assembleDebug`（有 SDK）成功，产物可 `adb install -r -t`。

## 6. Dependencies

- JDK 17+、Android SDK（compileSdk 36）、Gradle wrapper（已入库）。
- Termux 运行时快照（arm64/x86_64，约百 MB，由快照脚本产出）。
- Open WebUI 需预置 Python 运行时（快照内），重型依赖，首次部署耗时较长——列入已知验收性能风险。

## 7. 下一步建议

- `docs/design.md` 补充桥协议 v1 与安装脚本契约（已留位）。
- 用 `/archcore:decide` 固化“配置写入方式 = prefs JSON + 环境变量入参”这一契约，形成 ADR。