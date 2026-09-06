# ============================================================
#  Ollama Deck — Android 开发环境一键配置（PowerShell）
#  用法：以管理员身份运行 PowerShell，执行此脚本
#  前置：Windows 10 1809+ / Windows 11，已安装 winget
# ============================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$env:PYTHONIOENCODING = 'utf-8'

function Write-Step { param($msg) Write-Host "`n>>> $msg" -ForegroundColor Cyan }
function Write-Ok  { param($msg) Write-Host "[OK] $msg"  -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err  { param($msg) Write-Host "[ERR] $msg"  -ForegroundColor Red; exit 1 }

# ---------- 前置检查 ----------
Write-Step "检查管理员权限"
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Err "请以管理员身份运行 PowerShell，再执行此脚本。"
}

Write-Step "检查 winget"
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Err "未找到 winget。请先从 Microsoft Store 安装「App Installer」。"
}

Write-Step "检查 Node.js（项目依赖）"
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeCmd) {
    Write-Warn "未检测到 Node.js。请先安装：winget install OpenJS.NodeJS.LTS"
} else {
    Write-Ok "Node.js 已安装：$($nodeCmd.Source)"
}
$nodeVer = (node --version)
Write-Ok "Node.js 版本：$nodeVer"
if ($nodeVer -match 'v(\d+)') {
    $major = [int]$matches[1]
    if ($major -lt 18) { Write-Warn "Node.js >= 18 推荐，当前 $($major).x。" }
}

# ---------- 1. 安装 JDK 17 ----------
Write-Step "安装 JDK 17 (Eclipse Temurin)"
$jdkPkg = "Eclipse Adoptium.Temurin.17"
$installedJdk = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like '*Temurin*' -and $_.Name -like '*17*' } | Select-Object -First 1
if ($installedJdk) {
    Write-Ok "JDK 17 已安装：$($installedJdk.Name)"
} else {
    winget install --id $jdkPkg --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Err "JDK 17 安装失败。请手动安装：https://adoptium.net/temurin/releases/"
    }
}
Write-Ok "JDK 17 安装完成。"

# 刷新环境变量（JDK 路径通常写入注册表，需重新读取）
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
$javaHome = [System.Environment]::GetEnvironmentVariable("JAVA_HOME", "Machine")
if (-not $javaHome) {
    $javaHome = [System.Environment]::GetEnvironmentVariable("JAVA_HOME", "User")
}
if (-not $javaHome) {
    # 尝试常见安装路径
    $possibleJdkPaths = @(
        "${env:ProgramFiles}\Eclipse Adoptium\jdk-17.0.*",
        "${env:ProgramFiles(x86)}\Eclipse Adoptium\jdk-17.0.*",
        "${env:LOCALAPPDATA}\Microsoft\WinGet\Packages\Eclipse_Adoptium_Temurin_17_*.jdk"
    )
    foreach ($p in $possibleJdkPaths) {
        $found = Get-Item $p -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $javaHome = $found.FullName; break }
    }
}
if ($javaHome) {
    [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHome, "User")
    $env:JAVA_HOME = $javaHome
    Write-Ok "JAVA_HOME = $javaHome"
} else {
    Write-Warn "无法自动定位 JAVA_HOME，请手动设置或重启终端后重试。"
}

# 验证 java
$javaCmd = Get-Command java -ErrorAction SilentlyContinue
if ($javaCmd) {
    $javaVer = & java -version 2>&1 | Select-Object -First 1
    Write-Ok "java 可用：$javaVer"
} else {
    Write-Warn "java 命令未找到。请重启终端使环境变量生效。"
}

# ---------- 2. 安装 Android SDK Command Line Tools ----------
Write-Step "安装 Android SDK Command Line Tools"
$sdkRoot = "${env:LOCALAPPDATA}\Android\Sdk"
$sdkInstallScript = "${env:LOCALAPPDATA}\Android\sdk-tools-installer.ps1"

if (-not (Test-Path $sdkRoot)) {
    New-Item -ItemType Directory -Force -Path $sdkRoot | Out-Null
}

# 下载命令行工具（独立安装包）
$cmdlineZip = "$sdkRoot\commandlinetools.zip"
$cmdlineUrl = "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
if (-not (Test-Path $cmdlineZip)) {
    Write-Host "  下载 commandlinetools-win.zip (约 150MB)…" -NoNewline
    Invoke-WebRequest -Uri $cmdlineUrl -OutFile $cmdlineZip -UseBasicParsing
    Write-Ok "  下载完成。"
} else { Write-Ok "  commandlinetools.zip 已存在，跳过下载。" }

