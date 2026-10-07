import { randomUUID } from 'node:crypto';
import { mkdirSync, readFileSync, realpathSync, renameSync, unlinkSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import type { ExtensionAPI, ExtensionContext } from '@earendil-works/pi-coding-agent';

const MAX_CONFIG_BYTES = 64 * 1024;

type Model = ExtensionContext['model'];

/** No model allowlist: the backend decides whether priority routing is supported. */
export function isOfficialCodexModel(model: Model): boolean {
  if (model?.provider !== 'openai-codex' || model.api !== 'openai-codex-responses') return false;

  try {
    const url = new URL(model.baseUrl);
    const path = url.pathname.replace(/\/+$/u, '');
    const officialOrigin = url.origin === 'https://chatgpt.com' && !url.username && !url.password;
    // Pi's built-in catalog uses /backend-api; its adapter appends /codex/responses.
    const codexPath = path === '/backend-api' || path === '/backend-api/codex' ||
      path === '/backend-api/codex/responses';

    return officialOrigin && codexPath;
  } catch {
    return false;
  }
}

export function rewriteFastPayload(payload: unknown, model: Model, enabled: boolean): unknown | undefined {
  if (!isOfficialCodexModel(model) || typeof payload !== 'object' || payload === null || Array.isArray(payload)) {
    return undefined;
  }

  return { ...payload, service_tier: enabled ? 'priority' : 'default' };
}

function readConfig(path: string): Record<string, unknown> {
  let text: string;
  try {
    text = readFileSync(path, 'utf8');
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') return {};

    throw error;
  }

  if (Buffer.byteLength(text) > MAX_CONFIG_BYTES) throw new Error('settings exceed 64 KiB');

  const parsed: unknown = JSON.parse(text);
  if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
    throw new Error('expected a JSON object');
  }

  const config = parsed as Record<string, unknown>;
  if (config.fastMode !== undefined && typeof config.fastMode !== 'boolean') {
    throw new Error('fastMode must be a boolean');
  }

  return config;
}

export function loadFastMode(path: string): boolean {
  return readConfig(path).fastMode === true;
}

/** Atomic writes target the real file so toggling never replaces a Stow symlink. */
export function saveFastMode(path: string, enabled: boolean): void {
  const config = readConfig(path);
  let target: string;
  try {
    target = realpathSync(path);
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;

    target = resolve(path);
  }

  mkdirSync(dirname(target), { recursive: true });
  const temporary = `${target}.${randomUUID()}.tmp`;
  try {
    writeFileSync(temporary, `${JSON.stringify({ ...config, fastMode: enabled }, null, 2)}\n`, {
      flag: 'wx',
      mode: 0o600,
    });
    renameSync(temporary, target);
  } finally {
    try {
      unlinkSync(temporary);
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
    }
  }
}

export function registerFastMode(pi: ExtensionAPI, configPath: string): void {
  let enabled = false;

  function refreshStatus(ctx: ExtensionContext): void {
    ctx.ui.setStatus('pi-openai', enabled && isOfficialCodexModel(ctx.model) ? 'fast' : undefined);
  }

  pi.on('session_start', (_event, ctx) => {
    enabled = false;
    try {
      enabled = loadFastMode(configPath);
    } catch (error) {
      const reason = error instanceof Error ? error.message : String(error);
      ctx.ui.notify(`pi-openai: invalid settings (${reason}); Fast mode is off.`, 'warning');
    }

    refreshStatus(ctx);
  });

  pi.on('model_select', (_event, ctx) => refreshStatus(ctx));

  pi.registerCommand('fast', {
    description: 'Toggle OpenAI Codex Fast mode (/fast [on|off|status])',
    handler: async (args, ctx) => {
      const action = args.trim().toLowerCase();
      if (!['', 'on', 'off', 'status'].includes(action)) {
        throw new Error('Usage: /fast [on|off|status]');
      }

      if (action === 'status') {
        const inactive = enabled && !isOfficialCodexModel(ctx.model);
        const status = `Codex Fast mode: ${enabled ? 'on' : 'off'}${inactive ? ' (inactive for this model)' : ''}.`;
        ctx.ui.notify(status, 'info');
        return;
      }

      const next = action === '' ? !enabled : action === 'on';
      if (next && !isOfficialCodexModel(ctx.model)) {
        ctx.ui.notify('Fast mode requires the official OpenAI Codex Responses endpoint.', 'warning');
        return;
      }

      try {
        saveFastMode(configPath, next);
      } catch (error) {
        const reason = error instanceof Error ? error.message : String(error);
        ctx.ui.notify(`Could not save pi-openai settings: ${reason}`, 'error');
        return;
      }

      enabled = next;
      refreshStatus(ctx);
      ctx.ui.notify(
        enabled ? 'Codex Fast mode on; priority routing uses more plan allowance.' : 'Codex Fast mode off; standard routing.',
        'info',
      );
    },
  });

  pi.on('before_provider_request', (event, ctx) => rewriteFastPayload(event.payload, ctx.model, enabled));
}
