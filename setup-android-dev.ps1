# ============================================================
#  Ollama Deck — 终极环境配置脚本（支持 winget / choco / 手动）
#  用法：
#    powershell -ExecutionPolicy Bypass -File setup-android-dev.ps1
#  前置：Node.js 18+、curl、管理员权限
#  无需 winget； Chocolatey 可选，无则手动下载安装包
# ============================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$env:PYTHONIOENCODING = 'utf-8'

function Write-Step { param($msg) Write-Host "`n>>> $msg" -ForegroundColor Cyan }
function Write-Ok  { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err  { param($msg) Write-Host "[ERR] $msg" -ForegroundColor Red; exit 1 }

# ---------- 前置检查 ----------
Write-Step "检查前置环境"
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Err "请以管理员身份运行 PowerShell。"
}

$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeCmd) {
    Write-Err "未找到 Node.js。请先安装：https://nodejs.org/zh-cn/download/prebuilt-installer"
}
Write-Ok "Node.js: $(node --version)"

$curlCmd = Get-Command curl -ErrorAction SilentlyContinue
if (-not $curlCmd) { Write-Warn "未找到 curl，将使用 Invoke-WebRequest 替代下载" }

# ---------- 1. JDK 17 ----------
Write-Step "1/5 安装 JDK 17 (Eclipse Temurin)"
$jdkInstallPath = "${env:ProgramFiles}\Eclipse Adoptium"
$foundJdk = Get-ChildItem "$jdkInstallPath\jdk-17.0.*" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1

if ($foundJdk) {
    Write-Ok "JDK 17 已存在：$($foundJdk.FullName)"
} else {
    # 尝试 winget
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        Write-Host "  使用 winget 安装 JDK 17 …" -NoNewline
        winget install --id EclipseAdoptium.Temurin.17 --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $foundJdk = Get-ChildItem "$jdkInstallPath\jdk-17.0.*" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($foundJdk) { Write-Ok "winget 安装 JDK 17 成功" }
        }
    }
    # 尝试 Chocolatey
    if (-not $foundJdk) {
        $choco = Get-Command choco -ErrorAction SilentlyContinue
        if ($choco) {
            Write-Host "  使用 Chocolatey 安装 JDK 17 …" -NoNewline
            choco install temurin17 -y 2>&1 | Out-Null
            $foundJdk = Get-ChildItem "$jdkInstallPath\jdk-17.0.*" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($foundJdk) { Write-Ok "choco 安装 JDK 17 成功" }
        }
    }
    # 手动下载（优先 curl，失败则用 Invoke-WebRequest）
    if (-not $foundJdk) {
        Write-Host "  手动下载安装 JDK 17 …" -ForegroundColor Yellow
        $jdkZip = "$env:TEMP\temurin-jdk17.zip"
        $jdkUrl = "https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk"
        try {
            if ($curlCmd) {
                # 先尝试 curl，加 --insecure 绕过证书吊销检查
                curl -L -k -f -o $jdkZip $jdkUrl --progress-bar 2>&1 | Out-Null
                if (-not (Test-Path $jdkZip)) { throw "curl failed" }
            } else {
                throw "no curl"
            }
        } catch {
            Write-Host "  curl 失败，切换 PowerShell 下载 …" -ForegroundColor Yellow
            try {
                Invoke-WebRequest -Uri $jdkUrl -OutFile $jdkZip -UseBasicParsing
            } catch {
                Write-Err "JDK 17 下载失败：$($_.Exception.Message)`n请手动下载：https://adoptium.net/temurin/releases/"
            }
        }
            Write-Host "  下载完成，解压中 …" -NoNewline
            $jdkExtract = "$env:TEMP\temurin-jdk17"
            if (Test-Path $jdkExtract) { Remove-Item $jdkExtract -Recurse -Force }
            Expand-Archive -Path $jdkZip -DestinationPath $jdkExtract -Force
            # 移动到 ProgramFiles
            $extractedJdk = Get-ChildItem "$jdkExtract\*" -Directory | Select-Object -First 1
            if ($extractedJdk) {
                $destJdk = Join-Path $jdkInstallPath $extractedJdk.Name
                if (Test-Path $destJdk) { Remove-Item $destJdk -Recurse -Force }
                Move-Item $extractedJdk.FullName $destJdk -Force
                $foundJdk = Get-Item $destJdk
            }
            Remove-Item $jdkZip -Force -ErrorAction SilentlyContinue
            Remove-Item $jdkExtract -Recurse -Force -ErrorAction SilentlyContinue
            if ($foundJdk) { Write-Ok "JDK 17 手动安装成功：$($foundJdk.FullName)" }
        } catch {
            Write-Err "JDK 17 安装失败：$($_.Exception.Message)`n请手动下载：https://adoptium.net/temurin/releases/"
        }
    }
}

