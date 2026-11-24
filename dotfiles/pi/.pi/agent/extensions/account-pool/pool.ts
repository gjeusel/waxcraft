/**
 * Account pools: several subscription logins behind one provider id.
 *
 * The pooled provider keeps the id and models of the provider it wraps, so model selection and
 * every extension keyed on the provider id keep working. Each request runs on one account of the
 * pool: at a user turn, the first enabled account in the configured order (those listing the
 * request's model as a priority first) whose usage of the windows that count for that model is
 * below the threshold; between a tool call and its result, the account of the session's latest
 * response unless it is blocked for the model. A pinned account overrides the order. Limits are
 * per model: a model out of its own allowance, or rate limited, is blocked on that account while
 * the account keeps serving the other models. Usage comes from what each provider reports on its
 * responses and is shared by every Pi process through a small state file.
 */
import { mkdirSync, readdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { parse, printParseErrorCode, type ParseError } from 'jsonc-parser';
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
  /** Left out of every choice, while keeping its place and its login. */
  disabled?: boolean;
  /** Model ids, with `*` as a wildcard, whose requests take this account before the others. */
  priorityModels?: string[];
  /** Usage fraction (0-1) of the session window that replaces the pool threshold for it. */
  sessionThreshold?: number;
}

export interface PoolConfig {
  /** Usage fraction (0-1) from which an account is passed over at a user turn. */
  threshold: number;
  /**
   * Accounts by pooled provider, in merit order: each user turn runs on the first one with room.
   * The first one is also the default login.
   */
  pools: Partial<Record<PoolId, Account[]>>;
}

export interface UsageWindow {
  /** Used fraction of the window, 0-1. */
  used: number;
  /** Epoch milliseconds at which the window resets. */
  resetsAt?: number;
  /** The provider warned that the window is nearly used up. */
  warning?: boolean;
  /** Length of the window in minutes, when the provider reports it. */
  minutes?: number;
}

export interface Block {
  until: number;
  reason: string;
}

export interface AccountState {
  windows: Record<string, UsageWindow>;
  /** Block of the whole account: its login failed. */
  blockedUntil?: number;
  blockReason?: string;
  /** Blocks of single models, by model id: out of their allowance or rate limited. */
  modelBlocks?: Record<string, Block>;
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

/**
 * Parse the pool configuration, JSON with comments and trailing commas. Throws with a readable
 * message when it is invalid.
 */
export function parseConfig(text: string): PoolConfig {
  const errors: ParseError[] = [];
  const raw: unknown = parse(text, errors, { allowTrailingComma: true });
  if (errors.length > 0) {
    const { error, offset } = errors[0];
    const line = text.slice(0, offset).split('\n').length;

    throw new Error(`${printParseErrorCode(error)} at line ${line}`);
  }
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
      const { id, configDir, disabled, priorityModels, sessionThreshold } = (account ?? {}) as Record<string, unknown>;
      if (typeof id !== 'string' || !ACCOUNT_ID.test(id)) {
        throw new Error(`"pools.${pool}": each account needs an "id" made of letters, digits, "-" or "_"`);
      }
      if (seen.has(id)) throw new Error(`"pools.${pool}": duplicate account "${id}"`);
      seen.add(id);

      if (configDir !== undefined && (pool !== 'claude-code' || typeof configDir !== 'string')) {
        throw new Error(`"pools.${pool}.${id}": "configDir" is a string, for claude-code accounts only`);
      }

      if (disabled !== undefined && typeof disabled !== 'boolean') {
        throw new Error(`"pools.${pool}.${id}": "disabled" must be true or false`);
      }

      const isModelList = Array.isArray(priorityModels) && priorityModels.every((model) => typeof model === 'string' && model !== '');
      if (priorityModels !== undefined && !isModelList) {
        throw new Error(`"pools.${pool}.${id}": "priorityModels" must be an array of model ids`);
      }

      const isFraction = typeof sessionThreshold === 'number' && sessionThreshold > 0 && sessionThreshold <= 1;
      if (sessionThreshold !== undefined && !isFraction) {
        throw new Error(`"pools.${pool}.${id}": "sessionThreshold" must be a number in (0, 1]`);
      }

      return {
        id,
        ...(configDir === undefined ? {} : { configDir }),
        ...(disabled ? { disabled } : {}),
        ...(priorityModels === undefined ? {} : { priorityModels: priorityModels as string[] }),
        ...(sessionThreshold === undefined ? {} : { sessionThreshold: sessionThreshold as number }),
      };
    });

    if (accounts.length > 0 && config.pools[pool]?.every((account) => account.disabled)) {
      throw new Error(`"pools.${pool}": every account is disabled`);
    }
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

