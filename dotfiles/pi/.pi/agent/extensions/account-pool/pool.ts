/**
 * Account pools: several subscription logins behind one provider id.
 *
 * The pooled provider keeps the id and models of the provider it wraps, so model selection and
 * every extension keyed on the provider id keep working. Each request runs on one account of the
 * pool: the account of the session's latest response, unless that account is blocked or, at a
 * user turn, its usage reached the threshold. Usage comes from what each provider reports on its
 * responses and is shared by every Pi process through a small state file.
 */
import { mkdirSync, readdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import {
  createAssistantMessageEventStream,
  type Api,
  type AssistantMessage,
  type AssistantMessageEvent,
  type AssistantMessageEventStream,
  type Message,
  type Model,
  type Provider,
  type ProviderResponse,
  type SimpleStreamOptions,
  type TranscriptContext,
} from '@earendil-works/pi-ai';

export const POOLED_PROVIDERS = ['claude-code', 'openai-codex'] as const;
export type PoolId = (typeof POOLED_PROVIDERS)[number];

/** Diagnostic recording the account that produced an assistant message. */
export const POOL_DIAGNOSTIC = 'account-pool';
const CLAUDE_RATE_LIMIT_DIAGNOSTIC = 'claude-code.rate-limit';
// pi-claude-code's native replay carrier holds the message with its thinking signatures.
const CLAUDE_REPLAY_DIAGNOSTIC = 'claude-code.native-assistant.v1';

export const DEFAULT_THRESHOLD = 0.9;
const QUOTA_BLOCK_MS = 5 * 60_000;
// A plain rate limit (requests per minute, not the subscription quota) clears within a minute.
const RATE_LIMIT_BLOCK_MS = 60_000;
const AUTH_BLOCK_MS = 10 * 60_000;
const ACCOUNT_ID = /^[a-z0-9][a-z0-9_-]*$/i;

export interface Account {
  id: string;
  /** Claude Code configuration directory of a `claude-code` account. Absent: the default login. */
  configDir?: string;
}

export interface PoolConfig {
  /** Usage fraction (0-1) at which a session moves to another account at its next user turn. */
  threshold: number;
  /** Accounts by pooled provider, in order of preference. The first one is the default login. */
  pools: Partial<Record<PoolId, Account[]>>;
}

export interface UsageWindow {
  /** Used fraction of the window, 0-1. */
  used: number;
  /** Epoch milliseconds at which the window resets. */
  resetsAt?: number;
  /** The provider warned that the window is nearly used up. */
  warning?: boolean;
}

export interface AccountState {
  windows: Record<string, UsageWindow>;
  blockedUntil?: number;
  blockReason?: string;
  updatedAt?: number;
}

export type PoolState = Record<string, AccountState>;

export interface Failure {
  reason: 'quota' | 'rate-limit' | 'auth';
  until: number;
}

/** `Array.prototype.findLast`, which the ES2022 target lacks. */
export function findLast<T>(items: readonly T[] | undefined, predicate: (item: T) => boolean): T | undefined {
  for (let index = (items?.length ?? 0) - 1; index >= 0; index--) {
    const item = (items as readonly T[])[index];
    if (predicate(item)) return item;
  }

  return undefined;
}

export function isPoolId(value: string | undefined): value is PoolId {
  return (POOLED_PROVIDERS as readonly (string | undefined)[]).includes(value);
}

export function expandHome(path: string): string {
  return path === '~' || path.startsWith('~/') ? homedir() + path.slice(1) : path;
}

/** Parse the pool configuration. Throws with a readable message when it is invalid. */
export function parseConfig(text: string): PoolConfig {
  const raw: unknown = JSON.parse(text);
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) throw new Error('expected a JSON object');

  const { threshold = DEFAULT_THRESHOLD, pools = {} } = raw as Record<string, unknown>;
  if (typeof threshold !== 'number' || !(threshold > 0 && threshold <= 1)) {
    throw new Error('"threshold" must be a number in (0, 1]');
  }
  if (!pools || typeof pools !== 'object' || Array.isArray(pools)) throw new Error('"pools" must be an object');

  const config: PoolConfig = { threshold, pools: {} };
  for (const [pool, accounts] of Object.entries(pools)) {
    if (!isPoolId(pool)) throw new Error(`unknown pool "${pool}" (expected ${POOLED_PROVIDERS.join(' or ')})`);
    if (!Array.isArray(accounts)) throw new Error(`"pools.${pool}" must be an array of accounts`);

    const seen = new Set<string>();
    config.pools[pool] = accounts.map((account: unknown) => {
      const { id, configDir } = (account ?? {}) as Record<string, unknown>;
      if (typeof id !== 'string' || !ACCOUNT_ID.test(id)) {
        throw new Error(`"pools.${pool}": each account needs an "id" made of letters, digits, "-" or "_"`);
      }
      if (seen.has(id)) throw new Error(`"pools.${pool}": duplicate account "${id}"`);
      seen.add(id);

      if (configDir !== undefined && (pool !== 'claude-code' || typeof configDir !== 'string')) {
        throw new Error(`"pools.${pool}.${id}": "configDir" is a string, for claude-code accounts only`);
      }

      return configDir === undefined ? { id } : { id, configDir };
    });
  }

  return config;
}

