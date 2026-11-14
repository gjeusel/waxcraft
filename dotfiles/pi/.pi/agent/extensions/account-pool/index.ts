/**
 * account-pool — consume several Claude and ChatGPT subscriptions through one provider each.
 *
 * `claude-code` (pi-claude-code) and `openai-codex` keep their ids and models; each request runs
 * on one account of the pool, which switches when usage nears its limit (see pool.ts). Claude
 * accounts are Claude Code configuration directories; extra Codex accounts are logins stored by
 * Pi under hidden `openai-codex-<id>` providers (`/login openai-codex-<id>`).
 */
import { existsSync, readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';
import type { Provider } from '@earendil-works/pi-ai';
import { builtinProviders } from '@earendil-works/pi-ai/providers/all';
import { getAgentDir, type ExtensionAPI, type ExtensionContext } from '@earendil-works/pi-coding-agent';
import {
  accountOf,
  activeWindows,
  expandHome,
  findLast,
  isBlocked,
  isPoolId,
  parseConfig,
  stateKey,
  StateStore,
  wrapProvider,
  type Account,
  type AccountState,
  type PoolConfig,
  type PoolId,
  type UsageWindow,
} from './pool.ts';

const STATUS_KEY = 'account-pool';
// Marks a wrapped provider with the provider it wraps, so a later session start re-wraps the
// original instead of stacking pools.
const BASE = Symbol.for('account-pool.base');

type Wrapped = Provider & { [BASE]?: Provider };

export function codexLoginId(account: Account): string {
  return `openai-codex-${account.id}`;
}

function loadConfig(path: string): PoolConfig | Error | undefined {
  if (!existsSync(path)) return undefined;

  try {
    return parseConfig(readFileSync(path, 'utf8'));
  } catch (error) {
    return new Error(`account-pool: invalid ${path}: ${error instanceof Error ? error.message : String(error)}`);
  }
}

function percent(fraction: number): string {
  return `${Math.round(fraction * 100)}%`;
}

function duration(ms: number): string {
  const minutes = Math.max(0, Math.round(ms / 60_000));

  return minutes < 90 ? `${minutes}m` : minutes < 48 * 60 ? `${Math.round(minutes / 60)}h` : `${Math.round(minutes / 1440)}d`;
}

// `seven_day_overage_included` is the weekly per-model window, which Claude Code names the Fable limit.
const WINDOW_LABELS: Record<string, string> = {
  five_hour: '5h',
  seven_day: '7d',
  seven_day_overage_included: 'fable',
  primary: '1st',
  secondary: '2nd',
};
// The footer shows Claude's two weekly windows as a single weekly figure.
const MERGED_INTO: Record<string, string> = { seven_day_overage_included: 'seven_day' };
const STALE_MS = 60 * 60_000;
const BAR_WIDTH = 20;
const LEVELS = '▁▂▃▄▅▆▇█';
const EIGHTHS = ' ▏▎▍▌▋▊▉';

export interface ShownWindow extends UsageWindow {
  label: string;
}

/**
 * The windows to display, as the provider reported them. With `merge`, the weekly windows show as
 * one: the most used, which then carries the warning of any of them.
 */
export function shownWindows(state: AccountState | undefined, now: number, options: { merge: boolean }): ShownWindow[] {
  const shown = new Map<string, ShownWindow>();
  for (const [name, window] of activeWindows(state, now)) {
    const key = (options.merge && MERGED_INTO[name]) || name;
    const fromLength = window.minutes && (window.minutes >= 1440 ? `${Math.round(window.minutes / 1440)}d` : `${Math.round(window.minutes / 60)}h`);
    const previous = shown.get(key);
    const warning = window.warning || previous?.warning;

    shown.set(key, {
      ...(previous && previous.used >= window.used ? previous : { ...window, label: fromLength || (WINDOW_LABELS[key] ?? key) }),
      ...(warning ? { warning } : {}),
    });
  }

  return [...shown.values()];
}

/** Footer status: the account, then one level per window, such as `main · 5h ▂ · 7d ▇`. */
export function footerStatus(account: string, state: AccountState | undefined, now: number): string {
  const level = (used: number) => LEVELS[Math.round(Math.min(1, Math.max(0, used)) * (LEVELS.length - 1))];

  return [account, ...shownWindows(state, now, { merge: true }).map((window) => `${window.label} ${level(window.used)}`)].join(' · ');
}

/** A filling bar, with eighths of a cell: `███▍░░░░░░░░░░░░░░░░` for 17%. */
export function bar(used: number, width = BAR_WIDTH): string {
  const eighths = Math.round(Math.min(1, Math.max(0, used)) * width * 8);
  const full = Math.floor(eighths / 8);
  const partial = eighths % 8 > 0 ? EIGHTHS[eighths % 8] : '';

  return ('█'.repeat(full) + partial).padEnd(width, '░');
}

/** One account of `/accounts`: its name and login, then one bar per window. */
export function accountLines(
  account: { id: string; source: string; inSession: boolean },
  state: AccountState | undefined,
  now: number,
): string[] {
  const windows = shownWindows(state, now, { merge: false });
  const blocked = isBlocked(state, now) && state?.blockedUntil
    ? ` · blocked (${state.blockReason}) for ${duration(state.blockedUntil - now)}`
    : '';
  // Usage is only what the account's own responses reported, so an idle account's figures age.
  const age = state?.updatedAt === undefined ? undefined : now - state.updatedAt;
  const stale = age !== undefined && age > STALE_MS && windows.length > 0 ? ` · reported ${duration(age)} ago` : '';
  const labelWidth = Math.max(0, ...windows.map((window) => window.label.length));

  return [
    `${account.inSession ? '●' : ' '} ${account.id}  ${account.source}${blocked}${stale}`,
    ...windows.map((window) => {
      const reset = window.resetsAt ? `resets in ${duration(window.resetsAt - now)}` : '';

      return `  ${window.label.padEnd(labelWidth)}  ${bar(window.used)} ${percent(window.used).padStart(4)} ${window.warning ? '!' : ' '} ${reset}`.trimEnd();
    }),
    ...(windows.length === 0 ? ['  no usage reported yet'] : []),
  ];
}

export default function (pi: ExtensionAPI) {
  const configPath = join(getAgentDir(), 'account-pool.json');
  const store = new StateStore(join(getAgentDir(), 'account-pool-state'));
  const loaded = loadConfig(configPath);
  const config = loaded instanceof Error ? undefined : loaded;
  const pooled = (pool: PoolId) => (config?.pools[pool]?.length ?? 0) > 1;
  const codexBase = builtinProviders().find((provider) => provider.id === 'openai-codex');

  // Extra Codex accounts need somewhere to keep their OAuth login: a model-less provider each,
  // which `/login` lists. Pi stores, refreshes, and locks the credential as for any provider.
  if (codexBase?.auth.oauth && pooled('openai-codex')) {
    for (const account of config?.pools['openai-codex']?.slice(1) ?? []) {
      pi.registerProvider({
        ...codexBase,
        id: codexLoginId(account),
        name: `OpenAI Codex account "${account.id}" (account-pool)`,
        auth: { oauth: codexBase.auth.oauth },
        getModels: () => [],
        getAllModels: () => [],
        refreshModels: undefined,
      });
    }
  }

  // Wrappers of this extension instance; a wrapper left by a reloaded instance is replaced.
  const wrappers = new WeakSet<Provider>();

  function wrapPools(ctx: ExtensionContext): void {
    if (!config) return;

    // Requests outlive this context (subagents share the model runtime), so keep the registry.
    const registry = ctx.modelRegistry;
    for (const pool of ['claude-code', 'openai-codex'] as const) {
      const accounts = config.pools[pool] ?? [];
      const current = registry.getRegisteredNativeProvider(pool) as Wrapped | undefined;
      if (current?.[BASE] && wrappers.has(current)) continue;

      const base = current?.[BASE] ?? current ?? (pool === 'openai-codex' ? codexBase : undefined);
      if (!base || !pooled(pool)) continue;

      const wrapped: Wrapped = wrapProvider(base, {
        pool,
        accounts,
        threshold: config.threshold,
        store,
        async credentials(account) {
          const isDefault = account.id === accounts[0].id;
          if (pool === 'claude-code') {
            const configDir = account.configDir && resolve(expandHome(account.configDir));
            // Claude Code keys its Keychain login on CLAUDE_CONFIG_DIR being set at all: setting it
            // to the default ~/.claude looks for another login than the one `claude` uses.
            const isDefaultDir = configDir === join(homedir(), '.claude');

            return configDir && !isDefaultDir ? { env: { PI_CLAUDE_CODE_CONFIG_DIR: configDir } } : {};
          }
          if (isDefault) return {};

          const auth = await registry.getProviderAuth(codexLoginId(account));
          if (!auth?.auth.apiKey) throw new Error(`Codex account "${account.id}" is not logged in: run /login ${codexLoginId(account)}`);

          return { apiKey: auth.auth.apiKey };
        },
      });
      wrapped[BASE] = base;
      wrappers.add(wrapped);
      pi.registerProvider(wrapped);
    }
  }

  /** The account of the session's latest response of `pool`, else the default login. */
  function sessionAccount(ctx: ExtensionContext, pool: PoolId): string {
    const latest = findLast(
      ctx.sessionManager.getBranch(),
      (entry) => entry.type === 'message' && entry.message.role === 'assistant' && entry.message.provider === pool,
    );
    const message = latest?.type === 'message' && latest.message.role === 'assistant' ? latest.message : undefined;

    return (message && accountOf(message)) ?? config?.pools[pool]?.[0].id ?? '';
  }

  /** Footer status: the account the session runs on and its usage. */
  function refreshStatus(ctx: ExtensionContext, account?: string): void {
    const pool = ctx.model?.provider;
    if (!isPoolId(pool) || !pooled(pool)) {
      ctx.ui.setStatus(STATUS_KEY, undefined);
      return;
    }

    const current = account ?? sessionAccount(ctx, pool);

    ctx.ui.setStatus(STATUS_KEY, footerStatus(current, store.read()[stateKey(pool, current)], Date.now()));
  }

  pi.on('session_start', (_event, ctx) => {
    if (loaded instanceof Error) ctx.ui.notify(loaded.message, 'error');

    wrapPools(ctx);
    refreshStatus(ctx);
  });

  // A subagent shares this session's model runtime, and starting one registers pi-claude-code's
  // provider again (every extension factory runs, even those its allowlist drops), which replaces
  // the pool for every session of the process. Subagents that load this extension wrap it again
  // at their start; each turn restores it otherwise, before its request.
  pi.on('turn_start', (_event, ctx) => wrapPools(ctx));

  pi.on('model_select', (_event, ctx) => refreshStatus(ctx));

  // Runs before Pi persists the message, so the branch still ends at the previous response.
  pi.on('message_end', (event, ctx) => {
    const message = event.message;
    if (message.role !== 'assistant' || !isPoolId(message.provider) || !pooled(message.provider)) return;

    const pool = message.provider;
    const account = accountOf(message);
    const previous = findLast(
      ctx.sessionManager.getBranch(),
      (entry) =>
        entry.type === 'message' && entry.message.role === 'assistant' && entry.message.provider === pool &&
        entry.message.stopReason !== 'error' && entry.message.stopReason !== 'aborted',
    );
    const previousAccount =
      previous?.type === 'message' && previous.message.role === 'assistant'
        ? (accountOf(previous.message) ?? config?.pools[pool]?.[0].id)
        : undefined;
    if (account && previousAccount && account !== previousAccount && message.stopReason !== 'error') {
      ctx.ui.notify(`account-pool: ${pool} moved from "${previousAccount}" to "${account}"`, 'info');
    }

    refreshStatus(ctx, account);
  });

  pi.registerCommand('accounts', {
    description: 'Show the usage of every pooled Claude Code and Codex account',
    handler: async (_args, ctx) => {
      if (loaded instanceof Error) {
        ctx.ui.notify(loaded.message, 'error');
        return;
      }
      if (!config) {
        ctx.ui.notify(`account-pool: no ${configPath}; see the Pi README`, 'warning');
        return;
      }

      const now = Date.now();
      const states = store.read();
      const lines: string[] = [];
      for (const [pool, accounts] of Object.entries(config.pools)) {
        if (!isPoolId(pool)) continue;

        const inSession = ctx.model?.provider === pool && pooled(pool) ? sessionAccount(ctx, pool) : undefined;

        lines.push(`${pool}${pooled(pool) ? '' : ' (not pooled: needs two accounts)'}`, '');
        for (const account of accounts ?? []) {
          const source = pool === 'claude-code'
            ? (account.configDir ?? 'default login')
            : account.id === accounts?.[0].id ? 'openai-codex login' : codexLoginId(account);

          lines.push(
            ...accountLines({ id: account.id, source, inSession: account.id === inSession }, states[stateKey(pool, account)], now),
            '',
          );
        }
      }
      lines.push(`● this session's account · switches at ${percent(config.threshold)}, or when the provider warns (!)`);

      ctx.ui.notify(lines.join('\n'), 'info');
    },
  });
}