/** Whether the model id `modelId` matches `pattern`, a model id with `*` as a wildcard. */
export function matchesModel(pattern: string, modelId: string): boolean {
  const escaped = pattern.split('*').map((part) => part.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));

  return new RegExp(`^${escaped.join('.*')}$`, 'i').test(modelId);
}

/**
 * Windows that count for some models only: Claude Code reports each weekly per-model limit on the
 * responses of its models alone (`seven_day_overage_included` is the Fable limit). Every other
 * window counts for all the models of the account.
 */
const MODEL_WINDOWS: Record<string, string> = {
  seven_day_overage_included: 'claude-fable-*',
  seven_day_opus: 'claude-opus-*',
  seven_day_sonnet: 'claude-sonnet-*',
};

/**
 * The windows that have not reset yet, with the used fraction each provider reported. With
 * `modelId`, only those that count for that model.
 */
export function activeWindows(
  state: AccountState | undefined,
  now: number,
  modelId?: string,
): [name: string, window: UsageWindow][] {
  return Object.entries(state?.windows ?? {}).filter(([name, window]) => {
    const isActive = window.resetsAt === undefined || window.resetsAt > now;
    const counts = modelId === undefined || MODEL_WINDOWS[name] === undefined || matchesModel(MODEL_WINDOWS[name], modelId);

    return isActive && counts;
  });
}

/**
 * Highest used fraction across the windows of `modelId` that have not reset yet, for the switching
 * decision only. A provider warning does not count: Claude Code warns from 75% of a window on,
 * far below any useful threshold, and reports the exact utilization alongside.
 */
export function usage(state: AccountState | undefined, now: number, modelId: string): number {
  return Math.max(0, ...activeWindows(state, now, modelId).map(([, window]) => window.used));
}

/** The short window of each provider, which Claude names the current session: five hours. */
const SESSION_WINDOWS = new Set(['five_hour', 'primary']);

/**
 * Whether `account` may take a user turn of `modelId`: each of its windows that count for the
 * model is below `threshold`, and its session window below its own `sessionThreshold` if any.
 */
export function hasRoom(
  account: Account,
  state: AccountState | undefined,
  now: number,
  modelId: string,
  threshold: number,
): boolean {
  return activeWindows(state, now, modelId).every(([name, window]) => {
    const limit = SESSION_WINDOWS.has(name) ? (account.sessionThreshold ?? threshold) : threshold;

    return window.used < limit;
  });
}

/** End of the block of the account for `modelId`: its own, or that of the whole account. */
export function blockEnd(state: AccountState | undefined, modelId?: string): number {
  const modelBlock = modelId === undefined ? undefined : state?.modelBlocks?.[modelId];

  return Math.max(state?.blockedUntil ?? 0, modelBlock?.until ?? 0);
}

/** Whether the account is blocked: as a whole, or for `modelId` when given. */
export function isBlocked(state: AccountState | undefined, now: number, modelId?: string): boolean {
  return blockEnd(state, modelId) > now;
}

/**
 * When `modelId` is out of quota on every account: the soonest reset. Undefined while one account
 * may still serve it, even blocked by a mere rate limit, which clears within a minute.
 */
export function quotaExhaustedUntil(
  accounts: readonly Account[],
  states: PoolState,
  pool: PoolId,
  modelId: string,
  now: number,
): number | undefined {
  const ends = accounts.map((account) => {
    const block = states[stateKey(pool, account)]?.modelBlocks?.[modelId];

    return block?.reason === 'quota' && block.until > now ? block.until : undefined;
  });
  if (ends.length === 0 || ends.some((end) => end === undefined)) return undefined;

  return Math.min(...(ends as number[]));
}

