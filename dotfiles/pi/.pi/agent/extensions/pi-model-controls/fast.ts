import { readdirSync, readFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import {
  getAgentDir, parseFrontmatter, type ExtensionAPI, type ExtensionContext,
} from '@earendil-works/pi-coding-agent';
import { Container, Key, SelectList, Text, truncateToWidth } from '@earendil-works/pi-tui';

type Model = ExtensionContext['model'];
type SpeedMode = 'normal' | 'fast' | 'ultrafast';
type SpeedState = { version: 1; openai: SpeedMode; anthropic: 'normal' | 'fast' };

/** An `Agent` tool call whose child run has not started yet; `resume` targets an existing agent id. */
type SubagentSpawn = {
  toolCallId: string;
  type?: string;
  resume?: string;
  prompt: string;
  inherited: SpeedState;
  requested?: SpeedMode;
};

/**
 * pi-subagents runs sub-agents in-process, each session with its own instance of this extension,
 * so the speed a child inherits is exchanged through `globalThis`.
 */
export type SpeedRegistry = { main?: SpeedState; spawns: SubagentSpawn[] };

export const SPEED_ENTRY_TYPE = 'pi-speed-mode';

const ANTHROPIC_FAST_BETA = 'fast-mode-2026-02-01';

const NORMAL_SPEED: SpeedState = { version: 1, openai: 'normal', anthropic: 'normal' };

/** pi-subagents names child sessions `<agent type>#<first 8 hex digits of the agent id>`. */
const SUBAGENT_SESSION_NAME = /^(?<type>[^#]+)#(?<id>[0-9a-f]{8})$/u;

/** Spawns whose child never consumes them (unknown type, agent without this extension). */
const MAX_PENDING_SPAWNS = 64;

// A prompt section rather than an Agent tool guideline: Pi renders tool guidelines only for its
// default prompt, and pi-subagents children replace it.
const AGENT_SPEED_SECTION = 'The Agent tool also accepts an optional `speed` parameter ("normal", ' +
  '"fast", or "ultrafast"; not in its schema). Omit it to use the agent type\'s configured speed, ' +
  'else this session\'s speed; set it only when the user asks for a specific sub-agent speed.';

export const speedRegistry: SpeedRegistry = ((globalThis as Record<symbol, unknown>)[
  Symbol.for('pi-model-controls.speed-registry')
] ??= { spawns: [] }) as SpeedRegistry;

function isSpeedMode(value: unknown): value is SpeedMode {
  return value === 'normal' || value === 'fast' || value === 'ultrafast';
}

/** pi-subagents' local agent directories (packages excluded), from lowest to highest priority. */
export function agentDirectories(cwd: string): string[] {
  return [join(getAgentDir(), 'agents'), join(cwd, '.agents', 'agents'), join(cwd, '.pi', 'agents')];
}

/** The `speed:` frontmatter of an agent type; pi-subagents itself ignores the field. */
export function agentSpeed(type: string, directories: string[]): SpeedMode | undefined {
  let speed: SpeedMode | undefined;
  for (const directory of directories) {
    let files: string[];
    try {
      files = readdirSync(directory).filter((file) => file.endsWith('.md'));
    } catch {
      continue;
    }

    for (const file of files) {
      try {
        const content = readFileSync(join(directory, file), 'utf8').replace(/^\uFEFF/u, '');
        const { frontmatter } = parseFrontmatter(content);
        const name = typeof frontmatter.name === 'string' ? frontmatter.name.trim() : basename(file, '.md');
        // A higher-priority definition replaces the whole agent, including an absent speed.
        if (name === type) speed = isSpeedMode(frontmatter.speed) ? frontmatter.speed : undefined;
      } catch { /* pi-subagents reports malformed agent files. */ }
    }
  }

  return speed;
}

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

  function restore(state: SpeedState): void {
    modes.openai.enabled = state.openai !== 'normal';
    modes.openai.ultrafast = state.openai === 'ultrafast';
    modes.anthropic.enabled = state.anthropic === 'fast';
  }

  // Set at session_start when this session is a pi-subagents child.
  let subagent: { type: string; id: string } | undefined;
  let awaitingSubagentSpeed = false;

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
    if (subagent === undefined) speedRegistry.main = snapshot();
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
    let restored = false;
    const entries = ctx.sessionManager.getEntries();
    for (let index = entries.length - 1; index >= 0; index--) {
      const entry = entries[index];
      if (entry.type !== 'custom' || entry.customType !== SPEED_ENTRY_TYPE) continue;

      restored = true;
      const saved = entry.data;
      const data = typeof saved === 'object' && saved !== null && !Array.isArray(saved)
        ? saved as Record<string, unknown> : undefined;
      const validOpenAI = data?.openai === 'normal' || data?.openai === 'fast' || data?.openai === 'ultrafast';
      const validAnthropic = data?.anthropic === 'normal' || data?.anthropic === 'fast';
      if (data?.version !== 1 || !validOpenAI || !validAnthropic) {
        ctx.ui.notify('Invalid speed state in session history; using Normal mode.', 'warning');
        break;
      }

      restore(data as SpeedState);
      break;
    }

    // pi-subagents names the child session before binding extensions. A child's own history wins,
    // but children never record their resolved speed, so a resumed child resolves it again.
    const groups = SUBAGENT_SESSION_NAME.exec(ctx.sessionManager.getSessionName() ?? '')?.groups;
    subagent = groups === undefined ? undefined : { type: groups.type, id: groups.id };
    awaitingSubagentSpeed = subagent !== undefined && !restored;
    if (subagent === undefined) speedRegistry.main = snapshot();

    refreshStatus(ctx);
  });

  pi.on('tool_call', (event) => {
    if (event.toolName !== 'Agent') return;

    const { prompt, speed, subagent_type: type, resume, isolated } = event.input as Record<string, unknown>;
    if (speed !== undefined && !isSpeedMode(speed)) {
      return { block: true, reason: 'Agent speed must be "normal", "fast", or "ultrafast".' };
    }

    // An isolated child loads no extension, so it could never claim the spawn.
    if (typeof prompt !== 'string' || prompt === '' || isolated === true) return;

    speedRegistry.spawns.push({
      toolCallId: event.toolCallId,
      // pi-subagents resolves agent types case-insensitively.
      type: typeof type === 'string' ? type.toLowerCase() : undefined,
      resume: typeof resume === 'string' ? resume : undefined,
      prompt,
      inherited: snapshot(),
      requested: speed,
    });
    if (speedRegistry.spawns.length > MAX_PENDING_SPAWNS) speedRegistry.spawns.shift();
  });

  pi.on('tool_result', (event) => {
    if (event.toolName !== 'Agent' || !event.isError) return;

    // A blocked or failed call starts no child; a later call with the same prompt must not claim it.
    const index = speedRegistry.spawns.findIndex((spawn) => spawn.toolCallId === event.toolCallId);
    if (index !== -1) speedRegistry.spawns.splice(index, 1);
  });

  pi.on('before_agent_start', (event, ctx) => {
    const prompt: unknown = event.prompt;
    if (subagent !== undefined && typeof prompt === 'string') {
      const child = subagent;
      // A resume names the agent id. A spawn's first prompt is the call's prompt, after any
      // inherited parent context. Live resumes reuse the session, so every run looks for its call.
      const index = speedRegistry.spawns.findIndex((spawn) => spawn.resume !== undefined
        ? spawn.resume.slice(0, 8) === child.id
        : spawn.type === child.type.toLowerCase() && prompt.endsWith(spawn.prompt));
      const spawn = index === -1 ? undefined : speedRegistry.spawns.splice(index, 1)[0];

      // Workflow spawns have no recorded call and inherit the main session's speed; later runs
      // without a call (steering, follow-ups) keep the resolved speed.
      if (spawn !== undefined || awaitingSubagentSpeed) {
        const speed = spawn?.requested ?? agentSpeed(child.type, agentDirectories(ctx.cwd));
        restore(spawn?.inherited ?? speedRegistry.main ?? NORMAL_SPEED);
        if (speed !== undefined) {
          restore({ version: 1, openai: speed, anthropic: speed === 'normal' ? 'normal' : 'fast' });
        }

        refreshStatus(ctx);
      }

      awaitingSubagentSpeed = false;
    }

    const options = event.systemPromptOptions;
    if (options.selectedTools.includes('Agent')) options.sections.agent_speed = AGENT_SPEED_SECTION;
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
