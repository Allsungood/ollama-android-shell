/**
 * deck-logic.js — pure, framework-free logic shared by the WebView and unit tests.
 * Used by assets/webui/index.html as window.DeckLogic, and by node tests via module.exports.
 */

const LANG_LOCALE = {
  'zh-Hans': 'zh_CN.UTF-8',
  'zh-Hant': 'zh_TW.UTF-8',
  ja: 'ja_JP.UTF-8',
  en: 'en_US.UTF-8',
};

const MIRRORS = {
  auto: { label: '自动选择', url: '' },
  official: { label: 'Ollama 官方', url: 'https://ollama.com' },
  github: { label: 'GitHub Releases', url: 'https://github.com/ollama/ollama/releases' },
  'hf-mirror': { label: 'HF-Mirror', url: 'https://hf-mirror.com' },
  modelscope: { label: 'ModelScope', url: 'https://modelscope.cn' },
};

/** Map an ISO-ish language code to a POSIX locale the Termux runtime can export. */
function langToLocale(code) {
  return LANG_LOCALE[code] || 'en_US.UTF-8';
}

/** Resolve a mirror id to its download base URL ('' for auto). Unknown ids fall back to official. */
function resolveMirror(id) {
  const m = MIRRORS[id] || MIRRORS.official;
  return m.url;
}

/** Split "owner/model:tag" into {name, tag, model(alias+tag)}; default tag 'latest'. */
function normalizeModelName(ref) {
  const src = (ref || '').trim();
  if (!src) return null;
  const colon = src.lastIndexOf(':');
  if (colon === -1) return { model: src, name: src, tag: 'latest', ref: src };
  const name = src.slice(0, colon);
  const tag = src.slice(colon + 1);
  return { model: name, name: name.split('/').pop(), tag: tag || 'latest', ref: name + ':' + (tag || 'latest') };
}

/** Case-insensitive substring filter over installed models ({name, size}). */
function filterModels(models, query) {
  const q = (query || '').trim().toLowerCase();
  return (models || []).filter((m) => !q || String(m.name).toLowerCase().includes(q));
}

/** Human-readable size. */
function fmtSize(n) {
  if (n == null) return '—';
  const g = n / 1e9;
  return g >= 1 ? g.toFixed(1) + 'G' : Math.round(n / 1e6) + 'M';
}

const DeckLogic = { LANG_LOCALE, MIRRORS, langToLocale, resolveMirror, normalizeModelName, filterModels, fmtSize };

if (typeof window !== 'undefined') window.DeckLogic = DeckLogic;
if (typeof module !== 'undefined' && module.exports) module.exports = DeckLogic;