/** Whether `account` is listed as a priority for the model `modelId`. */
export function hasPriority(account: Account, modelId: string): boolean {
  return (account.priorityModels ?? []).some((pattern) => matchesModel(pattern, modelId));
}

/**
 * The accounts a request of `modelId` may run on, in order of use: the enabled accounts, those
 * with the model among their `priorityModels` first, each group in its configured order.
 */
export function meritOrder(accounts: readonly Account[], modelId: string): Account[] {
  const enabled = accounts.filter((account) => !account.disabled);

  return [
    ...enabled.filter((account) => hasPriority(account, modelId)),
    ...enabled.filter((account) => !hasPriority(account, modelId)),
  ];
}

/**
 * The account for one request. The pinned account wins whatever its usage. Otherwise the current
 * account stays between user turns, which keeps a tool call and its result on one account; at a
 * user turn the first account with room wins, in the order of `accounts`, so a session returns to
 * a preferred account once its window resets. With no room anywhere the current account stays,
 * then the least used one. Usage and blocks are those of the request's model. Blocked and excluded
 * accounts are never chosen: undefined when no other is left.
 */
export function chooseAccount(
  accounts: readonly Account[],
  states: PoolState,
  pool: PoolId,
  options: {
    model: string;
    current?: string;
    pinned?: string;
    userTurn: boolean;
    threshold: number;
    now: number;
    exclude?: ReadonlySet<string>;
  },
): Account | undefined {
  const { model, current: currentId, pinned: pinnedId, userTurn, threshold, now, exclude } = options;
  const stateOf = (account: Account) => states[stateKey(pool, account)];
  const usageOf = (account: Account) => usage(stateOf(account), now, model);
  const usable = accounts.filter((account) => !exclude?.has(account.id) && !isBlocked(stateOf(account), now, model));
  const roomy = usable.filter((account) => hasRoom(account, stateOf(account), now, model, threshold));
  const current = usable.find((account) => account.id === currentId);
  const pinned = usable.find((account) => account.id === pinnedId);

  if (pinned) return pinned;
  if (current && !userTurn) return current;
  if (roomy.length > 0) return roomy[0];
  if (current) return current;

  return usable.reduce<Account | undefined>((best, account) => (!best || usageOf(account) < usageOf(best) ? account : best), undefined);
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
  modelId: string,
): Failure | undefined {
  const patterns = FAILURE_PATTERNS[pool];
  if (patterns.auth.test(errorMessage)) return { reason: 'auth', until: now + AUTH_BLOCK_MS };

  const isQuota = patterns.quota.test(errorMessage);
  if (!isQuota && !patterns.rateLimit.test(errorMessage)) return undefined;

  // Without a reset in the message, a nearly full window of the model tells when its quota returns.
  // Claude Code words a request over a weekly limit as a plain rate limit: such a window makes it a
  // quota failure too, instead of a block of a minute that the next retries run into.
  const fullWindows = activeWindows(state, now, modelId)
    .filter(([, window]) => window.used >= 0.95 && window.resetsAt !== undefined)
    .map(([, window]) => window.resetsAt as number);
  const fullUntil = fullWindows.length > 0 ? Math.max(...fullWindows) : undefined;
  const hint = resetHint(errorMessage, now);
  if (!isQuota && fullUntil === undefined) return { reason: 'rate-limit', until: hint ?? now + RATE_LIMIT_BLOCK_MS };

  return { reason: 'quota', until: hint ?? fullUntil ?? now + QUOTA_BLOCK_MS };
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
    const used = typeof details.utilization === 'number' ? details.utilization : typeof details.surpassedThreshold === 'number' ? details.surpassedThreshold : 0;
    windows[type] = { used, resetsAt: epochMs(details.resetsAt), warning: true };
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
    const minutes = Number(headers[`x-codex-${name}-window-minutes`]);
    windows[name] = {
      used: used / 100,
      resetsAt: resetAt ?? (Number.isFinite(resetAfter) ? now + resetAfter * 1000 : undefined),
      ...(minutes > 0 ? { minutes } : {}),
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

    windows[name] = {
      used: window.used_percent / 100,
      resetsAt: epochMs(window.reset_at),
      ...(typeof window.window_minutes === 'number' && window.window_minutes > 0 ? { minutes: window.window_minutes } : {}),
    };
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
  /** The account the user pinned, which every request uses while it is not blocked. */
  pinned?: () => string | undefined;
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

  // A response proves the login, and the room of its model unless the provider says it is used up.
  function observe(account: Account, modelId: string, observation: Observation | undefined): void {
    if (!observation) return;

    store.update(stateKey(pool, account), (state) => {
      const { [modelId]: _previous, ...modelBlocks } = state.modelBlocks ?? {};
      if (observation.blockedUntil) modelBlocks[modelId] = { until: observation.blockedUntil, reason: 'quota' };

      return {
        ...state,
        windows: { ...state.windows, ...observation.windows },
        blockedUntil: undefined,
        blockReason: undefined,
        modelBlocks,
      };
    });
  }

  // A failed login blocks the account; a quota or a rate limit, only the model it was reached on.
  function block(account: Account, modelId: string, failure: Failure): void {
    store.update(stateKey(pool, account), (state) =>
      failure.reason === 'auth'
        ? { ...state, blockedUntil: failure.until, blockReason: failure.reason }
        : { ...state, modelBlocks: { ...state.modelBlocks, [modelId]: { until: failure.until, reason: failure.reason } } },
    );
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
    // `accounts` keeps the disabled ones: the first is the default login whatever its state.
    const candidates = meritOrder(accounts, model.id);
    const pick = () =>
      chooseAccount(candidates, store.read(), pool, {
        model: model.id,
        current,
        pinned: options.pinned?.(),
        userTurn,
        threshold,
        now: now(),
        exclude,
      });
    // When every account left is blocked, the one that unblocks first still gets the request: its
    // error is more useful than a pool error, and a block can be stale.
    const soonestUnblocked = () => {
      const states = store.read();
      const until = (account: Account) => blockEnd(states[stateKey(pool, account)], model.id);

      return candidates
        .filter((account) => !exclude.has(account.id))
        .reduce<Account | undefined>((soonest, account) => (!soonest || until(account) < until(soonest) ? account : soonest), undefined);
    };

    // A model out of quota on every account fails at once, worded so that Pi does not retry it
    // ("quota exceeded"): retrying only hits the same limit, until the window resets hours later.
    const exhaustedError = () => {
      const until = quotaExhaustedUntil(candidates, store.read(), pool, model.id, now());

      return until === undefined
        ? undefined
        : `account-pool: ${model.id} quota exceeded on every enabled ${pool} account until ` +
            `${new Date(until).toLocaleString()}; switch model, or enable another account in account-pool.jsonc`;
    };

    const initial = pick();
    const exhausted = initial ? undefined : exhaustedError();
    if (exhausted) {
      out.push(errorEvent(model, exhausted));
      return;
    }

    let account = (initial ?? soonestUnblocked()) as Account;

    for (;;) {
      exclude.add(account.id);

      let overrides: Partial<SimpleStreamOptions>;
      try {
        overrides = await options.credentials(account);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        block(account, model.id, { reason: 'auth', until: now() + AUTH_BLOCK_MS });
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
          if (pool === 'openai-codex') observe(attempt, model.id, codexHeaderObservation(response.headers, now()));
          await requestOptions?.onResponse?.(response, responseModel);
        },
        onProviderStreamEvent: async (data: unknown, eventModel: Model<Api>) => {
          if (pool === 'openai-codex') observe(attempt, model.id, codexEventObservation(data));
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

        if (event.type === 'done' && pool === 'claude-code') observe(attempt, model.id, claudeObservation(event.message));
        if (event.type === 'error' && event.reason !== 'aborted') {
          const state = store.read()[stateKey(pool, attempt)];
          const failure = classifyFailure(pool, event.error.errorMessage ?? '', state, now(), model.id);
          if (failure) block(attempt, model.id, failure);
          // Output already shown cannot be taken back, so only a silent failure is replayed.
          retryWith = failure && !streamed ? pick() : undefined;
          if (retryWith) break;

          const exhausted = failure && !streamed ? exhaustedError() : undefined;
          if (exhausted) event.error.errorMessage = exhausted;
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
