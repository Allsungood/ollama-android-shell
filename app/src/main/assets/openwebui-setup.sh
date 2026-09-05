#!/system/bin/sh
# openwebui-setup.sh — 部署 Open WebUI 网页界面并桥接到本地 Ollama。
# 运行时快照应预置 Python；未预置时脚本从所选镜像源安装。
set -e

RUNTIME="${OLLAMADECK_RUNTIME:-/data/user/0/com.ollamadeck.shell/files}"
BIN="${OLLAMADECK_BIN:-$RUNTIME/usr/bin}"
MIRROR="${OLLAMADECK_MIRROR:-official}"
export PATH="$BIN:$PATH"

# —— Python 依赖检查 / 安装 ——
if ! command -v python >/dev/null 2>&1; then
  echo "installing python…"
  pkg install -y python || true
fi

# —— 安装 open-webui（重依赖，快照一般预置并跳过）——
if ! command -v open-webui >/dev/null 2>&1; then
  echo "installing open-webui…"
  pip install --no-cache-dir open-webui 2>&1 | tail -5 || true
fi

# —— 桥接到本地 ollama 并以后台服务启动 ——
export OLLAMA_BASE_URL="http://127.0.0.1:11434"
mkdir -p "$RUNTIME/root/.open-webui/data"
nohup open-webui serve --host 127.0.0.1 --port 8080 >"$RUNTIME/openwebui.log" 2>&1 &
echo $! > "$RUNTIME/openwebui.pid"

echo "openwebui-setup ok: url=http://127.0.0.1:8080 mirror=$MIRROR"