/**
 * Usage and blocks of every account, shared by Pi processes: one JSON file per account, so
 * processes updating different accounts never overwrite each other. Two writes for the same
 * account are both fresh reports of it, and the last one wins.
 */
export class StateStore {
  readonly dir: string;

  constructor(dir: string) {
    this.dir = dir;
  }

  private file(key: string): string {
    return join(this.dir, `${key.replaceAll('/', '__')}.json`);
  }

  read(): PoolState {
    const states: PoolState = {};
    let names: string[] = [];
    try {
      names = readdirSync(this.dir).filter((name) => name.endsWith('.json'));
    } catch {
      return states;
    }

    for (const name of names) {
      try {
        states[name.slice(0, -'.json'.length).replace('__', '/')] = JSON.parse(readFileSync(join(this.dir, name), 'utf8'));
      } catch {
        // A file being replaced or corrupted counts as no report yet.
      }
    }

    return states;
  }

  update(key: string, change: (state: AccountState) => AccountState): void {
    const state = { ...change(this.read()[key] ?? { windows: {} }), updatedAt: Date.now() };

    mkdirSync(this.dir, { recursive: true });
    const temporary = `${this.file(key)}.${process.pid}.tmp`;
    writeFileSync(temporary, `${JSON.stringify(state, null, 2)}\n`);
    renameSync(temporary, this.file(key));
  }
}

export function stateKey(pool: PoolId, account: Account | string): string {
  return `${pool}/${typeof account === 'string' ? account : account.id}`;
}

/** Highest used fraction across the windows that have not reset yet. */
export function usage(state: AccountState | undefined, threshold: number, now: number): number {
  let used = 0;
  for (const window of Object.values(state?.windows ?? {})) {
    if (window.resetsAt !== undefined && window.resetsAt <= now) continue;

    used = Math.max(used, window.warning ? Math.max(window.used, threshold) : window.used);
  }

  return used;
}

export function isBlocked(state: AccountState | undefined, now: number): boolean {
  return (state?.blockedUntil ?? 0) > now;
}

/**
 * The account for one request. The current account stays unless it is blocked or, at a user turn,
 * its usage reached the threshold while another account still has room. Otherwise the first
 * account with room wins, then the least used one. Undefined when every account is blocked or
 * excluded.
 */
export function chooseAccount(
  accounts: readonly Account[],
  states: PoolState,
  pool: PoolId,
  options: { current?: string; userTurn: boolean; threshold: number; now: number; exclude?: ReadonlySet<string> },
): Account | undefined {
  const { current: currentId, userTurn, threshold, now, exclude } = options;
  const stateOf = (account: Account) => states[stateKey(pool, account)];
  const usable = accounts.filter((account) => !exclude?.has(account.id) && !isBlocked(stateOf(account), now));
  const roomy = usable.filter((account) => usage(stateOf(account), threshold, now) < threshold);
  const current = usable.find((account) => account.id === currentId);

  if (current && (!userTurn || roomy.includes(current))) return current;
  if (roomy.length > 0) return roomy[0];
  if (current) return current;

  return usable.reduce<Account | undefined>(
    (best, account) =>
      !best || usage(stateOf(account), threshold, now) < usage(stateOf(best), threshold, now) ? account : best,
    undefined,
  );
}

