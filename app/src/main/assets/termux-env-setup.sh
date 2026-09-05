#!/system/bin/sh
# termux-env-setup.sh — 自动配置 Termux 系统环境（镜像源 + 语言 + PATH）。
# 由壳 BootstrapManager 在快照解压后调用；环境变量在进程环境里由 OLLAMADECK_* 注入。
set -e

PROOT_RUNTIME="${OLLAMADECK_RUNTIME:-/data/user/0/com.ollamadeck.shell/files}"
BIN="${OLLAMADECK_BIN:-$PROOT_RUNTIME/usr/bin}"
MIRROR="${OLLAMADECK_MIRROR:-auto}"
LANG_CODE="${OLLAMADECK_LANG:-zh-Hans}"

# shell 搜索路径统一指到快照内的 Termux 工具链
export PATH="$BIN:$PATH"
export TERMUX_PREFIX="$PROOT_RUNTIME/usr"

# —— 多镜像切换：写入 apt/pacman 或来自定义 bootstrap 的镜像配置 ——
case "$MIRROR" in
  modelscope)   M="https://modelscope.cn" ;;
  hf-mirror)    M="https://hf-mirror.com" ;;
  github)       M="https://github.com/ollama/ollama/releases" ;;
  official|*)   M="https://packages.termux.dev" ;;
esac
echo "OLLAMADECK_MIRROR_URL=$M" >> "$PROOT_RUNTIME/etc/mirror.conf" 2>/dev/null || {
  mkdir -p "$PROOT_RUNTIME/etc"
  echo "OLLAMADECK_MIRROR_URL=$M" > "$PROOT_RUNTIME/etc/mirror.conf"
}

# —— 多语言：导出终端 locale / UI 文案 ——
case "$LANG_CODE" in
  zh-Hans) L="zh_CN.UTF-8" ;;
  zh-Hant) L="zh_TW.UTF-8" ;;
  ja)      L="ja_JP.UTF-8" ;;
  *)       L="en_US.UTF-8" ;;
esac
export LANG="$L"

# 持久化环境：写入 ~/.bash_profile（后续 ollama/open-webui/console 都复用它）
mkdir -p "$PROOT_RUNTIME/root"
cat > "$PROOT_RUNTIME/root/.bash_profile" <<EOF
export PATH="$BIN:\$PATH"
export TERMUX_PREFIX="$PROOT_RUNTIME/usr"
export LANG="$L"
export OLLAMADECK_MIRROR="$MIRROR"
export OLLAMADECK_MIRROR_URL="$M"
EOF

echo "termux-env-setup ok: mirror=$MIRROR lang=$LANG_CODE bin=$BIN"