import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';

const MANDATORY_MODEL_PREFIXES = ['claude-bridge/', 'openai-codex/'] as const;
const NO_MATCH_WARNING = /Warning: No models match pattern "([^"]+)"/;

function isOptionalModelWarning(value: unknown): boolean {
  if (typeof value !== 'string') return false;

  const match = value.match(NO_MATCH_WARNING);
  if (!match) return false;

  return !MANDATORY_MODEL_PREFIXES.some((prefix) => match[1].startsWith(prefix));
}

/**
 * Pi resolves enabledModels against authenticated providers and warns for every
 * unavailable entry. Treat Claude Bridge and OpenAI Codex models as mandatory,
 * while suppressing startup no-match warnings for every other provider. Pi
 * still excludes unavailable optional models from the active model scope.
 */
export default function optionalModelWarnings(pi: ExtensionAPI): void {
  const originalWarn = console.warn;
  const filteredWarn: typeof console.warn = (...args: unknown[]): void => {
    if (isOptionalModelWarning(args[0])) return;
    originalWarn(...args);
  };

  const restore = (): void => {
    if (console.warn === filteredWarn) console.warn = originalWarn;
  };

  console.warn = filteredWarn;
  pi.on('session_start', restore);
  pi.on('session_shutdown', restore);
}
