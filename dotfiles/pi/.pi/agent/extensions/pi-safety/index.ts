import { chmodSync, realpathSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { type ExtensionAPI, type ExtensionContext, isToolCallEventType } from '@earendil-works/pi-coding-agent';
import type { Parser } from 'web-tree-sitter';
import { API_KEY_ENV, adjudicate, buildTranscript, describeBashCall } from './auto-mode.ts';
import { loadSafetyConfig, type LoadedSafetyConfig } from './config.ts';
import { inspectPath } from './path-policy.ts';
import { createBashParser, inspectBashCommand } from './shell-policy.ts';

const extensionDirectory = dirname(realpathSync(fileURLToPath(import.meta.url)));
const shimDirectory = join(extensionDirectory, 'bin');

/** Footer status keys read by the statusbar extension. */
export const AUTO_MODE_STATUS_KEY = 'auto-mode';
export const SAFETY_STATUS_KEY = 'pi-safety';
const AUTO_MODE_STATUS_TEXT = 'auto-mode';
const PROMPT_COMMAND_CHARS = 600;
const DELETION_SAFETY_SECTION = 'deletion-safety';
const DELETION_SAFETY_PROMPT =
  'Plain rm and rmdir are transparently redirected to the macOS Trash for agent Bash calls; use them or trash normally.';

function shellQuote(value: string): string {
  return `'${value.replaceAll("'", `'"'"'`)}'`;
}

function ensureShims(): void {
  for (const name of ['rm', 'rmdir', 'trash']) chmodSync(join(shimDirectory, name), 0o755);
}

/** Degraded-state indicator for the footer; undefined while the configured checks are in force. */
function statusText(
  loaded: LoadedSafetyConfig,
  parserError: string | undefined,
  shellChecksDisabled: boolean,
): string | undefined {
  if (shellChecksDisabled) return '🛡 disabled';
  if (parserError) return '🛡 parser error';
  if (loaded.status === 'invalid') return '🛡 config invalid';
  if (loaded.status === 'missing') return '🛡 defaults';
  return undefined;
}

function autoModeApiKey(): string | undefined {
  return process.env[API_KEY_ENV]?.trim() || undefined;
}

function truncateForPrompt(command: string): string {
  return command.length <= PROMPT_COMMAND_CHARS ? command : `${command.slice(0, PROMPT_COMMAND_CHARS)}…`;
}

export default async function (pi: ExtensionAPI) {
  let parser: Parser | undefined;
  let parserError: string | undefined;
  try {
    ensureShims();
    parser = await createBashParser();
  } catch (error) {
    parserError = error instanceof Error ? error.message : String(error);
  }

  let loaded = loadSafetyConfig(process.env.PI_SAFETY_CONFIG);
  let shellChecksDisabled = false;
  let autoModeEnabled = process.env.PI_AUTO_MODE === '1' && autoModeApiKey() !== undefined;

  function refreshAutoModeStatus(ctx: ExtensionContext) {
    ctx.ui.setStatus(AUTO_MODE_STATUS_KEY, autoModeEnabled ? AUTO_MODE_STATUS_TEXT : undefined);
  }

  function invalidConfigBlock() {
    return {
      block: true,
      reason: `pi-safety: invalid ${loaded.configPath} (${loaded.errors.join('; ')}); Bash, write, and edit are disabled until the user fixes it`,
    };
  }

  pi.registerCommand('no-safety', {
    description: 'Disable shell command and protected-path checks for the current session',
    handler: async (_args, ctx) => {
      shellChecksDisabled = true;
      ctx.ui.setStatus(SAFETY_STATUS_KEY, statusText(loaded, parserError, shellChecksDisabled));
      ctx.ui.notify('pi-safety: shell command and protected-path checks are disabled for this session', 'warning');
    },
  });

  pi.registerCommand('toggle-auto-mode', {
    description: 'Toggle auto mode: jev adjudicates each Bash command (allow / ask / deny)',
    handler: async (_args, ctx) => {
      if (!autoModeEnabled && autoModeApiKey() === undefined) {
        ctx.ui.notify(`pi-safety: auto mode needs ${API_KEY_ENV} in the environment`, 'error');
        return;
      }

      autoModeEnabled = !autoModeEnabled;
      refreshAutoModeStatus(ctx);
      ctx.ui.notify(
        autoModeEnabled
          ? 'pi-safety: auto mode on — Bash commands are adjudicated by jev'
          : 'pi-safety: auto mode off — Bash commands execute directly',
        'info',
      );
    },
  });

  pi.on('session_start', (_event, ctx) => {
    loaded = loadSafetyConfig(process.env.PI_SAFETY_CONFIG);
    ctx.ui.setStatus(SAFETY_STATUS_KEY, statusText(loaded, parserError, shellChecksDisabled));
    refreshAutoModeStatus(ctx);

    if (parserError) {
      ctx.ui.notify(`pi-safety: tree-sitter initialization failed; Bash is disabled (${parserError})`, 'error');
    }
    if (loaded.status === 'invalid') {
      ctx.ui.notify(
        `pi-safety: invalid ${loaded.configPath}: ${loaded.errors.join('; ')}; Bash, write, and edit are disabled until it is fixed`,
        'error',
      );
    } else if (loaded.status === 'missing') {
      ctx.ui.notify(`pi-safety: ${loaded.errors.join('; ')}; using built-in safeguards only`, 'warning');
    }
  });

  // A section, not a returned systemPrompt, so Pi keeps patching the prompt incrementally.
  pi.on('before_agent_start', (event) => {
    event.systemPromptOptions.sections[DELETION_SAFETY_SECTION] = DELETION_SAFETY_PROMPT;
  });

  /**
   * Auto mode gate for one Bash command. Returns a block result, or undefined when the command
   * may run. `ask` (jev's own, a low-confidence verdict, or an unreachable classifier) becomes a
   * confirmation prompt; without a UI it degrades to a block so nothing runs silently.
   */
  async function gateWithAutoMode(command: string, ctx: ExtensionContext) {
    const apiKey = autoModeApiKey();
    if (apiKey === undefined) {
      return { block: true, reason: `pi-safety auto mode: ${API_KEY_ENV} is not set` };
    }

    const actionLine = describeBashCall(command);
    const transcript = buildTranscript(ctx.sessionManager.getBranch(), actionLine);
    const outcome = await adjudicate(transcript, {
      apiKey,
      minConfidence: loaded.config.autoMode.minConfidence,
      signal: ctx.signal,
    });

    if (outcome.verdict === 'allow') return undefined;

    if (outcome.verdict === 'deny' && outcome.source !== 'fail-closed') {
      ctx.ui.notify(`🛡 auto mode blocked: ${outcome.reason}\n  ${actionLine}`, 'warning');
      return { block: true, reason: `pi-safety auto mode denied: ${outcome.reason}` };
    }

    if (!ctx.hasUI) {
      return { block: true, reason: `pi-safety auto mode: ${outcome.reason} (no UI to confirm)` };
    }

    const title = outcome.source === 'fail-closed' ? '🛡 Auto mode: classifier unavailable' : '🛡 Auto mode: confirm';
    const allowed = await ctx.ui.confirm(
      title,
      `${truncateForPrompt(command)}\n\n${outcome.reason}\n\nAllow execution?`,
    );
    if (allowed) return undefined;

    return { block: true, reason: 'pi-safety auto mode: user declined' };
  }

  /**
   * Protected-path gate for the write and edit tools. `deny` rules block; `ask` rules need a
   * confirmation, which degrades to a block without a UI. Bash writes are not covered here.
   */
  async function gateFileMutation(toolName: string, path: string, ctx: ExtensionContext) {
    if (shellChecksDisabled) return undefined;
    if (loaded.status === 'invalid') return invalidConfigBlock();

    const verdict = inspectPath(path, ctx.cwd, loaded.config.paths);
    if (!verdict) return undefined;

    const subject = `${toolName} ${verdict.path}`;
    if (verdict.action === 'deny') {
      return { block: true, reason: `pi-safety: ${subject} is denied by protected path rule ${verdict.pattern}` };
    }

    if (!ctx.hasUI) {
      return {
        block: true,
        reason: `pi-safety: ${subject} needs user confirmation (path rule ${verdict.pattern}) but no UI is available`,
      };
    }

    const allowed = await ctx.ui.confirm(
      '🛡 Protected path',
      `${subject}\n\nMatches protected path rule ${verdict.pattern}.\n\nAllow this change?`,
    );
    if (allowed) return undefined;

    return { block: true, reason: `pi-safety: the user declined ${subject}` };
  }

  pi.on('tool_call', async (event, ctx) => {
    if (isToolCallEventType('write', event) || isToolCallEventType('edit', event)) {
      return gateFileMutation(event.toolName, event.input.path, ctx);
    }
    if (!isToolCallEventType('bash', event)) return;

    if (!shellChecksDisabled) {
      if (!parser) {
        return {
          block: true,
          reason: `pi-safety: Bash parser unavailable${parserError ? `: ${parserError}` : ''}`,
        };
      }

      // Fail closed like a parser failure: an invalid file would otherwise silently drop every
      // configured deny rule. The user can fix it and /reload, or opt out with /no-safety.
      if (loaded.status === 'invalid') return invalidConfigBlock();

      let denial: ReturnType<typeof inspectBashCommand>;
      try {
        denial = inspectBashCommand(parser, event.input.command, loaded.config.shell.deny);
      } catch (error) {
        return {
          block: true,
          reason: `pi-safety: Bash parser failed: ${error instanceof Error ? error.message : String(error)}`,
        };
      }
      if (denial) return { block: true, reason: `pi-safety: ${denial.reason}` };
    }

    // Deterministic rules are the floor; the classifier only sees what they let through.
    if (autoModeEnabled) {
      const blocked = await gateWithAutoMode(event.input.command, ctx);
      if (blocked) return blocked;
    }

    // Restrict the rm/rmdir-to-trash PATH shims to model-generated Bash. Manual !/!!
    // commands remain an explicit user-controlled escape hatch.
    event.input.command = `export PATH=${shellQuote(shimDirectory)}:"$PATH"\n${event.input.command}`;
  });
}
