#!/usr/bin/env node
/**
 * build-apk.mjs — 一键打包 Ollama Deck。参照参考壳管线：门禁 → 注入快照 → gradle。
 *
 * 用法：node scripts/build-apk.mjs [--arch arm64|x86_64] [--debug]
 * 前置：已用 scripts/build-snapshot.mjs 产出 out/snapshot/termux-runtime-<arch>.tar.xz；
 *       本机需 JDK 17+ / Android SDK（local.properties 或 ANDROID_HOME）。
 */
import { execSync } from 'node:child_process';
import { existsSync, readFileSync, mkdirSync, copyFileSync, rmSync, statSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const asset = join(root, 'app/src/main/assets');
const DIST = join(root, 'out');

const arg = (name, def) => {
  const i = process.argv.indexOf('--' + name);
  return i !== -1 && process.argv[i + 1] ? process.argv[i + 1] : def;
};
const arch = arg('arch', 'arm64');
const isDebug = process.argv.includes('--debug');
const variant = isDebug ? 'assembleDebug' : 'assembleRelease';

function gate(label, check) {
  const ok = typeof check === 'function' ? check() : check;
  console.log(`[gate] ${ok ? 'PASS' : 'FAIL'}  ${label}`);
  if (!ok) process.exit(1);
}

// ---- 门禁 ----
const snapProp = join(root, 'out/snapshot', `termux-runtime-${arch}.tar.xz`);
gate(`has ${arch} snapshot (${snapProp})`, existsSync(snapProp));
gate('sha256 placeholder replaced',
  () => !readFileSync(join(asset, 'snapshot.sha256'), 'utf8').includes('PLACEHOLDER'));
gate('installer scripts present', () =>
  ['termux-env-setup.sh', 'ollama-setup.sh', 'openwebui-setup.sh']
    .every(f => existsSync(join(asset, f))));

// ---- 注入快照到 assets（壳引用固定名 termux-runtime.tar.xz）----
console.log(`[build] inject ${arch} snapshot -> assets/termux-runtime.tar.xz`);
mkdirSync(asset, { recursive: true });
copyFileSync(snapProp, join(asset, 'termux-runtime.tar.xz'));

// ---- gradle ----
try {
  execSync(`${join(root, 'gradlew')} :app:${variant} -p ${root}`, { stdio: 'inherit', cwd: root });
} catch (e) {
  console.error('gradle failed:', e.message);
  process.exit(1);
}
rmSync(join(asset, 'termux-runtime.tar.xz'), { force: true });

// ---- 收集产物 ----
const apkDir = join(root, 'app/build/outputs/apk', isDebug ? 'debug' : 'release');
console.log(`[build] done. outputs: ${apkDir}`);