function resetHint(message: string, now: number): number | undefined {
  // Claude Code: "Claude AI usage limit reached|1794403800".
  const epoch = /\|(\d{10})\b/.exec(message) ?? /resets?_?(?:at)?["':\s]+(\d{10})\b/i.exec(message);
  if (epoch) return Number(epoch[1]) * 1000;

  // pi-ai's Codex wording: "You have hit your ChatGPT usage limit (plus plan). Try again in ~42 min."
  const minutes = /try again in ~?\s*(\d+)\s*min/i.exec(message);
  if (minutes) return now + Number(minutes[1]) * 60_000;

  return undefined;
}

const FAILURE_PATTERNS: Record<PoolId, { quota: RegExp; rateLimit: RegExp; auth: RegExp }> = {
  'claude-code': {
    quota: /usage limit|hit your limit|limit reached|out of extra usage|usage credits|Claude Code billing/i,
    rateLimit: /rate.?limit|too many requests|(?<![\w.])429(?![\w.])/i,
    auth: /not logged in|claude auth login|authentication_error|(?<![\w.])401(?![\w.])|invalid (?:api key|bearer|token)|oauth token/i,
  },
  'openai-codex': {
    quota: /usage limit|usage_limit_reached|usage_not_included|subscription_sharing\w*limit/i,
    rateLimit: /rate.?limit|too many requests|(?<![\w.])429(?![\w.])/i,
    auth: /(?<![\w.])401(?![\w.])|unauthorized|invalid_grant|token (?:has )?expired|refresh token|no api key|not logged in/i,
  },
};

/**
 * Whether a failed request means its account is unusable for now, and until when: out of its
 * subscription quota, rate limited (429), or no longer logged in. Overload and network errors are
 * not the account's fault and return undefined.
 */
export function classifyFailure(
  pool: PoolId,
  errorMessage: string,
  state: AccountState | undefined,
  now: number,
): Failure | undefined {
  const patterns = FAILURE_PATTERNS[pool];
  if (patterns.auth.test(errorMessage)) return { reason: 'auth', until: now + AUTH_BLOCK_MS };

  const hint = resetHint(errorMessage, now);
  if (!patterns.quota.test(errorMessage)) {
    return patterns.rateLimit.test(errorMessage) ? { reason: 'rate-limit', until: hint ?? now + RATE_LIMIT_BLOCK_MS } : undefined;
  }

  // Without a reset in the message, a nearly full window tells when the quota returns.
  const fullWindow = Object.values(state?.windows ?? {})
    .filter((window) => window.used >= 0.95 && window.resetsAt !== undefined && window.resetsAt > now)
    .map((window) => window.resetsAt as number);
  const until = hint ?? (fullWindow.length > 0 ? Math.max(...fullWindow) : now + QUOTA_BLOCK_MS);

  return { reason: 'quota', until };
}

function record(value: unknown): Record<string, unknown> | undefined {
  return value && typeof value === 'object' && !Array.isArray(value) ? (value as Record<string, unknown>) : undefined;
}

function epochMs(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isFinite(value) && value > 0 ? value * 1000 : undefined;
}

export interface Observation {
  windows: Record<string, UsageWindow>;
  blockedUntil?: number;
}

/** Usage reported by Claude Code's `rate_limit_event`, which pi-claude-code attaches to responses. */
export function claudeObservation(message: AssistantMessage): Observation | undefined {
  const details = record(findLast(message.diagnostics, (item) => item.type === CLAUDE_RATE_LIMIT_DIAGNOSTIC)?.details);
  if (!details) return undefined;

  const windows: Record<string, UsageWindow> = {};
  for (const [name, value] of Object.entries(record(details.unifiedWindows) ?? {})) {
    const window = record(value);
    if (typeof window?.utilization !== 'number') continue;

    windows[name] = {
      used: window.utilization,
      resetsAt: epochMs(window.resetsAt),
      ...(window.status === 'allowed_warning' ? { warning: true } : {}),
    };
  }

  const type = typeof details.rateLimitType === 'string' ? details.rateLimitType : undefined;
  if (type && !windows[type] && details.status === 'allowed_warning') {
    windows[type] = { used: 0, resetsAt: epochMs(details.resetsAt), warning: true };
  }

  // A rejection, or a response charged to usage credits, means the plan limit is used up.
  const exhausted = details.status === 'rejected' || details.isUsingOverage === true;
  const blockedUntil = exhausted ? (epochMs(details.resetsAt) ?? Date.now() + QUOTA_BLOCK_MS) : undefined;

  return { windows, blockedUntil };
}

/** Usage from the `x-codex-*` headers of a Codex HTTP response. */
export function codexHeaderObservation(headers: Record<string, string>, now: number): Observation | undefined {
  const windows: Record<string, UsageWindow> = {};
  for (const name of ['primary', 'secondary']) {
    const used = Number(headers[`x-codex-${name}-used-percent`]);
    if (headers[`x-codex-${name}-used-percent`] === undefined || !Number.isFinite(used)) continue;

    const resetAt = epochMs(Number(headers[`x-codex-${name}-reset-at`]));
    const resetAfter = Number(headers[`x-codex-${name}-reset-after-seconds`]);
    windows[name] = {
      used: used / 100,
      resetsAt: resetAt ?? (Number.isFinite(resetAfter) ? now + resetAfter * 1000 : undefined),
    };
  }

  return Object.keys(windows).length > 0 ? { windows } : undefined;
}

/** Usage from a `codex.rate_limits` event, which replaces the headers on the WebSocket transport. */
export function codexEventObservation(data: unknown): Observation | undefined {
  const event = record(data);
  if (event?.type !== 'codex.rate_limits') return undefined;

  const limits = record(event.rate_limits);
  const windows: Record<string, UsageWindow> = {};
  for (const name of ['primary', 'secondary']) {
    const window = record(limits?.[name]);
    if (typeof window?.used_percent !== 'number') continue;

    windows[name] = { used: window.used_percent / 100, resetsAt: epochMs(window.reset_at) };
  }

  const resets = Object.values(windows).flatMap((window) => (window.resetsAt ? [window.resetsAt] : []));
  const blockedUntil =
    limits?.limit_reached === true ? (resets.length > 0 ? Math.max(...resets) : Date.now() + QUOTA_BLOCK_MS) : undefined;

  return { windows, blockedUntil };
}

export function accountOf(message: AssistantMessage): string | undefined {
  const details = record(findLast(message.diagnostics, (item) => item.type === POOL_DIAGNOSTIC)?.details);

  return typeof details?.account === 'string' ? details.account : undefined;
}

/**
 * Account of the latest successful response of the pool in `messages`. Responses from before the
 * pool, without a tag, came from the default login: the first account.
 */
export function latestAccount(messages: readonly Message[], pool: PoolId, defaultAccount: string): string | undefined {
  const latest = findLast(
    messages,
    (message) =>
      message.role === 'assistant' && message.provider === pool && message.stopReason !== 'error' &&
      message.stopReason !== 'aborted',
  );

  return latest?.role === 'assistant' ? (accountOf(latest) ?? defaultAccount) : undefined;
}

/**
 * Drop what only the producing account can replay from other accounts' responses: thinking and
 * its signatures, text and tool-call signatures, and Claude Code's native replay carrier. This is
 * what Pi itself drops when a conversation moves to another model.
 */
export function forAccount(messages: readonly Message[], pool: PoolId, account: string, defaultAccount: string): Message[] {
  return messages.map((message) => {
    if (message.role !== 'assistant' || message.provider !== pool) return message;
    if ((accountOf(message) ?? defaultAccount) === account) return message;

    return {
      ...message,
      diagnostics: message.diagnostics?.filter((item) => item.type !== CLAUDE_REPLAY_DIAGNOSTIC),
      content: message.content.flatMap((block): AssistantMessage['content'] => {
        if (block.type === 'thinking') return [];
        if (block.type === 'text') return [{ type: 'text', text: block.text }];

        const { thoughtSignature: _signature, ...toolCall } = block;

        return [toolCall];
      }),
    };
  });
}

export interface PoolOptions {
  pool: PoolId;
  accounts: readonly Account[];
  threshold: number;
  store: StateStore;
  /** Request options that select an account: Claude Code's config dir, or a Codex token. */
  credentials(account: Account): Promise<Partial<SimpleStreamOptions>>;
  now?: () => number;
}

function errorEvent(model: Model<Api>, errorMessage: string): AssistantMessageEvent {
  const error: AssistantMessage = {
    role: 'assistant',
    content: [],
    api: model.api,
    provider: model.provider,
    model: model.id,
    usage: {
      input: 0,
      output: 0,
      cacheRead: 0,
      cacheWrite: 0,
      totalTokens: 0,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
    },
    stopReason: 'error',
    errorMessage,
    timestamp: Date.now(),
  };

  return { type: 'error', reason: 'error', error };
}

/** The provider `base` with each request routed to one account of the pool. */
export function wrapProvider(base: Provider, options: PoolOptions): Provider {
  const { pool, accounts, threshold, store } = options;
  const now = options.now ?? Date.now;
  const defaultAccount = accounts[0].id;

  function observe(account: Account, observation: Observation | undefined): void {
    if (!observation) return;

    store.update(stateKey(pool, account), (state) => ({
      ...state,
      windows: { ...state.windows, ...observation.windows },
      blockedUntil: observation.blockedUntil,
      blockReason: observation.blockedUntil ? 'quota' : undefined,
    }));
  }

  function block(account: Account, failure: Failure): void {
    store.update(stateKey(pool, account), (state) => ({
      ...state,
      blockedUntil: failure.until,
      blockReason: failure.reason,
    }));
  }

  async function run(
    out: AssistantMessageEventStream,
    simple: boolean,
    model: Model<Api>,
    context: TranscriptContext,
    requestOptions: SimpleStreamOptions | undefined,
  ): Promise<void> {
    const lastMessage = findLast(context.messages, (message) => message.role !== 'system');
    const userTurn = lastMessage?.role === 'user';
    const current = latestAccount(context.messages, pool, defaultAccount);
    const exclude = new Set<string>();
    const pick = () =>
      chooseAccount(accounts, store.read(), pool, { current, userTurn, threshold, now: now(), exclude });
    // When every account left is blocked, the one that unblocks first still gets the request: its
    // error is more useful than a pool error, and a block can be stale.
    const soonestUnblocked = () => {
      const states = store.read();
      const until = (account: Account) => states[stateKey(pool, account)]?.blockedUntil ?? 0;

      return accounts
        .filter((account) => !exclude.has(account.id))
        .reduce<Account | undefined>((soonest, account) => (!soonest || until(account) < until(soonest) ? account : soonest), undefined);
    };

    let account = (pick() ?? soonestUnblocked()) as Account;

    for (;;) {
      exclude.add(account.id);

      let overrides: Partial<SimpleStreamOptions>;
      try {
        overrides = await options.credentials(account);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        block(account, { reason: 'auth', until: now() + AUTH_BLOCK_MS });
        const next = pick() ?? soonestUnblocked();
        if (next) {
          account = next;
          continue;
        }

        out.push(errorEvent(model, message));
        return;
      }

      const attempt = account;
      const attemptOptions: SimpleStreamOptions = {
        ...requestOptions,
        ...overrides,
        env: { ...requestOptions?.env, ...overrides.env },
        onResponse: async (response: ProviderResponse, responseModel: Model<Api>) => {
          if (pool === 'openai-codex') observe(attempt, codexHeaderObservation(response.headers, now()));
          await requestOptions?.onResponse?.(response, responseModel);
        },
        onProviderStreamEvent: async (data: unknown, eventModel: Model<Api>) => {
          if (pool === 'openai-codex') observe(attempt, codexEventObservation(data));
          await requestOptions?.onProviderStreamEvent?.(data, eventModel);
        },
      };
      const attemptContext = { ...context, messages: forAccount(context.messages, pool, attempt.id, defaultAccount) };
      const inner = simple
        ? base.streamSimple(model, attemptContext, attemptOptions)
        : base.stream(model, attemptContext, attemptOptions);

      let start: AssistantMessageEvent | undefined;
      let streamed = false;
      let retryWith: Account | undefined;
      for await (const event of inner) {
        // Hold the start event: an error before any output can still move to another account.
        if (!streamed && event.type === 'start') {
          start = event;
          continue;
        }

        const final = event.type === 'done' ? event.message : event.type === 'error' ? event.error : undefined;
        if (final) {
          final.diagnostics = [
            ...(final.diagnostics ?? []).filter((item) => item.type !== POOL_DIAGNOSTIC),
            { type: POOL_DIAGNOSTIC, timestamp: Date.now(), details: { pool, account: attempt.id } },
          ];
        }

        if (event.type === 'done' && pool === 'claude-code') observe(attempt, claudeObservation(event.message));
        if (event.type === 'error' && event.reason !== 'aborted') {
          const failure = classifyFailure(pool, event.error.errorMessage ?? '', store.read()[stateKey(pool, attempt)], now());
          if (failure) block(attempt, failure);
          // Output already shown cannot be taken back, so only a silent failure is replayed.
          retryWith = failure && !streamed ? pick() : undefined;
          if (retryWith) break;
        }

        if (!streamed) {
          streamed = true;
          if (start) out.push(start);
        }
        out.push(event);
      }

      if (!retryWith) return;

      account = retryWith;
    }
  }

  function stream(simple: boolean) {
    return (model: Model<Api>, context: TranscriptContext, requestOptions?: SimpleStreamOptions) => {
      const out = createAssistantMessageEventStream();
      run(out, simple, model, context, requestOptions)
        .catch((error: unknown) => out.push(errorEvent(model, error instanceof Error ? error.message : String(error))))
        .finally(() => out.end());

      return out;
    };
  }

  return {
    ...base,
    stream: stream(false) as Provider['stream'],
    streamSimple: stream(true),
  };
}
