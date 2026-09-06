# ============================================================
#  Ollama Deck — 终极一键环境配置（PowerShell 单行版）
#  复制整段到管理员 PowerShell，回车即可
#  前置：Windows 10 1809+ / Windows 11，已安装 winget
# ============================================================
#  步骤 1: 确认 Node.js 已安装（项目依赖）
#  步骤 2: 安装 JDK 17 + Android SDK + 所有依赖组件
#  步骤 3: 生成 local.properties
#  步骤 4: 验证 Gradle 版本
#  注意：会下载约 2-3GB（JDK + SDK），需联网
# ============================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8;
$env:PYTHONIOENCODING = 'utf-8';
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw "请以管理员身份运行 PowerShell" }
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw "未找到 winget，请先安装「App Installer」" }
$repoRoot = $PSScriptRoot;
Write-Host "`n>>> 开始配置 Ollama Deck Android 开发环境（预计 5-15 分钟）`n" -ForegroundColor Cyan;
Write-Host ">>> 1/6 检查 Node.js …" -ForegroundColor Yellow;
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue;
if ($nodeCmd) { Write-Host "    [OK] Node.js: $((node --version))`n" -ForegroundColor Green }
else { Write-Host "    [WARN] 未安装 Node.js，请先执行: winget install OpenJS.NodeJS.LTS`n" -ForegroundColor Red; exit 1 }
Write-Host ">>> 2/6 安装 JDK 17 (Eclipse Temurin) …" -ForegroundColor Yellow;
$jdkPkg = "Eclipse Adoptium.Temurin.17";
$existingJdk = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like '*Temurin*' -and $_.Name -like '*17*' } | Select-Object -First 1;
if ($existingJdk) { Write-Host "    [OK] JDK 17 已安装: $($existingJdk.Name)`n" -ForegroundColor Green }
else { winget install --id $jdkPkg --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null; if ($LASTEXITCODE -ne 0) { throw "JDK 17 安装失败" } else { Write-Host "    [OK] JDK 17 安装完成`n" -ForegroundColor Green } }
Write-Host ">>> 3/6 配置 JAVA_HOME …" -ForegroundColor Yellow;
$javaHome = [System.Environment]::GetEnvironmentVariable("JAVA_HOME", "Machine") ?? [System.Environment]::GetEnvironmentVariable("JAVA_HOME", "User");
if (-not $javaHome) { $javaHome = (Get-ChildItem "${env:ProgramFiles}\Eclipse Adoptium\jdk-17.0.*" -ErrorAction SilentlyContinue | Select-Object -First 1)?.FullName ?? (Get-ChildItem "${env:LOCALAPPDATA}\Microsoft\WinGet\Packages\Eclipse_Adoptium_Temurin_17_*.jdk" -ErrorAction SilentlyContinue | Select-Object -First 1)?.FullName };
if ($javaHome) { [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHome, "User"); $env:JAVA_HOME = $javaHome; Write-Host "    [OK] JAVA_HOME=$javaHome`n" -ForegroundColor Green }
else { Write-Host "    [WARN] 无法定位 JAVA_HOME，请重启终端`n" -ForegroundColor Yellow }
Write-Host ">>> 4/6 安装 Android SDK Command Line Tools + 组件 …" -ForegroundColor Yellow;
$sdkRoot = "${env:LOCALAPPDATA}\Android\Sdk";
$cmdlineZip = "$sdkRoot\commandlinetools.zip";
$cmdlineUrl = "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip";
New-Item -ItemType Directory -Force -Path $sdkRoot | Out-Null;
if (-not (Test-Path $cmdlineZip)) { Write-Host "    下载 commandlinetools-win.zip (约 150MB) …" -NoNewline; Invoke-WebRequest -Uri $cmdlineUrl -OutFile $cmdlineZip -UseBasicParsing; Write-Host " 完成" -ForegroundColor Green }
else { Write-Host "    [SKIP] commandlinetools.zip 已存在`n" -ForegroundColor Gray }
$cmdlineUnpack = "$sdkRoot\cmdline-tools";
if (-not (Test-Path "$cmdlineUnpack\latest\bin\sdkmanager.bat")) { Write-Host "    解压 commandlinetools …" -NoNewline; Expand-Archive -Path $cmdlineZip -DestinationPath $cmdlineUnpack -Force; $extracted = Get-ChildItem $cmdlineUnpack -Directory | Select-Object -First 1; if ($extracted -and $extracted.Name -ne "latest") { Rename-Item -Path $extracted.FullName -NewName "latest" -Force }; Write-Host " 完成" -ForegroundColor Green }
else { Write-Host "    [SKIP] SDK 工具已就绪`n" -ForegroundColor Gray }
$oldPath = [System.Environment]::GetEnvironmentVariable("Path", "User");
$pathsToAdd = @();
if (-not ($oldPath -like "*$sdkRoot\cmdline-tools\latest\bin*")) { $pathsToAdd += "$sdkRoot\cmdline-tools\latest\bin" };
if (-not ($oldPath -like "*$sdkRoot\tools\bin*")) { $pathsToAdd += "$sdkRoot\tools\bin" };
if ($javaHome -and -not ($oldPath -like "*$javaHome\bin*")) { $pathsToAdd += "$javaHome\bin" };
if ($pathsToAdd.Count -gt 0) { $newPath = ($pathsToAdd -join ";") + ";" + $oldPath; [System.Environment]::SetEnvironmentVariable("Path", $newPath, "User"); $env:Path = $newPath; Write-Host "    [OK] 环境变量已更新（需重启终端）`n" -ForegroundColor Green }
else { Write-Host "    [OK] 环境变量已存在`n" -ForegroundColor Green }
[System.Environment]::SetEnvironmentVariable("ANDROID_HOME", $sdkRoot, "User");
[System.Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $sdkRoot, "User");
$env:ANDROID_HOME = $sdkRoot; $env:ANDROID_SDK_ROOT = $sdkRoot;
Write-Host "    [OK] ANDROID_HOME=$sdkRoot`n" -ForegroundColor Green;
Write-Host ">>> 5/6 安装 SDK 组件（platforms;android-36 / build-tools;34.0.0 / platform-tools）…" -ForegroundColor Yellow;
$sdkmanager = "$sdkRoot\cmdline-tools\latest\bin\sdkmanager.bat";
& $sdkmanager --licenses --no_https --yes 2>&1 | Out-Null;
& $sdkmanager "platforms;android-36" "build-tools;34.0.0" "platform-tools" "extras;android;m2repository" --no_https --yes 2>&1 | Select-Object -Last 3;
Write-Host "    [OK] SDK 组件安装完成`n" -ForegroundColor Green;
Write-Host ">>> 6/6 生成 local.properties …" -ForegroundColor Yellow;
$localProps = Join-Path $repoRoot "local.properties";
$propsContent = "sdk.dir=$sdkRoot`n";
if ($javaHome) { $propsContent += "org.gradle.java.home=$javaHome`n" };
Set-Content -Path $localProps -Value $propsContent -Encoding UTF8;
Write-Host "    [OK] local.properties 已生成`n" -ForegroundColor Green;
Write-Host ">>> 验证 Gradle 版本 …" -ForegroundColor Yellow;
& (Join-Path $repoRoot "gradlew") --version 2>&1 | Select-Object -First 12;
Write-Host "`n========================================" -ForegroundColor Cyan;
Write-Host "  Ollama Deck — Android 开发环境配置完成" -ForegroundColor Green;
Write-Host "========================================`n" -ForegroundColor Cyan;
Write-Host "下一步（重启终端后执行）:" -ForegroundColor White;
Write-Host "  cd $repoRoot" -ForegroundColor Yellow;
Write-Host "  .\gradlew :app:assembleDebug`n" -ForegroundColor Yellow;
Write-Host "注意: 运行时快照 termux-runtime.tar.xz 未入库（体积大），" -ForegroundColor Red;
Write-Host "      构建门禁会提示下载地址。详见 docs/USAGE.md`n" -ForegroundColor Red;
