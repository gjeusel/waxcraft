import { chmodSync, realpathSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { type EditToolInput, type ExtensionAPI, type ExtensionContext, type WriteToolInput, isToolCallEventType } from '@earendil-works/pi-coding-agent';
import type { Parser } from 'web-tree-sitter';
import { AUTO_MODE_PROMPT_FILENAME, DECISION_BACKENDS, adjudicate, appendAutoModeRecord, buildTranscript, describeBashCall, type AutoModeRecord, type AutoModeSource } from './auto-mode.ts';
import { createApprovalPrompt, fileApproval, type ApprovalRequest } from './approval.ts';
import { loadSafetyConfig, type LoadedSafetyConfig } from './config.ts';
import { inspectPath } from './path-policy.ts';
import { createBashParser, inspectBashCommand } from './shell-policy.ts';
import { AutoModeState, forwardApproval, registerSafetySession } from './session-state.ts';

const extensionDirectory = dirname(realpathSync(fileURLToPath(import.meta.url)));
const shimDirectory = join(extensionDirectory, 'bin');

/** Footer status keys read by the statusbar extension. */
export const AUTO_MODE_STATUS_KEY = 'auto-mode';
export const SAFETY_STATUS_KEY = 'pi-safety';
const AUTO_MODE_STATUS_TEXT = 'auto-mode';
const AUTO_MODE_ENTRY_TYPE = 'pi-safety:auto-mode';
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

function autoModeApiKey(source: AutoModeSource): string | undefined {
  return process.env[DECISION_BACKENDS[source].apiKeyEnv]?.trim() || undefined;
}

function savedAutoMode(ctx: ExtensionContext): boolean | undefined {
  // This is a discussion-wide preference, not branch state: /tree must not undo a user toggle.
  const entries = ctx.sessionManager.getEntries();
  for (let index = entries.length - 1; index >= 0; index--) {
    const entry = entries[index];
    if (entry.type !== 'custom' || entry.customType !== AUTO_MODE_ENTRY_TYPE) continue;

    const data = entry.data;
    if (data && typeof data === 'object' && 'enabled' in data && typeof data.enabled === 'boolean') {
      return data.enabled;
    }
  }

  return undefined;
}

export default async function (pi: ExtensionAPI) {
  const shutdown = new AbortController();
  const prompt = createApprovalPrompt(shutdown.signal);
  const approve = (request: ApprovalRequest, ctx: ExtensionContext) => ctx.hasUI
    ? prompt(request, ctx)
    : forwardApproval(request, ctx, shutdown.signal);
  let disposeSession: (() => void) | undefined;
  let unsubscribeMode: (() => void) | undefined;
  pi.on('session_shutdown', () => {
    shutdown.abort();
    disposeSession?.();
    unsubscribeMode?.();
  });

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
  // Missing credentials must not silently disable an enabled permission gate.
  const envMode = process.env.PI_AUTO_MODE === '1' ? true : process.env.PI_AUTO_MODE === '0' ? false : undefined;
  const persistMode = (enabled: boolean, previous: boolean) => {
    try {
      pi.appendEntry(AUTO_MODE_ENTRY_TYPE, { enabled });
    } catch (error) {
      // Pi appends in memory before writing to disk. Compensate so /reload cannot restore a
      // failed toggle; even if disk writes still fail, the last in-memory preference is restored.
      try {
        pi.appendEntry(AUTO_MODE_ENTRY_TYPE, { enabled: previous });
      } catch { /* Preserve the original write error. */ }

      throw error;
    }
  };
  let mode = new AutoModeState(envMode ?? loaded.config.autoMode.enabled, persistMode);

  function autoModeEnabled(): boolean {
    return mode.snapshot().enabled;
  }

  function refreshAutoModeStatus(ctx: ExtensionContext) {
    ctx.ui.setStatus(AUTO_MODE_STATUS_KEY, autoModeEnabled() ? AUTO_MODE_STATUS_TEXT : undefined);
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
    description: 'Toggle Bash adjudication and protected-file confirmations for this discussion (saved across resume/reload)',
    handler: async (_args, ctx) => {
      const { source } = loaded.config.autoMode;
      if (!autoModeEnabled() && autoModeApiKey(source) === undefined) {
        ctx.ui.notify(`pi-safety: auto mode (${source}) needs ${DECISION_BACKENDS[source].apiKeyEnv} in the environment`, 'error');
        return;
      }

      mode.setEnabled(!autoModeEnabled());
      refreshAutoModeStatus(ctx);
      ctx.ui.notify(
        autoModeEnabled()
          ? `pi-safety: auto mode on — Bash commands are adjudicated by ${source}; protected-file edits require confirmation`
          : 'pi-safety: auto mode off — no Bash adjudication or file confirmations; hard deny rules still apply',
        'info',
      );
    },
  });

  pi.on('session_start', (_event, ctx) => {
    loaded = loadSafetyConfig(process.env.PI_SAFETY_CONFIG);
    disposeSession?.();
    unsubscribeMode?.();
    const localMode = new AutoModeState(
      savedAutoMode(ctx) ?? envMode ?? loaded.config.autoMode.enabled,
      persistMode,
    );
    const session = registerSafetySession(ctx, prompt, localMode, shutdown.signal);
    mode = session.mode;
    disposeSession = session.dispose;
    unsubscribeMode = mode.subscribe(() => refreshAutoModeStatus(ctx));
    ctx.ui.setStatus(SAFETY_STATUS_KEY, statusText(loaded, parserError, shellChecksDisabled));
    refreshAutoModeStatus(ctx);

    const { source } = loaded.config.autoMode;
    if (autoModeEnabled() && autoModeApiKey(source) === undefined) {
      ctx.ui.notify(
        `pi-safety: auto mode (${source}) needs ${DECISION_BACKENDS[source].apiKeyEnv}; Bash is blocked until it is set or auto mode is disabled`,
        'warning',
      );
    }

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
   * may run. `ask` (the backend's own, a low-confidence verdict, or a broken policy file) becomes a
   * confirmation prompt; without a UI it degrades to a block. Backend failures and refusals allow.
   */
  async function gateWithAutoMode(command: string, ctx: ExtensionContext, confirmationReason?: string) {
    const { source, minConfidence } = loaded.config.autoMode;
    const apiKey = autoModeApiKey(source);
    if (apiKey === undefined) {
      return { block: true, reason: `pi-safety auto mode (${source}): ${DECISION_BACKENDS[source].apiKeyEnv} is not set` };
    }

    const actionLine = describeBashCall(command);
    const transcript = buildTranscript(ctx.sessionManager.getBranch(), actionLine);
    const outcome = await adjudicate(transcript, {
      apiKey,
      promptPath: join(dirname(loaded.configPath), AUTO_MODE_PROMPT_FILENAME),
      source,
      minConfidence,
      signal: ctx.signal,
    });

    if (ctx.signal?.aborted) return { block: true, reason: 'pi-safety: classification cancelled' };
    if (outcome.verdict === 'allow' && !confirmationReason) {
      const unclassified = outcome.source === 'fail-open' || outcome.source === 'refusal';
      if (unclassified) ctx.ui.notify(`🛡 auto mode allowed unclassified: ${outcome.reason}\n  ${actionLine}`, 'warning');

      return undefined;
    }

    if (outcome.verdict === 'deny') {
      ctx.ui.notify(`🛡 auto mode blocked: ${outcome.reason}\n  ${actionLine}`, 'warning');
      return { block: true, reason: `pi-safety auto mode denied: ${outcome.reason}` };
    }

    const classificationFailed = outcome.source === 'fail-closed';
    const reason = classificationFailed ? outcome.reason : confirmationReason ?? outcome.reason;

    const record: AutoModeRecord = {
      timestamp: new Date().toISOString(),
      answer: 'cancelled',
      sessionId: ctx.sessionManager.getSessionId(),
      sessionName: ctx.sessionManager.getSessionName(),
      cwd: ctx.cwd,
      backend: source,
      trigger: confirmationReason && !classificationFailed ? 'shell-rule' : outcome.source,
      outcome,
      reason,
      command,
      transcript,
    };
    try {
      const allowed = await approve({
        title: 'bash', content: command, language: 'bash', reason,
        onAnswer: (allowed) => { record.answer = allowed ? 'allow' : 'deny'; },
      }, ctx);
      if (allowed === undefined) {
        if (record.answer === 'cancelled') record.answer = 'unavailable';
        return { block: true, reason: `pi-safety auto mode: ${reason} (no UI to confirm or parent approval unavailable)` };
      }

      if (allowed) return undefined;

      return { block: true, reason: 'pi-safety auto mode: user declined' };
    } catch (error) {
      if (record.answer === 'cancelled') record.answer = 'unavailable';
      throw error;
    } finally {
      try {
        appendAutoModeRecord(record);
      } catch {
        // A logging failure must neither grant permission nor discard the user's actual choice.
        ctx.ui.notify('pi-safety: could not append ~/.pi/auto-mode-records.md; approval was not recorded', 'warning');
      }
    }
  }

  /**
   * Protected-path gate for write/edit. Denies always block; asks require confirmation only while
   * auto mode is on. Mode changes cancel pending approvals and recheck the rules before proceeding.
   * Bash writes are not covered here.
   */
  async function gateFileMutation(toolName: 'write' | 'edit', input: WriteToolInput | EditToolInput, ctx: ExtensionContext) {
    const operationSignal = ctx.signal;
    for (;;) {
      if (operationSignal?.aborted || shutdown.signal.aborted) return { block: true, reason: 'pi-safety: operation cancelled' };

      if (shellChecksDisabled) return undefined;
      if (loaded.status === 'invalid') return invalidConfigBlock();

      const verdict = inspectPath(input.path, ctx.cwd, loaded.config.paths);
      if (!verdict) return undefined;

      const subject = `${toolName} ${verdict.path}`;
      if (verdict.action === 'deny') {
        return { block: true, reason: `pi-safety: ${subject} is denied by protected path rule ${verdict.pattern}` };
      }

      const snapshot = mode.snapshot();
      if (!snapshot.enabled) return undefined;

      const signal = AbortSignal.any([snapshot.signal, shutdown.signal, ...(operationSignal ? [operationSignal] : [])]);
      const decisionContext: ExtensionContext = Object.create(ctx, { signal: { value: signal } });
      const request = fileApproval(toolName, input, verdict.path);
      request.reason = `Matches protected path rule ${verdict.pattern}`;
      const allowed = await approve(request, decisionContext);
      if (operationSignal?.aborted || shutdown.signal.aborted) return { block: true, reason: 'pi-safety: operation cancelled' };
      if (snapshot.signal.aborted) continue;

      if (allowed === undefined) {
        return {
          block: true,
          reason: `pi-safety: ${subject} needs user confirmation (path rule ${verdict.pattern}) but no UI or parent approval is available`,
        };
      }

      if (allowed) return undefined;

      return { block: true, reason: `pi-safety: the user declined ${subject}` };
    }
  }

  pi.on('tool_call', async (event, ctx) => {
    if (isToolCallEventType('write', event) || isToolCallEventType('edit', event)) {
      return gateFileMutation(event.toolName, event.input, ctx);
    }
    if (!isToolCallEventType('bash', event)) return;

    const operationSignal = ctx.signal;
    for (;;) {
      if (operationSignal?.aborted || shutdown.signal.aborted) return { block: true, reason: 'pi-safety: operation cancelled' };

      const snapshot = mode.snapshot();
      let confirmationReason: string | undefined;
      if (!shellChecksDisabled) {
        if (!parser) {
          return {
            block: true,
            reason: `pi-safety: Bash parser unavailable${parserError ? `: ${parserError}` : ''}`,
          };
        }

        // An invalid file must not silently drop configured rules. Recheck these rules after a
        // toggle: turning auto mode off restores infrastructure hard denies, not permission.
        if (loaded.status === 'invalid') return invalidConfigBlock();

        let decision: ReturnType<typeof inspectBashCommand>;
        try {
          decision = inspectBashCommand(parser, event.input.command, loaded.config.shell.deny, snapshot.enabled);
        } catch (error) {
          return {
            block: true,
            reason: `pi-safety: Bash parser failed: ${error instanceof Error ? error.message : String(error)}`,
          };
        }
        if (decision?.action === 'deny') return { block: true, reason: `pi-safety: ${decision.reason}` };
        confirmationReason = decision?.reason;
      }

      if (snapshot.enabled) {
        const signal = AbortSignal.any([snapshot.signal, shutdown.signal, ...(operationSignal ? [operationSignal] : [])]);
        const decisionContext: ExtensionContext = Object.create(ctx, { signal: { value: signal } });
        const blocked = await gateWithAutoMode(event.input.command, decisionContext, confirmationReason);
        if (operationSignal?.aborted || shutdown.signal.aborted) return { block: true, reason: 'pi-safety: operation cancelled' };
        if (snapshot.signal.aborted) continue;
        if (blocked) return blocked;
      }

      // Restrict trash shims to model-generated Bash; manual !/!! commands remain user-controlled.
      event.input.command = `export PATH=${shellQuote(shimDirectory)}:"$PATH"\n${event.input.command}`;

      return;
    }
  });
}
