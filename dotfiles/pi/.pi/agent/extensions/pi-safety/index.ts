import { chmodSync, realpathSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { type ExtensionAPI, isToolCallEventType } from '@earendil-works/pi-coding-agent';
import type { Parser } from 'web-tree-sitter';
import { filesystemPolicyHash, loadSafetyConfig, type LoadedSafetyConfig } from './config.ts';
import { createBashParser, inspectBashCommand } from './shell-policy.ts';

const extensionDirectory = dirname(realpathSync(fileURLToPath(import.meta.url)));
const shimDirectory = join(extensionDirectory, 'bin');

function shellQuote(value: string): string {
  return `'${value.replaceAll("'", `'"'"'`)}'`;
}

function ensureShims(): void {
  for (const name of ['rm', 'rmdir', 'trash']) chmodSync(join(shimDirectory, name), 0o755);
}

function filesystemSandboxDisabled(): boolean {
  return process.env.PI_SAFETY_SANDBOXED !== '1' && process.env.PI_SAFETY_DISABLE_FILESYSTEM_SANDBOX === '1';
}

function launchedSafely(): boolean {
  return process.env.PI_SAFETY_SANDBOXED === '1' || filesystemSandboxDisabled();
}

function statusText(loaded: LoadedSafetyConfig, parserError: string | undefined, shellChecksDisabled: boolean): string {
  if (!launchedSafely()) return '🛡 unsandboxed';
  if (shellChecksDisabled) return filesystemSandboxDisabled() ? '🛡 trash only' : '🛡 filesystem only';
  if (parserError) return '🛡 parser error';
  const suffix = loaded.status === 'loaded' ? '' : ' defaults';
  if (filesystemSandboxDisabled()) return `🛡 ${loaded.config.shell.deny.length}c${suffix} (filesystem off)`;
  const pathCount = new Set([...loaded.config.filesystem.denyRead, ...loaded.config.filesystem.denyWrite]).size;
  return `🛡 ${pathCount}p/${loaded.config.shell.deny.length}c${suffix}`;
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

  pi.registerCommand('no-safety', {
    description: 'Disable shell safety checks for the current session',
    handler: async (_args, ctx) => {
      shellChecksDisabled = true;
      ctx.ui.setStatus('pi-safety', statusText(loaded, parserError, shellChecksDisabled));
      const remainingProtection = filesystemSandboxDisabled()
        ? 'rm/rmdir-to-trash routing remains active; filesystem Seatbelt was disabled by the environment'
        : 'rm/rmdir-to-trash routing and filesystem Seatbelt remain active';
      ctx.ui.notify(`pi-safety: shell command checks are disabled for this session; ${remainingProtection}`, 'warning');
    },
  });

  pi.on('session_start', (_event, ctx) => {
    loaded = loadSafetyConfig(process.env.PI_SAFETY_CONFIG);
    ctx.ui.setStatus('pi-safety', statusText(loaded, parserError, shellChecksDisabled));

    if (!launchedSafely()) {
      ctx.ui.notify('pi-safety: Pi was not launched through ~/.local/bin/pi; model tool calls are disabled', 'error');
      return;
    }
    if (filesystemSandboxDisabled()) {
      ctx.ui.notify(
        'pi-safety: filesystem Seatbelt is disabled by PI_SAFETY_DISABLE_FILESYSTEM_SANDBOX=1; shell checks and rm/rmdir-to-trash routing remain active',
        'warning',
      );
    }
    if (parserError) {
      ctx.ui.notify(`pi-safety: tree-sitter initialization failed; Bash is disabled (${parserError})`, 'error');
    }
    if (loaded.status !== 'loaded') {
      ctx.ui.notify(
        `pi-safety: ${loaded.errors.join('; ')}; using built-in safeguards only`,
        loaded.status === 'invalid' ? 'error' : 'warning',
      );
    }

    const launchHash = process.env.PI_SAFETY_FS_POLICY_HASH;
    const currentHash = filesystemPolicyHash(loaded.config);
    if (!filesystemSandboxDisabled() && launchHash && launchHash !== currentHash) {
      ctx.ui.notify(
        'pi-safety: filesystem policy changed since launch; shell rules were refreshed, but restart Pi to refresh Seatbelt',
        'warning',
      );
    }
  });

  pi.on('before_agent_start', (event) => ({
    systemPrompt: `${event.systemPrompt}\n\n${
      shellChecksDisabled
        ? filesystemSandboxDisabled()
          ? 'Shell command checks and filesystem Seatbelt restrictions were disabled by the user; rm and rmdir remain routed to Trash.'
          : 'Shell command checks were disabled by the user for this session; rm and rmdir remain routed to Trash and filesystem Seatbelt restrictions remain active.'
        : 'Deletion safety: plain rm and rmdir are transparently redirected to the macOS Trash for agent Bash calls; use them or trash normally.'
    }`,
  }));

  pi.on('tool_call', (event) => {
    if (!launchedSafely()) {
      return {
        block: true,
        reason:
          'pi-safety: Pi is not running under sandbox-exec; restart it through ~/.local/bin/pi or explicitly set PI_SAFETY_DISABLE_FILESYSTEM_SANDBOX=1',
      };
    }
    if (!isToolCallEventType('bash', event)) return;
    if (shellChecksDisabled) {
      event.input.command = `export PATH=${shellQuote(shimDirectory)}:"$PATH"\n${event.input.command}`;
      return;
    }
    if (!parser) {
      return {
        block: true,
        reason: `pi-safety: Bash parser unavailable${parserError ? `: ${parserError}` : ''}`,
      };
    }

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

    // Restrict the rm/rmdir-to-trash PATH shims to model-generated Bash. Manual !/!!
    // commands remain an explicit user-controlled escape hatch.
    event.input.command = `export PATH=${shellQuote(shimDirectory)}:"$PATH"\n${event.input.command}`;
  });
}
