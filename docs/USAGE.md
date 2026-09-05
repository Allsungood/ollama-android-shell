# Ollama Deck — 操作指南

> 安卓壳 APK：内嵌 Termux 运行时 + Ollama 引擎 + Open WebUI 网页界面。
> 首次安装后自动配置 Termux 系统环境、Ollama 软件与镜像源，之后即可在图形界面里搜索/拉取/删除模型，并用 Open WebUI 进行对话。

---

## 1. 这是什么

| 组件 | 说明 |
|---|---|
| 壳 APK | `WebView + window.androidBridge + 内嵌 Termux 快照 + 前台保活服务` |
| 引擎 | Ollama（本机 `127.0.0.1:11434`） |
| 网页界面 | Open WebUI（本机 `127.0.0.1:8080`） |
| 引导 UI | 内嵌 `assets/webui/index.html`，负责首次部署、语言/镜像、模型管理 |

支持能力：
- 自动配置 Termux 系统环境（PATH / locale / 镜像源）
- 自动安装并启动 Ollama、部署 Open WebUI
- 多种语言（简体中文 / 繁體中文 / English / 日本語）
- 多种下载镜像源（官方 / GitHub / HF-Mirror / ModelScope / 自动）
- 图形化搜索、拉取、删除已安装模型
- Open WebUI 完整对话/部署界面

---

## 2. 构建 APK（开发者）

### 2.1 前置准备
本机需要：**JDK 17+**、**Android SDK**（`local.properties` 或 `ANDROID_HOME`）、**Node 18+**。

项目不提交运行时快照（体积大），需先自行产出。

### 2.2 生成 Termux 运行时快照
先准备对应 ABI 的 Termux rootfs，内置 `python git curl ollama` 并把 `open-webui` 装进其 venv：

```bash
# 在已配置好的 rootfs 目录上执行
node scripts/build-snapshot.mjs --src out/bootstrap-root --arch arm64
# x86_64 则： --arch x86_64
```

产物：`out/snapshot/termux-runtime-<arch>.tar.xz`，并自动更新 `snapshot.sha256`。

### 2.3 打包 APK
```bash
node scripts/build-apk.mjs --arch arm64          # release
node scripts/build-apk.mjs --arch arm64 --debug  # debug
```
构建前会做门禁校验：快照存在、`snapshot.sha256` 不含占位符、三个安装脚本齐全。产物在 `app/build/outputs/apk/<variant>/`。

### 2.4 用 GitHub 云构建（推荐，无需本机 SDK）
推送 tag 或手动触发 `build` workflow 会对 `arm64`/`x86_64` 双 ABI 各打一个 APK：
- 在 workflow 输入框填 **快照下载 URL**（模板里的 `{arch}` 会自动替换为 abi）
- 打 tag 后自动上传到对应 Release

---

## 3. 安装到手机

1. 将 `app/build/outputs/apk/release/dsh-mobile...-release.apk`（或 CI Release 下载）传到手机。
2. 安装时允许"未知来源"。
3. 若旧版本已安装，覆盖安装签名需一致（本仓库 keystore 已固定，可覆盖安装）。

> 首次启动会**解压运行时快照约 2–4 分钟**，请耐心等待，保持前台。

---

## 4. 首次使用（一键部署）

1. 打开 App，进入引导页。
2. （可选）先在上方"语言 Language / 镜像源 Mirrors"面板选好偏好。
3. 点击 **「开始一键部署 Termux · Ollama · Open WebUI」**。
    - 依次执行：初始化 Termux 环境 → 配置 Ollama 引擎与镜像源 → 部署 Open WebUI。
    - 进度条会实时映射到中文提示。
4. 部署成功标记后，自动进入 Open WebUI（若引擎仍在启动，会先回到引导页并显示就绪状态，稍后自动切换）。

> 一键部署**只在首次执行**；失败会自动保留进度，下次进入可重试，不会重复成功步骤。

---

## 5. 图形界面操作

### 5.1 语言 / 镜像
- 顶部两个面板点选即可切换，配置会被持久化（写回 `prefs/ollamadeck-config.json`），并注入 Termux 的 locale 与镜像 URL。
- 语言影响：终端 locale 与界面文案。
- 镜像影响：Ollama/模型的下载分发渠道（模型本身从 Ollama 官方拉取，镜像决定二进制与依赖来源）。

### 5.2 模型仓库 Model Hub
- 搜索框按名称过滤**已安装**模型。
- 点下方推荐卡片（如 `qwen2.5:7b`）、或直接用搜索框定位后，即可**拉取**模型到本地。
- 每条模型条目提供**删除**按钮。
- 注意：此处拉取走 Ollama REST（`127.0.0.1:11434`），真正多模型对话在 Open WebUI。

### 5.3 Open WebUI
- 当 Web UI 指示灯为绿色时，点击 **「打开 Open WebUI 对话界面 →」** 进入完整网页版。
- 网页内可继续搜索/部署模型、发起对话。

---

## 6. 常见问题排查

| 现象 | 处理 |
|---|---|
| 部署进度一直卡住 | 回到引导页查看 `bootMsg`/`bootErr`；确认网络可用 |
| 引擎指示灯一直 OFF | 等待几秒让看门狗自检；或 App 内点 `下载调试日志` 查看 `ollama.log` |
| 无法访问网页界面 | 确认端口 `8080` 未被占用；首次 Open WebUI 构建较慢属正常 |
| 删除/拉取失败 | 检查本地 Ollama 是否在线（`检查 Ollama 引擎` 指示灯） |
| 需要原始终端 | 引导页/桥提供打开 Console 的入口（`assets/console.html`） |
| Android 11+ 文件访问 | 模型缓存写到应用私有目录，如需外部存储请授予"所有文件访问"权限 |

### 调试入口
- 桥 `downloadDebugLogs()`：收集 `ollama.log` 并分享。
- `ConsoleActivity`：内置终端便于诊断。

---

## 7. 技术约束（改动前必读）

- **端口不可变**：Ollama `11434`、Open WebUI `8080`，多处引用。
- **targetSdk 固定 34**：保证 Android 15/16 上能 exec 内嵌 Termux/Ollama ELF。
- **快照/`*.tar.xz` 不入库**：构建门禁强制存在，防止打包进空运行时。
- **桥协议 v1**：桥方法改动需同步 `OllamaBridge` / `webui/index.html` / `docs/design.md`。
- **配置单一来源**：语言/镜像统一走 `BootstrapManager.persistConfig` → `prefs/ollamadeck-config.json` → `OLLAMADECK_*` 环境变量。