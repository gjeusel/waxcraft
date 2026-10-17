import type { ExtensionAPI, ExtensionContext } from '@earendil-works/pi-coding-agent';
import { Container, Key, SelectList, Text, truncateToWidth } from '@earendil-works/pi-tui';

type Model = ExtensionContext['model'];
type SpeedMode = 'normal' | 'fast' | 'ultrafast';
type SpeedState = { version: 1; openai: SpeedMode; anthropic: 'normal' | 'fast' };

export const SPEED_ENTRY_TYPE = 'pi-speed-mode';

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

export function registerFastMode(pi: ExtensionAPI): void {
  const modes = {
    openai: {
      label: 'OpenAI', enabled: false, ultrafast: false, supports: isOfficialOpenAIModel,
    },
    anthropic: {
      label: 'Anthropic', enabled: false, ultrafast: false, supports: isAnthropicFastModel,
    },
  };

  function currentMode(ctx: ExtensionContext) {
    return ctx.model?.provider === 'anthropic' ? modes.anthropic : modes.openai;
  }

  function refreshStatus(ctx: ExtensionContext): void {
    const mode = currentMode(ctx);
    const speed = mode.ultrafast ? 'ultrafast' : 'fast';
    ctx.ui.setStatus('pi-model-controls', mode.enabled && mode.supports(ctx.model) ? speed : undefined);
  }

  function snapshot(): SpeedState {
    return {
      version: 1,
      openai: modes.openai.enabled ? (modes.openai.ultrafast ? 'ultrafast' : 'fast') : 'normal',
      anthropic: modes.anthropic.enabled ? 'fast' : 'normal',
    };
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

    const previous = snapshot();
    const provider = mode === modes.anthropic ? 'anthropic' : 'openai';
    try {
      pi.appendEntry(SPEED_ENTRY_TYPE, { ...previous, [provider]: speed });
    } catch (error) {
      // Pi appends in memory before persisting. Restore the prior snapshot even if the disk
      // failure also affects compensation, so a reload cannot enable a failed paid-speed change.
      try {
        pi.appendEntry(SPEED_ENTRY_TYPE, previous);
      } catch { /* Preserve the original write error. */ }

      const reason = error instanceof Error ? error.message : String(error);
      ctx.ui.notify(`Could not save ${mode.label} speed in session history: ${reason}`, 'error');
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

  let sessionGeneration = 0;
  let selecting = false;
  pi.registerShortcut(Key.ctrlShift(';'), {
    description: 'Select Normal, Fast, or Ultrafast routing',
    handler: async (ctx) => {
      if (ctx.mode !== 'tui' || selecting) return;

      const generation = sessionGeneration;
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

        if (generation !== sessionGeneration) {
          ctx.ui.notify('Session changed while selecting speed; reopen the selector.', 'warning');
          return;
        }

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
    sessionGeneration++;
    for (const mode of Object.values(modes)) {
      mode.enabled = false;
      mode.ultrafast = false;
    }

    // Speed is a discussion preference: navigating /tree must not undo a user's paid-tier choice.
    const entries = ctx.sessionManager.getEntries();
    for (let index = entries.length - 1; index >= 0; index--) {
      const entry = entries[index];
      if (entry.type !== 'custom' || entry.customType !== SPEED_ENTRY_TYPE) continue;

      const saved = entry.data;
      const data = typeof saved === 'object' && saved !== null && !Array.isArray(saved)
        ? saved as Record<string, unknown> : undefined;
      const validOpenAI = data?.openai === 'normal' || data?.openai === 'fast' || data?.openai === 'ultrafast';
      const validAnthropic = data?.anthropic === 'normal' || data?.anthropic === 'fast';
      if (data?.version !== 1 || !validOpenAI || !validAnthropic) {
        ctx.ui.notify('Invalid speed state in session history; using Normal mode.', 'warning');
        break;
      }

      modes.openai.enabled = data.openai !== 'normal';
      modes.openai.ultrafast = data.openai === 'ultrafast';
      modes.anthropic.enabled = data.anthropic === 'fast';
      break;
    }

    refreshStatus(ctx);
  });

  pi.on('session_shutdown', () => { sessionGeneration++; });

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
