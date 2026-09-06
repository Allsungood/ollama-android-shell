# Ollama Deck — Android 开发环境配置指南

> 本文档说明如何配置 Android 开发环境，以及项目所需的工具链。

---

## 一、环境需求总览

| 组件 | 最低版本 | 说明 |
|---|---|---|
| Node.js | 18+ | 构建脚本（`.mjs`）运行环境 |
| JDK | 17 | Android 编译工具链 |
| Android SDK | compileSdk 36 / build-tools 34.0.0 | AGP 8.9.2 所需 |
| Gradle | 8.11.1 | 通过 `gradlew` 自动下载，无需单独安装 |
| AGP | 8.9.2 | 通过 Gradle 插件自动下载 |
| Kotlin | 2.0.21 | 通过 Gradle 插件自动下载 |

---

## 二、Windows（推荐用 PowerShell）

### 2.1 一键配置（推荐）

**步骤 1**：确认已安装 **winget**（Windows 11 自带；Windows 10 可从 Microsoft Store 安装「App Installer」）

**步骤 2**：以**管理员身份**打开 PowerShell，执行：

```powershell
# 方式 A：复制粘贴整段单行命令（最快）
powershell -ExecutionPolicy Bypass -File setup-android-dev-single-line.ps1

# 方式 B：运行详细脚本（带进度提示）
powershell -ExecutionPolicy Bypass -File setup-android-dev.ps1
```

脚本会自动完成：
1. 检查 Node.js（缺失则提示安装）
2. 安装 JDK 17（Eclipse Temurin）
3. 配置 JAVA_HOME
4. 下载 Android SDK Command Line Tools
5. 安装 SDK 组件（platforms/android-36 / build-tools/34.0.0 / platform-tools）
6. 设置 ANDROID_HOME、PATH 环境变量
7. 生成 `local.properties`

**步骤 3**：**重启终端**（使环境变量生效）

**步骤 4**：验证并构建
```powershell
cd <项目根目录>
.\gradlew :app:assembleDebug
```

### 2.2 手动配置（可选）

如果一键脚本失败，可手动执行：

```powershell
# 安装 JDK 17
winget install --id EclipseAdoptium.Temurin.17 --accept-source-agreements --accept-package-agreements

# 设置 JAVA_HOME（以管理员 PowerShell 执行）
$javaHome = "C:\Program Files\Eclipse Adoptium\jdk-17.0.x.x-hotspot"
[Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHome, "Machine")

# 安装 Android SDK（从 https://developer.android.com/studio 下载 Command Line Tools）
# 解压到 %LOCALAPPDATA%\Android\Sdk\cmdline-tools\latest\
# 然后通过命令行安装组件
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
& "$env:ANDROID_HOME\cmdline-tools\latest\bin\sdkmanager.bat" "platforms;android-36" "build-tools;34.0.0" "platform-tools"

# 生成 local.properties
@"
sdk.dir=$env:ANDROID_HOME
org.gradle.java.home=$javaHome
"@ | Out-File -FilePath "local.properties" -Encoding UTF8
```

---

## 三、Linux / macOS

### 3.1 一键配置（推荐）

```bash
# Debian/Ubuntu
bash setup-android-dev.sh

# macOS（需已安装 Homebrew）
chmod +x setup-android-dev.sh
./setup-android-dev.sh
```

脚本会自动完成：
1. 安装 JDK 17（通过 apt / brew / dnf）
2. 检查 Node.js
3. 下载 Android SDK Command Line Tools
4. 安装 SDK 组件
5. 生成 `local.properties`

### 3.2 手动配置（可选）

**Debian/Ubuntu：**
```bash
# 安装 JDK 17
sudo apt-get install -y openjdk-17-jdk-headless

# 安装 Node.js（如未安装）
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# 安装 Android SDK
export ANDROID_HOME=$HOME/Android/Sdk
mkdir -p $ANDROID_HOME/cmdline-tools
cd $ANDROID_HOME/cmdline-tools
curl -O https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip -q commandlinetools-*.zip && mv cmdline-tools latest

# 安装 SDK 组件
export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$PATH
sdkmanager --licenses < /dev/null 2>/dev/null || true
sdkmanager "platforms;android-36" "build-tools;34.0.0" "platform-tools"

# 生成 local.properties
echo "sdk.dir=$ANDROID_HOME" > local.properties
echo "org.gradle.java.home=/usr/lib/jvm/java-17-openjdk-$(uname -m)" >> local.properties
```

**macOS：**
```bash
# 安装 JDK 17
brew install --cask temurin@17

# 安装 Node.js
brew install node

# 安装 Android SDK（同上 Linux 步骤，替换 URL）
export ANDROID_HOME=$HOME/Library/Android/Sdk
mkdir -p $ANDROID_HOME/cmdline-tools
cd $ANDROID_HOME/cmdline-tools
curl -O https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip
unzip -q commandlinetools-*.zip && mv cmdline-tools latest
export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$PATH
sdkmanager "platforms;android-36" "build-tools;34.0.0" "platform-tools"

# 生成 local.properties
JAVA_HOME=$( /usr/libexec/java_home -v 17 )
echo "sdk.dir=$ANDROID_HOME" > local.properties
echo "org.gradle.java.home=$JAVA_HOME" >> local.properties
```

---

## 四、验证环境

```bash
# JDK
java -version
# 输出：openjdk version "17.0.x" ...

# Node.js
node --version
# 输出：v20.x.x

# Android SDK
echo $ANDROID_HOME
# 输出：/path/to/Android/Sdk

# Gradle
./gradlew --version
# 输出：Gradle 8.11.1

# 构建测试
./gradlew :app:assembleDebug
# 输出：BUILD SUCCESSFUL
```

---

## 五、常见问题

### Q1: `java: command not found`
重启终端使 `JAVA_HOME` 生效，或手动 `export JAVA_HOME=/path/to/jdk17`。

### Q2: `sdkmanager: command not found`
```bash
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
```

### Q3: `Missing file` 或构建失败
缺少运行时快照。构建前需准备 `app/src/main/assets/termux-runtime.tar.xz`。
详见 [docs/USAGE.md](docs/USAGE.md) §2.2。

### Q4: 安装 JDK 失败
手动从 https://adoptium.net/temurin/releases/ 下载 JDK 17 安装包。

### Q5: Node.js 版本低于 18
```bash
# nvm
nvm install 20 && nvm use 20
# 或 brew
brew install node
```

---

## 六、文件清单

| 文件 | 用途 |
|---|---|
| `setup-android-dev.ps1` | Windows 详细配置脚本（带进度提示） |
| `setup-android-dev-single-line.ps1` | Windows 单行一键配置 |
| `setup-android-dev.sh` | Linux/macOS 配置脚本 |
| `local.properties` | 本地 SDK/JDK 路径（不入库） |
| `gradlew` / `gradlew.bat` | Gradle Wrapper（已提交） |
