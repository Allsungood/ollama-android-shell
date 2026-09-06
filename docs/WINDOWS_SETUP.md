# Ollama Deck — Windows 环境配置指南（无 winget 版）

> 本文档适用于没有 winget 的 Windows 环境。

---

## 方案一：一键脚本（推荐）

将脚本文件 `setup-android-dev.ps1` 复制到你的项目根目录，然后：

**1. 确认你有管理员权限**
右键点击 PowerShell → **以管理员身份运行**

**2. 确认 Node.js 已安装**
```powershell
node --version
# 应输出 v18.x.x 或更高
```
如果未安装，去 https://nodejs.org/zh-cn/download/prebuilt-installer 下载安装。

**3. 运行配置脚本**
```powershell
powershell -ExecutionPolicy Bypass -File .\setup-android-dev.ps1
```

脚本会自动：
- 尝试用 winget 安装 JDK 17（无 winget 自动跳过）
- 尝试用 Chocolatey 安装 JDK 17（无 choco 自动跳过）
- **自动下载** Eclipse Temurin JDK 17（约 200MB）
- 下载 Android SDK Command Line Tools
- 安装 SDK 组件（platforms/android-36 / build-tools/34.0.0 / platform-tools）
- 配置 JAVA_HOME、ANDROID_HOME 环境变量
- 生成 `local.properties`

---

## 方案二：手动分步安装

如果脚本失败，按以下步骤手动安装：

### 步骤 1：安装 JDK 17

**方式 A - 手动下载安装（无需 winget/choco）**

1. 访问 https://adoptium.net/temurin/releases/
2. 选择 **Version: 17 LTS**，**OS: Windows**，**Architecture: x64**，**Package: JDK**
3. 下载 `.zip` 文件（约 200MB）
4. 解压到 `C:\Program Files\Eclipse Adoptium\`（会自动创建目录）
5. 设置环境变量：
   ```powershell
   [System.Environment]::SetEnvironmentVariable("JAVA_HOME", "C:\Program Files\Eclipse Adoptium\jdk-17.0.x.x-hotspot", "User")
   ```
   将 `jdk-17.0.x.x-hotspot` 替换为你实际解压的目录名。

**方式 B - 使用 Chocolatey（如果有）**
```powershell
choco install temurin17 -y
```

**方式 C - 使用 Scoop（如果有）**
```powershell
scoop install temurin@17
```

### 步骤 2：安装 Android SDK Command Line Tools

1. 下载：https://developer.android.com/tools/releases/cmdline-tools
2. 解压到 `%LOCALAPPDATA%\Android\Sdk\cmdline-tools\latest\`
3. 确保目录结构为：`%LOCALAPPDATA%\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat`

### 步骤 3：安装 SDK 组件

以管理员 PowerShell 运行：
```powershell
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
& "$env:ANDROID_HOME\cmdline-tools\latest\bin\sdkmanager.bat" --licenses --no_https --yes
& "$env:ANDROID_HOME\cmdline-tools\latest\bin\sdkmanager.bat" "platforms;android-36" "build-tools;34.0.0" "platform-tools" "extras;android;m2repository" --no_https --yes
```

### 步骤 4：配置环境变量

```powershell
# JAVA_HOME（假设 JDK 安装在 C:\Program Files\Eclipse Adoptium\jdk-17.0.x.x-hotspot）
$javaHome = "C:\Program Files\Eclipse Adoptium\jdk-17.0.x.x-hotspot"
[System.Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHome, "User")

# ANDROID_HOME
$sdkRoot = "$env:LOCALAPPDATA\Android\Sdk"
[System.Environment]::SetEnvironmentVariable("ANDROID_HOME", $sdkRoot, "User")
[System.Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $sdkRoot, "User")

# PATH（添加 JDK 和 SDK bin 目录）
$oldPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
$newPaths = @("$javaHome\bin", "$sdkRoot\cmdline-tools\latest\bin", "$sdkRoot\platform-tools")
foreach ($p in $newPaths) {
    if (-not ($oldPath -like "*$p*")) { $oldPath = "$p;$oldPath" }
}
[System.Environment]::SetEnvironmentVariable("Path", $oldPath, "User")
```

### 步骤 5：生成 local.properties

在项目根目录创建 `local.properties`：
```
sdk.dir=C:\\Users\\Administrator\\AppData\\Local\\Android\\Sdk
org.gradle.java.home=C:\\Program Files\\Eclipse Adoptium\\jdk-17.0.x.x-hotspot
```

---

## 步骤 5：验证安装

**重启终端**后执行：

```powershell
# 验证 JDK
java -version
# 输出：openjdk version "17.0.x" ...

# 验证 Node.js
node --version
# 输出：v20.x.x 或更高

# 验证 Android SDK
echo $env:ANDROID_HOME
# 输出：C:\Users\Administrator\AppData\Local\Android\Sdk

# 验证 Gradle
.\gradlew --version
# 输出：Gradle 8.11.1

# 构建测试
.\gradlew :app:assembleDebug
```

---

## 常见问题

### Q1: `java: command not found`
重启终端使环境变量生效，或手动执行：
```powershell
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-17.0.x.x-hotspot"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
```

### Q2: `sdkmanager: command not found`
```powershell
$env:Path = "$env:ANDROID_HOME\cmdline-tools\latest\bin;$env:Path"
```

### Q3: `INSTALL_FAILED_UPDATE_INCOMPATIBLE`
卸载旧版本后再安装：
```powershell
adb uninstall com.ollamadeck.shell
adb install -r app/build/outputs/apk/debug/*.apk
```

### Q4: 网络慢或下载失败
手动下载 JDK 17：
- Adoptium: https://adoptium.net/temurin/releases/
- 或镜像：https://mirrors.huaweicloud.com/openjdk/17.0.2/

---

## 文件清单

| 文件 | 用途 |
|---|---|
| `setup-android-dev.ps1` | 完整配置脚本（推荐） |
| `setup-android-dev-single-line.ps1` | 单行一键配置 |
| `setup-android-dev.sh` | Linux/macOS 配置脚本 |
| `docs/ENV_SETUP.md` | 环境配置详细指南 |
| `docs/USAGE.md` | 操作指南 |
| `local.properties` | 本地 SDK/JDK 路径（不入库） |
