#!/system/bin/sh
# ollama-setup.sh — 自动配置欧拉玛（Ollama）软件本身：安装、环境、镜像、启动。
set -e

RUNTIME="${OLLAMADECK_RUNTIME:-/data/user/0/com.ollamadeck.shell/files}"
BIN="${OLLAMADECK_BIN:-$RUNTIME/usr/bin}"
MIRROR="${OLLAMADECK_MIRROR:-official}"
export PATH="$BIN:$PATH"
export OLLAMA_HOST="127.0.0.1"
export OLLAMA_PORT="11434"
export OLLAMA_MODELS="$RUNTIME/root/.ollama/models"

# —— 若快照未内置二进制，则从所选镜像安装 ollama ——
if [ ! -x "$BIN/ollama" ]; then
  echo "installing ollama (mirror=$MIRROR)…"
  case "$MIRROR" in
    modelscope) pkg install -y ollama --from="$MIRROR" 2>/dev/null || curl -fsSL "https://modelscope.cn/models/ollama/ollama/resolve/master/install.sh" | sh ;;
    hf-mirror)  curl -fsSL -H "X-Api-Key: none" "https://hf-mirror.com/ollama/ollama/releases/download/sha256/ollama-linux-arm64.tgz" -o /tmp/ollama.tgz && tar -xzf /tmp/ollama.tgz -C "$RUNTIME" ;;
    github|*)   curl -fsSL "https://github.com/ollama/ollama/releases/latest/download/ollama-linux-arm64.tgz" -o /tmp/ollama.tgz && tar -xzf /tmp/ollama.tgz -C "$RUNTIME" ;;
  esac
fi

# —— 启动守护进程（后台），写 PID ——
mkdir -p "$OLLAMA_MODELS"
nohup "$BIN/ollama" serve >"$RUNTIME/ollama.log" 2>&1 &
echo $! > "$RUNTIME/ollama.pid"

# 就绪探测
i=0
until "$BIN/ollama" --version || [ $i -ge 20 ]; do i=$((i+1)); sleep 1; done
echo "ollama-setup ok: host=$OLLAMA_HOST port=$OLLAMA_PORT mirror=$MIRROR"