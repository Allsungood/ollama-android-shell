# ============================================================
#  Ollama Deck — 终极环境配置（PowerShell 单行版，支持 winget/choco/手动）
#  复制整段到管理员 PowerShell，回车即可
#  前置：Windows 10 1809+ / Windows 11，Node.js 18+，curl
#  无需 winget； Chocolatey 可选，均无则手动下载
# ============================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; $env:PYTHONIOENCODING = 'utf-8';
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw "请以管理员身份运行 PowerShell" }
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw "未找到 Node.js，请先安装 https://nodejs.org/" }
Write-Host "`n>>> 开始配置 Ollama Deck Android 开发环境（预计 5-15 分钟）`n" -ForegroundColor Cyan;
$jdkPath = "${env:ProgramFiles}\Eclipse Adoptium"; $foundJdk = Get-ChildItem "$jdkPath\jdk-17.0.*" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1;
if (-not $foundJdk) {
    $winget = Get-Command winget -ErrorAction SilentlyContinue; $choco = Get-Command choco -ErrorAction SilentlyContinue;
    if ($winget) { winget install --id EclipseAdoptium.Temurin.17 --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null; $foundJdk = Get-ChildItem "$jdkPath\jdk-17.0.*" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if (-not $foundJdk -and $choco) { choco install temurin17 -y 2>&1 | Out-Null; $foundJdk = Get-ChildItem "$jdkPath\jdk-17.0.*" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if (-not $foundJdk) {
        Write-Host "  手动下载安装 JDK 17 …" -ForegroundColor Yellow
        $jdkZip = "$env:TEMP\temurin-jdk17.zip"
        try {
            curl -L -k -f -o $jdkZip "https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk" --progress-bar 2>&1 | Out-Null
            if (-not (Test-Path $jdkZip)) { throw "curl failed" }
        } catch {
            Write-Host "  curl 失败，切换 PowerShell 下载 …" -ForegroundColor Yellow
            try { Invoke-WebRequest -Uri "https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk" -OutFile $jdkZip -UseBasicParsing } catch { throw "JDK 17 下载失败: $($_.Exception.Message)" }
        }
        try {
            $jdkExt = "$env:TEMP\temurin-jdk17-ext"; Expand-Archive -Path $jdkZip -DestinationPath $jdkExt -Force
            $extJdk = Get-ChildItem "$jdkExt\*" -Directory | Select-Object -First 1
            if ($extJdk) { $dest = Join-Path $jdkPath $extJdk.Name; if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }; Move-Item $extJdk.FullName $dest -Force; $foundJdk = Get-Item $dest }
            Remove-Item $jdkZip -Force -ErrorAction SilentlyContinue; Remove-Item $jdkExt -Recurse -Force -ErrorAction SilentlyContinue
            if ($foundJdk) { Write-Host "    [OK] JDK 17 手动安装成功" -ForegroundColor Green }
        } catch { throw "JDK 17 安装失败: $($_.Exception.Message)" }
    } else { Write-Host "    [OK] JDK 17 通过 winget/choco 安装" -ForegroundColor Green }
}
if (-not $foundJdk) { throw "无法安装 JDK 17，请手动下载 https://adoptium.net/temurin/releases/" }
$javaHome = $foundJdk.FullName; [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHome, "User"); $env:JAVA_HOME = $javaHome; Write-Host "    [OK] JAVA_HOME=$javaHome`n" -ForegroundColor Green;
$sdkRoot = "${env:LOCALAPPData}\Android\Sdk"; New-Item -ItemType Directory -Force -Path $sdkRoot | Out-Null
if (-not (Test-Path "$sdkRoot\cmdline-tools\latest\bin\sdkmanager.bat")) {
    $cmdlineZip = "$sdkRoot\commandlinetools.zip"
    if (-not (Test-Path $cmdlineZip)) { Write-Host "  下载 commandlinetools-win.zip（约 150MB）…" -NoNewline; curl -L -k -f -o $cmdlineZip "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip" --progress-bar 2>&1 | Out-Null; Write-Host " 完成" -ForegroundColor Green } else { Write-Host "  [SKIP] commandlinetools.zip 已存在" -ForegroundColor Gray }
    Write-Host "  解压 …" -NoNewline; Expand-Archive -Path $cmdlineZip -DestinationPath "$sdkRoot\cmdline-tools" -Force
    $ext = Get-ChildItem "$sdkRoot\cmdline-tools" -Directory | Select-Object -First 1
    if ($ext -and $ext.Name -ne "latest") { Rename-Item -Path $ext.FullName -NewName "latest" -Force }
    Write-Host " 完成" -ForegroundColor Green
} else { Write-Host "  [SKIP] SDK 工具已就绪" -ForegroundColor Gray }
[System.Environment]::SetEnvironmentVariable("ANDROID_HOME", $sdkRoot, "User"); [System.Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $sdkRoot, "User")
Write-Host "    [OK] ANDROID_HOME=$sdkRoot`n" -ForegroundColor Green;
Write-Host ">>> 安装 SDK 组件（platforms/android-36 / build-tools/34.0.0 / platform-tools）…" -ForegroundColor Yellow
$sdkmanager = "$sdkRoot\cmdline-tools\latest\bin\sdkmanager.bat"
& $sdkmanager --licenses --no_https --yes 2>&1 | Out-Null
& $sdkmanager "platforms;android-36" "build-tools;34.0.0" "platform-tools" "extras;android;m2repository" --no_https --yes 2>&1 | Select-Object -Last 3
Write-Host "    [OK] SDK 组件安装完成`n" -ForegroundColor Green;
$oldPath = [System.Environment]::GetEnvironmentVariable("Path", "User"); $pathsToAdd = @()
if (-not ($oldPath -like "*$sdkRoot\cmdline-tools\latest\bin*")) { $pathsToAdd += "$sdkRoot\cmdline-tools\latest\bin" }
if (-not ($oldPath -like "*$sdkRoot\platform-tools*")) { $pathsToAdd += "$sdkRoot\platform-tools" }
if (-not ($oldPath -like "*$javaHome\bin*")) { $pathsToAdd += "$javaHome\bin" }
if ($pathsToAdd.Count -gt 0) { $newPath = ($pathsToAdd -join ";") + ";" + $oldPath; [System.Environment]::SetEnvironmentVariable("Path", $newPath, "User"); $env:Path = $newPath; Write-Host "    [OK] 环境变量已更新（需重启终端）`n" -ForegroundColor Green } else { Write-Host "    [OK] 环境变量已存在`n" -ForegroundColor Green }
$localProps = Join-Path $PSScriptRoot "local.properties"; $propsContent = "sdk.dir=$sdkRoot`n"
if ($javaHome) { $propsContent += "org.gradle.java.home=$javaHome`n" }
Set-Content -Path $localProps -Value $propsContent -Encoding UTF8; Write-Host "    [OK] local.properties 已生成`n" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Ollama Deck — Android 开发环境配置完成" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan
Write-Host "下一步（重启终端后执行）:" -ForegroundColor White
Write-Host "  cd $PSScriptRoot" -ForegroundColor Yellow
Write-Host "  .\gradlew :app:assembleDebug`n" -ForegroundColor Yellow
Write-Host "注意: 运行时快照 termux-runtime.tar.xz 未入库（体积大），构建门禁会提示下载地址。详见 docs/USAGE.md" -ForegroundColor Red
