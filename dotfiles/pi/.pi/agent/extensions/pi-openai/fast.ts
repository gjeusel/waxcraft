import { randomUUID } from 'node:crypto';
import { mkdirSync, readFileSync, realpathSync, renameSync, unlinkSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import type { ExtensionAPI, ExtensionContext } from '@earendil-works/pi-coding-agent';
import { Container, Key, SelectList, Text, truncateToWidth } from '@earendil-works/pi-tui';

const MAX_CONFIG_BYTES = 64 * 1024;

type Model = ExtensionContext['model'];
type SpeedMode = 'normal' | 'fast' | 'ultrafast';

const ANTHROPIC_FAST_BETA = 'fast-mode-2026-02-01';

/** No model allowlist: Anthropic decides whether fast mode is supported. */
export function isAnthropicFastModel(model: Model): boolean {
  if (model?.provider !== 'anthropic' || model.api !== 'anthropic-messages') return false;

  try {
    const url = new URL(model.baseUrl);
    const path = url.pathname.replace(/\/+$/u, '');

    return url.origin === 'https://api.anthropic.com' && !url.username && !url.password &&
      (path === '' || path === '/v1');
  } catch {
    return false;
  }
}

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

/** No model allowlist: OpenAI decides which models and accounts support each service tier. */
export function isOfficialOpenAIModel(model: Model): boolean {
  if (isOfficialCodexModel(model)) return true;

  if (model?.provider !== 'openai' ||
    !['openai-responses', 'openai-completions'].includes(model.api)) return false;

  try {
    const url = new URL(model.baseUrl);
    const path = url.pathname.replace(/\/+$/u, '');

    return url.origin === 'https://api.openai.com' && !url.username && !url.password &&
      ['', '/v1', '/v1/responses', '/v1/chat/completions'].includes(path);
  } catch {
    return false;
  }
}

export function rewriteFastPayload(
  payload: unknown, model: Model, enabled: boolean, ultrafast = false,
): unknown | undefined {
  if (typeof payload !== 'object' || payload === null || Array.isArray(payload)) return undefined;

  const request = payload as Record<string, unknown>;
  if (isOfficialOpenAIModel(model)) {
    if (request.model !== undefined && request.model !== model?.id) return undefined;

    const serviceTier = enabled ? (ultrafast ? 'ultrafast' : 'priority') : 'default';

    return { ...payload, service_tier: serviceTier };
  }

  // The hook context is the selected model, which can differ from a routed request's model.
  if (!isAnthropicFastModel(model) || request.model !== model?.id || !enabled) return undefined;

  // The SDK moves betas into the header; preserve Pi's OAuth/thinking/tool betas. Black then
  // checksums the serialized body (including speed), so no post-signing request mutation is needed.
  const betas = Array.isArray(request.betas) ? request.betas : [];

  return { ...request, speed: 'fast', betas: [...new Set([...betas, ANTHROPIC_FAST_BETA])] };
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
  for (const key of ['fastMode', 'ultrafastMode']) {
    if (config[key] !== undefined && typeof config[key] !== 'boolean') {
      throw new Error(`${key} must be a boolean`);
    }
  }

  return config;
}

export function loadFastMode(path: string): boolean {
  return readConfig(path).fastMode === true;
}

export function loadUltrafastMode(path: string): boolean {
  return readConfig(path).ultrafastMode === true;
}

/** Atomic writes target the real file so toggling never replaces a Stow symlink. */
export function saveFastMode(path: string, enabled: boolean, ultrafast = false): void {
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
    const updated: Record<string, unknown> = { ...config, fastMode: enabled };
    if (ultrafast || config.ultrafastMode !== undefined) updated.ultrafastMode = enabled && ultrafast;

    writeFileSync(temporary, `${JSON.stringify(updated, null, 2)}\n`, {
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

export function registerFastMode(pi: ExtensionAPI, configPath: string, anthropicConfigPath: string): void {
  const modes = {
    openai: {
      path: configPath, label: 'OpenAI', enabled: false, ultrafast: false, supports: isOfficialOpenAIModel,
    },
    anthropic: {
      path: anthropicConfigPath, label: 'Anthropic', enabled: false, ultrafast: false, supports: isAnthropicFastModel,
    },
  };

  function currentMode(ctx: ExtensionContext) {
    return ctx.model?.provider === 'anthropic' ? modes.anthropic : modes.openai;
  }

  function refreshStatus(ctx: ExtensionContext): void {
    const mode = currentMode(ctx);
    const speed = mode.ultrafast ? 'ultrafast' : 'fast';
    ctx.ui.setStatus('pi-openai', mode.enabled && mode.supports(ctx.model) ? speed : undefined);
  }

  function applySpeed(ctx: ExtensionContext, speed: SpeedMode): void {
    const mode = currentMode(ctx);
    const enabled = speed !== 'normal';
    const ultrafast = speed === 'ultrafast';
    if (ultrafast && mode === modes.anthropic) {
      ctx.ui.notify('Ultrafast mode requires the official OpenAI API or Codex endpoint.', 'warning');
      return;
    }

    if (enabled && !mode.supports(ctx.model)) {
      const requirement = mode === modes.anthropic
        ? 'Anthropic Fast mode requires the official Anthropic Messages endpoint.'
        : 'Fast mode requires the official OpenAI API or Codex endpoint.';
      ctx.ui.notify(requirement, 'warning');
      return;
    }

    try {
      saveFastMode(mode.path, enabled, ultrafast);
    } catch (error) {
      const reason = error instanceof Error ? error.message : String(error);
      ctx.ui.notify(`Could not save ${mode.label} Fast settings: ${reason}`, 'error');
      return;
    }

    mode.enabled = enabled;
    mode.ultrafast = ultrafast;
    refreshStatus(ctx);
    const enabledNotice = mode === modes.anthropic
      ? 'Anthropic Fast mode on; premium pricing, billed to usage credits on subscriptions (not included plan usage).'
      : `OpenAI ${ultrafast ? 'Ultrafast' : 'Fast'} mode on; higher API cost or plan usage, subject to backend support.`;
    ctx.ui.notify(enabled ? enabledNotice : `${mode.label} Fast mode off; standard routing.`, 'info');
  }

  let selecting = false;
  pi.registerShortcut(Key.ctrlShift(';'), {
    description: 'Select Normal, Fast, or Ultrafast routing',
    handler: async (ctx) => {
      if (ctx.mode !== 'tui' || selecting) return;

      const model = ctx.model;
      const mode = currentMode(ctx);
      const current: SpeedMode = mode.enabled ? (mode.ultrafast ? 'ultrafast' : 'fast') : 'normal';
      const speeds: SpeedMode[] = ['normal', 'fast', 'ultrafast'];
      const colors = { normal: 'muted', fast: 'success', ultrafast: 'warning' } as const;
      selecting = true;
      try {
        const selected = await ctx.ui.custom<SpeedMode | undefined>((tui, theme, _kb, done) => {
          const container = new Container();
          container.addChild(new Text(theme.bold(`Select speed · ${mode.label}`), 0, 1));
          const items = speeds.map((speed) => {
            const unavailable = speed === 'ultrafast' && mode === modes.anthropic;
            const label = speed[0].toUpperCase() + speed.slice(1);
            const descriptions = {
              normal: 'Standard routing',
              fast: mode === modes.anthropic ? 'Paid usage credits on subscriptions' : 'Priority routing',
              ultrafast: unavailable ? 'OpenAI only' : 'Highest-speed routing · higher cost',
            };

            return {
              value: speed,
              label: `${label}${speed === current ? ' (current)' : ''}${unavailable ? ' (unavailable)' : ''}`,
              description: descriptions[speed],
            };
          });
          const list = new SelectList(items, 3, {
            selectedPrefix: (text) => theme.fg('accent', text),
            selectedText: (text) => theme.bold(text),
            description: (text) => theme.fg('muted', text),
            scrollInfo: (text) => theme.fg('dim', text),
            noMatch: (text) => theme.fg('warning', text),
          }, {
            minPrimaryColumnWidth: 22,
            maxPrimaryColumnWidth: 32,
            truncatePrimary: ({ text, maxWidth, item }) => {
              const speed = item.value as SpeedMode;
              const unavailable = speed === 'ultrafast' && mode === modes.anthropic;

              return theme.fg(unavailable ? 'dim' : colors[speed], truncateToWidth(text, maxWidth, ''));
            },
          });
          list.setSelectedIndex(speeds.indexOf(current));
          list.onSelect = (item) => done(item.value as SpeedMode);
          list.onCancel = () => done(undefined);
          container.addChild(list);
          container.addChild({
            render: (width) => ['', truncateToWidth(
              theme.fg('dim', '↑↓ choose · Enter apply · Esc cancel'), width,
            ), ''],
            invalidate() {},
          });

          return {
            render: (width) => container.render(width).map((line) => truncateToWidth(line, width)),
            invalidate: () => container.invalidate(),
            handleInput: (data) => {
              list.handleInput(data);
              tui.requestRender();
            },
          };
        });
        if (selected === undefined) return;

        if (ctx.model !== model) {
          ctx.ui.notify('Model changed while selecting speed; reopen the selector.', 'warning');
          return;
        }

        applySpeed(ctx, selected);
      } finally {
        selecting = false;
      }
    },
  });

  pi.on('session_start', (_event, ctx) => {
    for (const mode of Object.values(modes)) {
      mode.enabled = false;
      mode.ultrafast = false;
      try {
        const config = readConfig(mode.path);
        mode.ultrafast = mode === modes.openai && config.ultrafastMode === true;
        mode.enabled = config.fastMode === true || mode.ultrafast;
      } catch (error) {
        mode.enabled = false;
        mode.ultrafast = false;
        const reason = error instanceof Error ? error.message : String(error);
        ctx.ui.notify(`${mode.label}: invalid settings (${reason}); Fast mode is off.`, 'warning');
      }
    }

    refreshStatus(ctx);
  });

  pi.on('model_select', (event, ctx) => {
    const leavingUltrafast = modes.openai.enabled && modes.openai.ultrafast &&
      isOfficialOpenAIModel(event.previousModel);
    const enteringAnthropic = isAnthropicFastModel(ctx.model);
    if (leavingUltrafast && enteringAnthropic && !modes.anthropic.enabled) {
      applySpeed(ctx, 'fast');
    }

    refreshStatus(ctx);
  });

  for (const command of ['fast', 'ultrafast']) {
    pi.registerCommand(command, {
      description: command === 'ultrafast'
        ? 'Toggle OpenAI Ultrafast mode (/ultrafast [on|off|status])'
        : 'Toggle OpenAI or Anthropic Fast mode (/fast [on|off|status])',
      handler: async (args, ctx) => {
        const action = args.trim().toLowerCase();
        if (!['', 'on', 'off', 'status'].includes(action)) {
          throw new Error(`Usage: /${command} [on|off|status]`);
        }

        const mode = currentMode(ctx);
        if (command === 'ultrafast' && mode === modes.anthropic) {
          ctx.ui.notify('Ultrafast mode requires the official OpenAI API or Codex endpoint.', 'warning');
          return;
        }

        if (action === 'status') {
          const inactive = mode.enabled && !mode.supports(ctx.model);
          const speed = mode.enabled ? (mode.ultrafast ? 'ultrafast' : 'on') : 'off';
          const status = `${mode.label} Fast mode: ${speed}${inactive ? ' (inactive for this model)' : ''}.`;
          ctx.ui.notify(status, 'info');
          return;
        }

        const active = command === 'ultrafast' ? mode.ultrafast : mode.enabled;
        const next = action === '' ? !active : action === 'on';
        if (command === 'ultrafast' && !next && !mode.ultrafast) {
          ctx.ui.notify('OpenAI Ultrafast mode already off; routing unchanged.', 'info');
          return;
        }

        applySpeed(ctx, next ? (command === 'ultrafast' ? 'ultrafast' : 'fast') : 'normal');
      },
    });
  }

  pi.on('before_provider_request', (event, ctx) => {
    const mode = currentMode(ctx);

    return rewriteFastPayload(event.payload, ctx.model, mode.enabled, mode.ultrafast);
  });
}
