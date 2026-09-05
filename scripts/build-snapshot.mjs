#!/usr/bin/env node
/**
 * build-snapshot.mjs — 产出内嵌运行时快照 termux-runtime.tar.xz（不入库）。
 *
 * 快照内容：Termux rootfs 工具链 + python + git + curl + ollama 依赖闭包，
 * 由 Shell 在设备上解压即用（extract-and-run）。
 *
 * 用法：
 *   node scripts/build-snapshot.mjs --src out/bootstrap-root --arch arm64
 *   node scripts/build-snapshot.mjs --src out/bootstrap-root --arch x86_64
 *
 * 需要调用方先准备好对应 ABI 的 Termux rootfs（--src <dir>）：
 *   pkg install -y python git curl ollama   # 并把 open-webui 装入该 rootfs 的 venv
 * 本脚本负责：门禁 → 打包 tar.xz → 写入 snapshot.sha256。
 */
import { execSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, existsSync, mkdirSync, rmSync, statSync } from 'node:fs';
import { dirname, join, basename } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const arg = (name, def) => {
  const i = process.argv.indexOf('--' + name);
  return i !== -1 && process.argv[i + 1] ? process.argv[i + 1] : def;
};
const arch = arg('arch', 'arm64');
const src = arg('src', null);

function log(m) { console.log(`[snapshot/${arch}] ${m}`); }
function fail(label) { log(`FAIL  ${label}`); process.exit(1); }
function pass(label) { log(`PASS  ${label}`); }

if (!src) {
  console.log(`用法：node scripts/build-snapshot.mjs --src <Termux rootfs 目录> --arch arm64|x86_64`);
  console.log(`在 rootfs 里预置：pkg install -y python git curl ollama；open-webui 装入 venv。`);
  process.exit(0);
}

// ---- 门禁 ----
for (const r of ['usr/bin/sh', 'usr/bin/python']) {
  if (!existsSync(join(src, r))) fail(`rootfs 缺少 ${r}`);
}
pass('rootfs 布局（sh/python）');

// 写入镜像/语言配置模板（运行期由壳覆盖）
writeFileSync(join(src, 'etc/mirror.conf'), `OLLAMADECK_MIRROR_URL=\n`);
writeFileSync(join(src, 'root/.bash_profile'), `export PATH=$PREFIX/usr/bin:$PATH\n`);

// ---- 打包 tar.xz ----
const file = join(root, `out/snapshot/termux-runtime-${arch}.tar.xz`);
mkdirSync(dirname(file), { recursive: true });
rmSync(file, { force: true });
pass('打包 tar.xz…');
execSync(`tar -C "${src}" --numeric-owner -cf - . | xz -9 > "${file}"`, { stdio: 'inherit', cwd: root });

// ---- 校验与指纹 ----
const h = createHash('sha256').update(readFileSync(file)).digest('hex');
writeFileSync(join(root, 'app/src/main/assets/snapshot.sha256'), `${h}  ${basename(file)}\n`);
const KB = (statSync(file).size / 1024).toFixed(0);
log(`完成：${file}（${KB} KB）sha256=${h.slice(0, 16)}…`);