if (-not $foundJdk) {
    Write-Err "无法自动安装 JDK 17，请手动从 https://adoptium.net/temurin/releases/ 下载 JDK 17 LTS (Windows x64) 并安装。"
}

$javaHome = $foundJdk.FullName
[System.Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHome, "User")
$env:JAVA_HOME = $javaHome
Write-Ok "JAVA_HOME = $javaHome"

# ---------- 2. Android SDK ----------
Write-Step "2/5 安装 Android SDK Command Line Tools"
$sdkRoot = "${env:LOCALAPPDATA}\Android\Sdk"
New-Item -ItemType Directory -Force -Path $sdkRoot | Out-Null

$cmdlineZip = "$sdkRoot\commandlinetools.zip"
$cmdlineUrl = "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"

if (-not (Test-Path "$sdkRoot\cmdline-tools\latest\bin\sdkmanager.bat")) {
    if (-not (Test-Path $cmdlineZip)) {
        Write-Host "  下载 commandlinetools-win.zip（约 150MB）…" -NoNewline
        if ($curlCmd) {
            curl -L -f -o $cmdlineZip $cmdlineUrl --progress-bar
        } else {
            Invoke-WebRequest -Uri $cmdlineUrl -OutFile $cmdlineZip -UseBasicParsing
        }
        Write-Host " 完成" -ForegroundColor Green
    } else { Write-Host "  [SKIP] commandlinetools.zip 已存在" -ForegroundColor Gray }

    Write-Host "  解压 …" -NoNewline
    Expand-Archive -Path $cmdlineZip -DestinationPath "$sdkRoot\cmdline-tools" -Force
    $extracted = Get-ChildItem "$sdkRoot\cmdline-tools" -Directory | Select-Object -First 1
    if ($extracted -and $extracted.Name -ne "latest") {
        Rename-Item -Path $extracted.FullName -NewName "latest" -Force
    }
    Write-Host " 完成" -ForegroundColor Green
} else {
    Write-Host "  [SKIP] SDK 工具已就绪" -ForegroundColor Gray
}
Write-Ok "ANDROID_HOME = $sdkRoot"
[System.Environment]::SetEnvironmentVariable("ANDROID_HOME", $sdkRoot, "User")
[System.Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $sdkRoot, "User")

# ---------- 3. 安装 SDK 组件 ----------
Write-Step "3/5 安装 SDK 组件（platforms/android-36 / build-tools/34.0.0 / platform-tools）"
$sdkmanager = "$sdkRoot\cmdline-tools\latest\bin\sdkmanager.bat"

# 接受许可
& $sdkmanager --licenses --no_https --yes 2>&1 | Out-Null

Write-Host "  安装中（约 1-2GB，需几分钟）…" -ForegroundColor Yellow
$components = @("platforms;android-36", "build-tools;34.0.0", "platform-tools", "extras;android;m2repository")
& $sdkmanager @components --no_https --yes 2>&1 | Select-Object -Last 5
Write-Ok "SDK 组件安装完成"

# ---------- 4. 配置环境变量 ----------
Write-Step "4/5 配置环境变量"
$oldPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
$pathsToAdd = @()
$sdkBin = "$sdkRoot\cmdline-tools\latest\bin"
if (-not ($oldPath -like "*$sdkBin*")) { $pathsToAdd += $sdkBin }
if (-not ($oldPath -like "*$sdkRoot\platform-tools*")) { $pathsToAdd += "$sdkRoot\platform-tools" }
if (-not ($oldPath -like "*$javaHome\bin*")) { $pathsToAdd += "$javaHome\bin" }

if ($pathsToAdd.Count -gt 0) {
    $newPath = ($pathsToAdd -join ";") + ";" + $oldPath
    [System.Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    $env:Path = $newPath
    Write-Ok "环境变量已更新（需重启终端生效）"
} else {
    Write-Ok "环境变量已存在，无需更新"
}

# ---------- 5. 生成 local.properties ----------
Write-Step "5/5 生成 local.properties"
$localProps = Join-Path $PSScriptRoot "local.properties"
$propsContent = "sdk.dir=$sdkRoot`n"
if ($javaHome) { $propsContent += "org.gradle.java.home=$javaHome`n" }
Set-Content -Path $localProps -Value $propsContent -Encoding UTF8
Write-Ok "local.properties 已生成"

# ---------- 完成 ----------
Write-Step "配置完成"
Write-Host @"

========================================
  Ollama Deck — Android 开发环境已配置
========================================

下一步（重启终端后执行）：
  cd $PSScriptRoot
  .\gradlew :app:assembleDebug

注意：
  - 运行时快照 termux-runtime.tar.xz 未入库（体积大），
    构建会因门禁失败并提示下载地址。详见 docs/USAGE.md。
  - 如需 CI 构建，可在 GitHub 配置 Secrets 或手动上传快照。

"@ -ForegroundColor Green
Write-Ok "配置完成。建议重启终端后运行 gradlew 验证。"
