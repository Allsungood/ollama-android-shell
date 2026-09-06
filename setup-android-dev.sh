# Ollama Deck — Linux / macOS 一键环境配置（Bash 版）
# 用法：bash setup-android-dev.sh

set -euo pipefail

echo ">>> 配置 Ollama Deck Android 开发环境（预计 5-15 分钟）"
echo ""

# 依赖检查
if ! command -v java &>/dev/null; then
  echo ">>> 1/5 安装 JDK 17"
  if command -v apt-get &>/dev/null; then
    sudo apt-get install -y openjdk-17-jdk-headless
  elif command -v brew &>/dev/null; then
    brew install --cask temurin@17
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y java-17-openjdk-headless
  else
    echo "[ERR] 无法自动安装 JDK，请手动安装 Java 17"
    exit 1
  fi
else
  echo "[OK] JDK 已安装: $(java -version 2>&1 | head -1)"
fi

echo ">>> 2/5 安装 Node.js（项目依赖）"
if ! command -v node &>/dev/null; then
  echo "[WARN] 未安装 Node.js，项目构建需要 Node 18+"
  echo "       请执行: curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt-get install -y nodejs"
else
  echo "[OK] Node.js: $(node --version)"
fi

echo ">>> 3/5 安装 Android SDK Command Line Tools"
SDK_ROOT="${ANDROID_HOME:-$HOME/Android/Sdk}"
CMDLINE_ZIP="$SDK_ROOT/commandlinetools.zip"
CMDLINE_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
mkdir -p "$SDK_ROOT/cmdline-tools"
if [ ! -f "$CMDLINE_ZIP" ]; then
  echo "  下载 commandlinetools-linux.zip …"
  curl -fL "$CMDLINE_URL" -o "$CMDLINE_ZIP"
fi
if [ ! -d "$SDK_ROOT/cmdline-tools/latest" ]; then
  echo "  解压 …"
  cd "$SDK_ROOT/cmdline-tools" && unzip -qo "$CMDLINE_ZIP"
  # rename to latest
  [ -d "$SDK_ROOT/cmdline-tools/cmdline-tools" ] && mv "$SDK_ROOT/cmdline-tools/cmdline-tools" "$SDK_ROOT/cmdline-tools/latest"
fi
export ANDROID_HOME="$SDK_ROOT"
export ANDROID_SDK_ROOT="$SDK_ROOT"
export PATH="$SDK_ROOT/cmdline-tools/latest/bin:$SDK_ROOT/platform-tools:$PATH"

echo ">>> 4/5 接受许可并安装 SDK 组件"
sdkmanager --licenses < /dev/null 2>/dev/null || true
sdkmanager "platforms;android-36" "build-tools;34.0.0" "platform-tools" 2>&1 | tail -3
echo "[OK] SDK 组件安装完成"

echo ">>> 5/5 生成 local.properties"
JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-$(uname -m)}"
[ -d "$JAVA_HOME" ] || JAVA_HOME="$(readlink -f $(which java) | sed 's|/bin/java||')"
cat > local.properties <<EOF
sdk.dir=$SDK_ROOT
org.gradle.java.home=$JAVA_HOME
EOF
echo "[OK] local.properties 已生成"

echo ""
echo "========================================"
echo "  Ollama Deck — Android 开发环境配置完成"
echo "========================================"
echo ""
echo "下一步："
echo "  export PATH=~/Android/Sdk/cmdline-tools/latest/bin:\$PATH"
echo "  export JAVA_HOME=$JAVA_HOME"
echo "  ./gradlew :app:assembleDebug"
echo ""
echo "注意：运行时快照 termux-runtime.tar.xz 未入库，构建门禁会提示下载地址。"
echo "详见 docs/USAGE.md"
