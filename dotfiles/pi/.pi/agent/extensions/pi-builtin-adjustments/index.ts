import { existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { SettingsManager, type ExtensionAPI } from '@earendil-works/pi-coding-agent';
import { getKeybindings } from '@earendil-works/pi-tui';

const ANSI_CSI_PATTERN = /\x1b\[[0-?]*[ -/]*[@-~]/g;
const RESUME_MESSAGE_PREFIX = 'To resume this session:';
const STYLE_PLACEHOLDER = '__PI_RESUME_COMMAND__';
const MANDATORY_MODEL_PREFIXES = ['claude-bridge/', 'openai-codex/'] as const;
const NO_MATCH_WARNING = /Warning: No models match pattern "([^"]+)"/;
const PROJECT_SKILL_LOCATIONS = [
  ['.claude', 'skills'],
  ['.agents', 'skills'],
] as const;

function findGitRepoRoot(startDir: string): string | undefined {
  let directory = resolve(startDir);

  while (true) {
    if (existsSync(join(directory, '.git'))) return directory;

    const parent = dirname(directory);
    if (parent === directory) return undefined;
    directory = parent;
  }
}

/** Find existing project skill directories from cwd through the Git root. */
export function collectAncestorSkillPaths(cwd: string): string[] {
  const skillPaths: string[] = [];
  const gitRepoRoot = findGitRepoRoot(cwd);
  let directory = resolve(cwd);

  while (true) {
    for (const location of PROJECT_SKILL_LOCATIONS) {
      const skillPath = join(directory, ...location);
      if (existsSync(skillPath)) skillPaths.push(skillPath);
    }

    if (directory === gitRepoRoot) break;

    const parent = dirname(directory);
    if (parent === directory) break;
    directory = parent;
  }

  return skillPaths;
}

export function extractResumeCommand(chunk: unknown): string | undefined {
  if (typeof chunk !== 'string') return undefined;

  const plain = chunk.replace(ANSI_CSI_PATTERN, '').trimEnd();
  if (!plain.startsWith(RESUME_MESSAGE_PREFIX)) return undefined;

  const command = plain.slice(RESUME_MESSAGE_PREFIX.length).trim();
  if (!/(?:^|\s)--session\s+\S+$/.test(command)) return undefined;
  return command;
}

function isOptionalModelWarning(value: unknown): boolean {
  if (typeof value !== 'string') return false;

  const match = value.match(NO_MATCH_WARNING);
  if (!match) return false;

  return !MANDATORY_MODEL_PREFIXES.some((prefix) => match[1].startsWith(prefix));
}

/** Replace Pi's verbose exit hint with the resume command alone. */
export function adjustExitResumeCommand(pi: ExtensionAPI): void {
  pi.on('session_shutdown', (event, ctx) => {
    if (event.reason !== 'quit' || ctx.mode !== 'tui') return;

    // Pi writes its built-in resume hint only after all shutdown handlers have
    // finished, so intercept that one stdout write and leave every other write
    // untouched. Precompute the themed wrapper while the extension context is live.
    const styledTemplate = ctx.ui.theme.fg('dim', STYLE_PLACEHOLDER);
    const stdout = process.stdout;
    const originalWrite = stdout.write;

    stdout.write = ((chunk: string | Uint8Array, ...args: unknown[]): boolean => {
      const command = extractResumeCommand(chunk);
      if (!command) {
        return Reflect.apply(originalWrite, stdout, [chunk, ...args]) as boolean;
      }

      stdout.write = originalWrite;
      const styledCommand = styledTemplate.replace(STYLE_PLACEHOLDER, command);
      return Reflect.apply(originalWrite, stdout, [`${styledCommand}\n`, ...args]) as boolean;
    }) as typeof stdout.write;
  });
}

/** Suppress startup no-match warnings for providers that are optional locally. */
export function adjustOptionalModelWarnings(pi: ExtensionAPI): void {
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

/**
 * Keep model and thinking-level switches session-local by suppressing Pi's
 * settings-manager writes. Restore implementation details during shutdown so
 * stale extension instances do not retain the patches after reload/replacement.
 */
export function adjustSessionOnlyModelSelection(pi: ExtensionAPI): void {
  const originalModelSetter = SettingsManager.prototype.setDefaultModelAndProvider;
  const originalThinkingSetter = SettingsManager.prototype.setDefaultThinkingLevel;
  const skipDefaultModelUpdate = (): void => {};
  const skipDefaultThinkingUpdate = (): void => {};

  SettingsManager.prototype.setDefaultModelAndProvider = skipDefaultModelUpdate;
  SettingsManager.prototype.setDefaultThinkingLevel = skipDefaultThinkingUpdate;

  pi.on('session_shutdown', () => {
    if (SettingsManager.prototype.setDefaultModelAndProvider === skipDefaultModelUpdate) {
      SettingsManager.prototype.setDefaultModelAndProvider = originalModelSetter;
    }
    if (SettingsManager.prototype.setDefaultThinkingLevel === skipDefaultThinkingUpdate) {
      SettingsManager.prototype.setDefaultThinkingLevel = originalThinkingSetter;
    }
  });
}

/** Load Claude and Agent Skills from every trusted project ancestor. */
export function adjustMonorepoSkillDiscovery(pi: ExtensionAPI): void {
  pi.on('resources_discover', (event, ctx) => {
    if (!ctx.isProjectTrusted()) return;

    return { skillPaths: collectAncestorSkillPaths(event.cwd) };
  });
}

/** Apply small behavior corrections to Pi's built-in UX and persistence. */
export default function piBuiltinAdjustments(pi: ExtensionAPI): void {
  adjustExitResumeCommand(pi);
  adjustOptionalModelWarnings(pi);
  adjustSessionOnlyModelSelection(pi);
  adjustMonorepoSkillDiscovery(pi);
}
