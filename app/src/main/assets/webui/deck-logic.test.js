/* tailtest-generated unit tests for assets/webui/deck-logic.js */
const test = require('node:test');
const assert = require('node:assert');
const D = require('./deck-logic.js');

test('langToLocale: known codes map to POSIX locales', () => {
  assert.strictEqual(D.langToLocale('zh-Hans'), 'zh_CN.UTF-8');
  assert.strictEqual(D.langToLocale('zh-Hant'), 'zh_TW.UTF-8');
  assert.strictEqual(D.langToLocale('ja'), 'ja_JP.UTF-8');
});

test('langToLocale: unknown codes fall back to en_US', () => {
  assert.strictEqual(D.langToLocale('fr'), 'en_US.UTF-8');
  assert.strictEqual(D.langToLocale(undefined), 'en_US.UTF-8');
  assert.strictEqual(D.langToLocale(''), 'en_US.UTF-8');
});

test('resolveMirror: known ids return their base URL', () => {
  assert.strictEqual(D.resolveMirror('modelscope'), 'https://modelscope.cn');
  assert.strictEqual(D.resolveMirror('hf-mirror'), 'https://hf-mirror.com');
  assert.strictEqual(D.resolveMirror('official'), 'https://ollama.com');
});

test('resolveMirror: auto means empty (probe official fallback behaviour)', () => {
  assert.strictEqual(D.resolveMirror('auto'), '');
});

test('resolveMirror: unknown ids fall back to official, never crash', () => {
  assert.strictEqual(D.resolveMirror('bogus'), 'https://ollama.com');
  assert.strictEqual(D.resolveMirror(null), 'https://ollama.com');
  assert.strictEqual(D.resolveMirror(undefined), 'https://ollama.com');
});

test('normalizeModelName: with tag splits owner/model and tag', () => {
  const r = D.normalizeModelName('qwen2.5:7b');
  assert.strictEqual(r.model, 'qwen2.5');
  assert.strictEqual(r.name, 'qwen2.5');
  assert.strictEqual(r.tag, '7b');
  assert.strictEqual(r.ref, 'qwen2.5:7b');
});

test('normalizeModelName: strips an ownerspaced prefix for the short name', () => {
  const r = D.normalizeModelName('ollama/llama3.2:3b');
  assert.strictEqual(r.name, 'llama3.2');
  assert.strictEqual(r.model, 'ollama/llama3.2');
  assert.strictEqual(r.ref, 'ollama/llama3.2:3b');
});

test('normalizeModelName: no tag defaults to latest but keeps the raw ref (pull works as-is)', () => {
  const r = D.normalizeModelName('gemma3');
  assert.strictEqual(r.tag, 'latest');
  assert.strictEqual(r.ref, 'gemma3'); // user-supplied ref is preserved
});

test('normalizeModelName: empty/blank input returns null', () => {
  assert.strictEqual(D.normalizeModelName(''), null);
  assert.strictEqual(D.normalizeModelName('   '), null);
  assert.strictEqual(D.normalizeModelName(undefined), null);
});

test('normalizeModelName: empty tag after colon is treated as latest', () => {
  const r = D.normalizeModelName('mistral:');
  assert.strictEqual(r.tag, 'latest');
});

test('filterModels: empty query returns the whole list', () => {
  const list = [{ name: 'a' }, { name: 'b' }];
  assert.strictEqual(D.filterModels(list, '').length, 2);
  assert.strictEqual(D.filterModels(list, null).length, 2);
  assert.strictEqual(D.filterModels(list, '   ').length, 2);
});

test('filterModels: case-insensitive substring matches', () => {
  const list = [{ name: 'qwen2.5:7b' }, { name: 'llama3.2:3b' }];
  const hits = D.filterModels(list, 'QWEN');
  assert.strictEqual(hits.length, 1);
  assert.strictEqual(hits[0].name, 'qwen2.5:7b');
});

test('filterModels: no matches yields empty array; null input handled', () => {
  assert.deepStrictEqual(D.filterModels([{ name: 'x' }], 'zzz'), []);
  assert.deepStrictEqual(D.filterModels(null, 'q'), []);
  assert.deepStrictEqual(D.filterModels(undefined, 'q'), []);
});

test('fmtSize: GB/MB formatting and null guard', () => {
  assert.strictEqual(D.fmtSize(4700000000), '4.7G');
  assert.strictEqual(D.fmtSize(5000000000), '5.0G');
  assert.strictEqual(D.fmtSize(3000000000), '3.0G');
  assert.strictEqual(D.fmtSize(5000000), '5M');
  assert.strictEqual(D.fmtSize(null), '—');
  assert.strictEqual(D.fmtSize(undefined), '—');
});