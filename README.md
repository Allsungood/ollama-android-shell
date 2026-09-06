# Ollama Deck — Android Ollama 客户端

内嵌 **Termux + Ollama + Open WebUI** 的安卓壳 APK：

- **WebView + 原生桥**（window.androidBridge）
- **一键部署**：自动配置 Termux 系统环境、Ollama 引擎、Open WebUI 网页界面
- **多语言 / 多镜像**：简体中文 / 繁體中文 / English / 日本語；官方 / GitHub / HF-Mirror / ModelScope / 自动
- **图形化模型管理**：搜索、拉取、删除已安装模型
- **前台保活服务** + 重启恢复
- **双 ABI 支持**：arm64 / x86_64

---

## 快速开始

### 1. 配置开发环境

**Windows（PowerShell）**：以管理员身份运行  
```powershell
cd <repo-root>
.\setup-android-dev.ps1
```

**Linux / macOS**（需已安装 Node.js 18+）：
```bash
# 安装 JDK 17 + Android SDK（以 Debian/Ubuntu 为例）
sudo apt-get install -y openjdk-17-jdk-headless
export ANDROID_HOME=$HOME/Android/Sdk
mkdir -p $ANDROID_HOME/cmdline-tools
cd $ANDROID_HOME/cmdline-tools
curl -O https://dl.google.com/android/repository/commandlinetools-<arch>-latest.zip
unzip commandlinetools-*.zip && mv cmdline-tools latest
export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$PATH
sdkmanager --licenses 2>/dev/null || true
sdkmanager "platforms;android-36" "build-tools;34.0.0" "platform-tools"
```

生成 `local.properties`（自动指向环境变量）：
```bash
echo "sdk.dir=$ANDROID_HOME" > local.properties
echo "org.gradle.java.home=/usr/lib/jvm/java-17-openjdk" >> local.properties
```

### 2. 获取运行时快照

快照（Termux rootfs + python + ollama + open-webui）不在仓库中（体积大）。

**本地构建快照**（需已配置 Termux rootfs）：
```bash
node scripts/build-snapshot.mjs --src out/bootstrap-root --arch arm64
```

**使用 CI 下载快照**（见 [docs/USAGE.md](docs/USAGE.md)）

### 3. 构建 APK

```bash
# debug 版本
./gradlew :app:assembleDebug
# 或 npm 脚本（若存在）
node scripts/build-apk.mjs --arch arm64 --debug

# release 版本
./gradlew :app:assembleRelease
node scripts/build-apk.mjs --arch arm64
```

产物位置：`app/build/outputs/apk/<variant>/`

### 4. 安装到设备

```bash
adb install -r -t app/build/outputs/apk/debug/*.apk
```

---

## 项目结构

```
ollama-android-shell/
├── app/src/main/
│   ├── assets/
│   │   ├── webui/           # 引导 UI + 模型管理
│   │   │   ├── index.html   # 主界面
│   │   │   ├── deck-logic.js        # 纯 JS 逻辑（可单测）
│   │   │   └── deck-logic.test.js   # 单元测试
│   │   ├── console.html     # 内置终端
│   │   ├── termux-env-setup.sh
│   │   ├── ollama-setup.sh
│   │   └── openwebui-setup.sh
│   ├── java/com/ollamadeck/shell/
│   │   ├── MainActivity.kt        # WebView + 桥接线 + 引导分支
│   │   ├── OllamaBridge.kt        # JS 桥（窗口 ↔ 原生）
│   │   ├── RuntimeManager.kt      # 快照解压 / 校验
│   │   ├── BootstrapManager.kt    # 一键部署流水线
│   │   ├── OllamaProbe.kt         # 引擎 / UI 探活
│   │   ├── ModelApi.kt            # Ollama REST API 客户端
│   │   ├── BridgeService.kt       # 前台保活 + 看门狗
│   │   ├── BootReceiver.kt        # 重启后恢复服务
│   │   ├── ConsoleActivity.kt     # 内置终端页
│   │   ├── NotifyCenter.kt        # 系统通知
│   │   └── LogCollector.kt        # 日志导出
│   └── res/                 # 资源
├── scripts/
│   ├── build-snapshot.mjs   # 打包 Termux 快照
│   └── build-apk.mjs        # 注入快照 + gradle 打包
├── .github/workflows/build.yml  # CI 双 ABI 构建
├── docs/
│   ├── PLAN.md              # 产品规划
│   ├── design.md            # 架构设计
│   └── USAGE.md             # 操作指南
├── AGENTS.md                # 开发约定与验证清单
├── setup-android-dev.ps1    # Windows 一键环境配置
└── local.properties         # 本地 SDK 路径（不入库）
```

---

## 技术约束

- **端口不可变**：Ollama `11434`、Open WebUI `8080`
- **targetSdk = 34**：保证 Android 15/16 上能 exec 内嵌 Termux/Ollama ELF
- **快照 / `*.tar.xz` 不入库**：构建门禁强制存在
- **桥协议 v1**：改动桥方法需同步 Android / Web / 文档三端

---

## 测试

```bash
# 纯 JS 逻辑单测（无需 Android SDK）
node --test app/src/main/assets/webui/deck-logic.test.js

# Shell 脚本语法检查
sh -n app/src/main/assets/*.sh

# Android 构建（需完整 SDK）
./gradlew :app:assembleDebug
```

---

## 参考

- 原始壳参考：[dsh-mobile-apk](https://github.com/kelai141/dsh-mobile-apk/)
- Ollama 文档：https://ollama.com/docs
- Open WebUI 文档：https://openwebui.com/