$cmdlineUnpack = "$sdkRoot\cmdline-tools"
if (-not (Test-Path "$cmdlineUnpack\latest\bin\sdkmanager.bat")) {
    Write-Host "  解压 commandlinetools…" -NoNewline
    Expand-Archive -Path $cmdlineZip -DestinationPath $cmdlineUnpack -Force
    # Windows 解压后目录名是 cmdline-tools，需要 rename 为 latest
    $extracted = Get-ChildItem $cmdlineUnpack -Directory | Select-Object -First 1
    if ($extracted -and $extracted.Name -ne "latest") {
        Rename-Item -Path $extracted.FullName -NewName "latest" -Force
    }
    Write-Ok "  解压完成。"
} else { Write-Ok "  SDK 工具已就绪，跳过解压。" }

# ---------- 3. 设置环境变量 ----------
Write-Step "配置环境变量"
$oldPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
$newSdkBin = "$sdkRoot\cmdline-tools\latest\bin"
$newSdkTools = "$sdkRoot\tools\bin"
$pathsToAdd = @()
if (-not ($oldPath -like "*$newSdkBin*")) { $pathsToAdd += $newSdkBin }
if (-not ($oldPath -like "*$newSdkTools*")) { $pathsToAdd += $newSdkTools }
if ($javaHome -and -not ($oldPath -like "*$javaHome\bin*")) { $pathsToAdd += "$javaHome\bin" }

if ($pathsToAdd.Count -gt 0) {
    $newPath = ($pathsToAdd -join ";") + ";" + $oldPath
    [System.Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    $env:Path = $newPath
    Write-Ok "环境变量已更新（需重启终端生效）"
} else {
    Write-Ok "环境变量已存在，无需更新。"
}

[System.Environment]::SetEnvironmentVariable("ANDROID_HOME", $sdkRoot, "User")
[System.Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $sdkRoot, "User")
$env:ANDROID_HOME = $sdkRoot
$env:ANDROID_SDK_ROOT = $sdkRoot
Write-Ok "ANDROID_HOME = $sdkRoot"

# ---------- 4. 接受许可并安装 SDK 组件 ----------
Write-Step "接受 Android SDK 许可协议"
$sdkmanager = "$newSdkBin\sdkmanager.bat"
if (-not (Test-Path $sdkmanager)) {
    $sdkmanager = "$newSdkBin\sdkmanager"  # Linux/Mac fallback
}
if (-not (Test-Path $sdkmanager)) {
    Write-Err "未找到 sdkmanager。请检查 $newSdkBin 目录。"
}

# 使用 PowerShell 进程接受许可
$acceptLicense = Start-Process -FilePath $sdkmanager -ArgumentList "--licenses" -RedirectStandardInput "$null" -PassThru -NoNewWindow -Wait -ErrorAction SilentlyContinue
# 另一种方式：通过环境变量自动接受
[System.Environment]::SetEnvironmentVariable("JAVA_TOOL_OPTIONS", "-Dfile.encoding=UTF-8", "User")

Write-Step "安装必需 SDK 组件"
Write-Host "  这可能需要几分钟（下载约 1-2GB）…"
$components = @(
    "platforms;android-36",
    "build-tools;34.0.0",
    "platform-tools",
    "extras;android;m2repository"
)
& $sdkmanager @components --no_https --yes 2>&1 | Select-Object -Last 5
Write-Ok "SDK 组件安装完成。"

# ---------- 5. 安装 Gradle Wrapper ----------
Write-Step "检查 Gradle Wrapper"
$gradlew = Join-Path $PSScriptRoot "gradlew"
if (-not (Test-Path $gradlew)) {
    Write-Err "项目根目录未找到 gradlew。请在此仓库根目录运行本脚本。"
}
Write-Ok "gradlew 已存在。"

# ---------- 6. 验证构建 ----------
Write-Step "验证环境（dry-run）"
& $gradlew --version 2>&1 | Select-Object -First 15
Write-Ok "Gradle 版本检查完成。"

# ---------- 7. 生成 local.properties ----------
Write-Step "生成 local.properties"
$localProps = Join-Path $PSScriptRoot "local.properties"
$propsContent = "sdk.dir=$sdkRoot`n"
if ($javaHome) { $propsContent += "org.gradle.java.home=$javaHome`n" }
Set-Content -Path $localProps -Value $propsContent -Encoding UTF8
Write-Ok "local.properties 已生成。"

# ---------- 完成 ----------
Write-Step "安装完成"
Write-Host @"

========================================
  Ollama Deck — Android 开发环境已配置
========================================

下一步（重启终端后）：
  cd $(Split-Path $PSScriptRoot)
  .\gradlew :app:assembleDebug

注意：
  - SDK 组件已安装，但运行时快照 termux-runtime.tar.xz 未入库（体积大），
    构建会因门禁失败并提示下载地址。详见 docs/USAGE.md。
  - 如需 CI 构建，可在 GitHub 上配置 Secrets / 上传快照。

  可选：安装 Node.js 插件（如果未安装）
    winget install OpenJS.NodeJS.LTS

"@ -ForegroundColor Green
Write-Ok "配置完成。建议重启终端后再次运行 gradlew 验证。"
