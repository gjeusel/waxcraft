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
  expandHome,
  findLast,
  isBlocked,
  isPoolId,
  parseConfig,
  stateKey,
  StateStore,
  usage,
  wrapProvider,
  type Account,
  type PoolConfig,
  type PoolId,
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

function until(epochMs: number, now: number): string {
  const minutes = Math.max(0, Math.round((epochMs - now) / 60_000));

  return minutes < 90 ? `${minutes}m` : minutes < 48 * 60 ? `${Math.round(minutes / 60)}h` : `${Math.round(minutes / 1440)}d`;
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

  /** Footer status: the account the session runs on and its usage. */
  function refreshStatus(ctx: ExtensionContext, account?: string): void {
    const pool = ctx.model?.provider;
    if (!isPoolId(pool) || !pooled(pool)) {
      ctx.ui.setStatus(STATUS_KEY, undefined);
      return;
    }

    const latest = findLast(
      ctx.sessionManager.getBranch(),
      (entry) => entry.type === 'message' && entry.message.role === 'assistant' && entry.message.provider === pool,
    );
    const message = latest?.type === 'message' && latest.message.role === 'assistant' ? latest.message : undefined;
    const current = account ?? (message && accountOf(message)) ?? config?.pools[pool]?.[0].id ?? '';
    const used = usage(store.read()[stateKey(pool, current)], config?.threshold ?? 1, Date.now());

    ctx.ui.setStatus(STATUS_KEY, `${current} ${percent(used)}`);
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

        lines.push(`${pool}${pooled(pool) ? '' : ' (not pooled: needs two accounts)'}`);
        for (const account of accounts ?? []) {
          const state = states[stateKey(pool, account)];
          const windows = Object.entries(state?.windows ?? {})
            .filter(([, window]) => window.resetsAt === undefined || window.resetsAt > now)
            .map(([name, window]) => `${name} ${percent(window.used)}${window.resetsAt ? ` (resets in ${until(window.resetsAt, now)})` : ''}`);
          const blocked = isBlocked(state, now) && state?.blockedUntil
            ? ` · blocked (${state.blockReason}) for ${until(state.blockedUntil, now)}`
            : '';
          const source = pool === 'claude-code'
            ? (account.configDir ?? 'default login')
            : account.id === accounts?.[0].id ? 'openai-codex login' : codexLoginId(account);

          lines.push(`  ${account.id} [${source}]: ${windows.join(', ') || 'no usage reported yet'}${blocked}`);
        }
      }
      lines.push(`switch threshold: ${percent(config.threshold)}`);

      ctx.ui.notify(lines.join('\n'), 'info');
    },
  });
}
