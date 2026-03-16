import { i18n } from "../../i18n/index.ts";

/**
 * Client-side label overrides per locale for config form fields.
 * Keys match the path patterns used in server-side FIELD_LABELS (schema.labels.ts),
 * including wildcard segments (`*`). Only sections that have been translated need entries.
 */
const LOCALE_CONFIG_LABELS: Record<string, Record<string, string>> = {
  "zh-CN": {
    // models.providers subsection
    "models.providers": "模型提供商",
    "models.providers.*.baseUrl": "Base URL",
    "models.providers.*.apiKey": "API 密钥",
    "models.providers.*.auth": "认证模式",
    "models.providers.*.api": "API 适配器",
    "models.providers.*.injectNumCtxForOpenAICompat": "注入 num_ctx（OpenAI 兼容）",
    "models.providers.*.headers": "请求头",
    "models.providers.*.authHeader": "授权请求头",
    "models.providers.*.models": "模型列表",
  },
};

function matchesPattern(pattern: string, concrete: string): boolean {
  const pSegs = pattern.split(".");
  const cSegs = concrete.split(".");
  if (pSegs.length !== cSegs.length) {
    return false;
  }
  for (let i = 0; i < pSegs.length; i++) {
    if (pSegs[i] !== "*" && pSegs[i] !== cSegs[i]) {
      return false;
    }
  }
  return true;
}

/**
 * Returns a locale-specific label override for the given dot-path (e.g. "models.providers.openai.apiKey"),
 * or undefined if no override exists for the current locale.
 */
export function getLocaleLabel(dotPath: string): string | undefined {
  const locale = i18n.getLocale();
  const map = LOCALE_CONFIG_LABELS[locale];
  if (!map) {
    return undefined;
  }
  // Exact match first.
  if (dotPath in map) {
    return map[dotPath];
  }
  // Wildcard match.
  for (const [pattern, label] of Object.entries(map)) {
    if (pattern.includes("*") && matchesPattern(pattern, dotPath)) {
      return label;
    }
  }
  return undefined;
}
