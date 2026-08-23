import { chmodSync, realpathSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { type ExtensionAPI, isToolCallEventType } from '@earendil-works/pi-coding-agent';
import type { Parser } from 'web-tree-sitter';
import { loadSafetyConfig, type LoadedSafetyConfig } from './config.ts';
import { createBashParser, inspectBashCommand } from './shell-policy.ts';

const extensionDirectory = dirname(realpathSync(fileURLToPath(import.meta.url)));
const shimDirectory = join(extensionDirectory, 'bin');

function shellQuote(value: string): string {
  return `'${value.replaceAll("'", `'"'"'`)}'`;
}

function ensureShims(): void {
  for (const name of ['rm', 'rmdir', 'trash']) chmodSync(join(shimDirectory, name), 0o755);
}

function statusText(loaded: LoadedSafetyConfig, parserError: string | undefined, shellChecksDisabled: boolean): string {
  if (shellChecksDisabled) return '🛡 disabled';
  if (parserError) return '🛡 parser error';
  const suffix = loaded.status === 'loaded' ? '' : ' defaults';
  return `🛡 ${loaded.config.shell.deny.length}c${suffix}`;
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
      ctx.ui.notify('pi-safety: shell command checks are disabled for this session', 'warning');
    },
  });

  pi.on('session_start', (_event, ctx) => {
    loaded = loadSafetyConfig(process.env.PI_SAFETY_CONFIG);
    ctx.ui.setStatus('pi-safety', statusText(loaded, parserError, shellChecksDisabled));

    if (parserError) {
      ctx.ui.notify(`pi-safety: tree-sitter initialization failed; Bash is disabled (${parserError})`, 'error');
    }
    if (loaded.status !== 'loaded') {
      ctx.ui.notify(
        `pi-safety: ${loaded.errors.join('; ')}; using built-in safeguards only`,
        loaded.status === 'invalid' ? 'error' : 'warning',
      );
    }
  });

  pi.on('before_agent_start', (event) => ({
    systemPrompt: `${event.systemPrompt}\n\nDeletion safety: plain rm and rmdir are transparently redirected to the macOS Trash for agent Bash calls; use them or trash normally.`,
  }));

  pi.on('tool_call', (event) => {
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
