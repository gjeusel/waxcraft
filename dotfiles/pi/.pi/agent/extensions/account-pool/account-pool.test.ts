import assert from 'node:assert/strict';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import {
  createAssistantMessageEventStream,
  type Api,
  type AssistantMessage,
  type Message,
  type Model,
  type Provider,
  type SimpleStreamOptions,
  type TranscriptContext,
} from '@earendil-works/pi-ai';
import { normalizeContext } from '@earendil-works/pi-ai/utils/transcript';
import {
  accountOf,
  chooseAccount,
  claudeObservation,
  classifyFailure,
  codexEventObservation,
  codexHeaderObservation,
  forAccount,
  parseConfig,
  stateKey,
  StateStore,
  usage,
  wrapProvider,
  type Account,
  type PoolId,
  type PoolState,
} from './pool.ts';
import { accountLines, bar, footerStatus, shownWindows } from './index.ts';

const NOW = 1_800_000_000_000;
const accounts: Account[] = [{ id: 'main' }, { id: 'work', configDir: '~/.claude-work' }, { id: 'spare' }];

const usageZero = {
  input: 0,
  output: 0,
  cacheRead: 0,
  cacheWrite: 0,
  totalTokens: 0,
  cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
};

function assistant(pool: PoolId, account: string | undefined, extra: Partial<AssistantMessage> = {}): AssistantMessage {
  return {
    role: 'assistant',
    content: [
      { type: 'thinking', thinking: 'hmm', thinkingSignature: 'sig' },
      { type: 'text', text: 'hello', textSignature: 'tsig' },
      { type: 'toolCall', id: 'call', name: 'read', arguments: {}, thoughtSignature: 'tc' },
    ],
    api: 'test',
    provider: pool,
    model: 'm',
    usage: usageZero,
    stopReason: 'stop',
    timestamp: 0,
    diagnostics: account ? [{ type: 'account-pool', timestamp: 0, details: { pool, account } }] : [],
    ...extra,
  };
}

function user(text: string): Message {
  return { role: 'user', content: text, timestamp: 0 };
}

function store(): StateStore {
  return new StateStore(join(mkdtempSync(join(tmpdir(), 'account-pool-')), 'state'));
}

test('parseConfig validates pools and accounts', () => {
  const config = parseConfig(JSON.stringify({
    pools: { 'claude-code': [{ id: 'main' }, { id: 'work', configDir: '~/.claude-work' }], 'openai-codex': [{ id: 'a' }] },
  }));

  assert.equal(config.threshold, 0.9);
  assert.deepEqual(config.pools['claude-code'], [{ id: 'main' }, { id: 'work', configDir: '~/.claude-work' }]);
  assert.throws(() => parseConfig('{"pools":{"anthropic":[]}}'), /unknown pool/);
  assert.throws(() => parseConfig('{"pools":{"openai-codex":[{"id":"a","configDir":"x"}]}}'), /claude-code accounts only/);
  assert.throws(() => parseConfig('{"pools":{"claude-code":[{"id":"a"},{"id":"a"}]}}'), /duplicate/);
  assert.throws(() => parseConfig('{"threshold":1.5}'), /threshold/);
});

test('chooseAccount keeps the session account until a user turn finds it over the threshold', () => {
  const states: PoolState = {
    [stateKey('claude-code', 'main')]: { windows: { five_hour: { used: 0.95, resetsAt: NOW + 3_600_000 } } },
  };
  const options = { threshold: 0.9, now: NOW };

  assert.equal(chooseAccount(accounts, states, 'claude-code', { ...options, current: 'main', userTurn: false })?.id, 'main');
  assert.equal(chooseAccount(accounts, states, 'claude-code', { ...options, current: 'main', userTurn: true })?.id, 'work');
  assert.equal(chooseAccount(accounts, states, 'claude-code', { ...options, current: 'spare', userTurn: true })?.id, 'spare');
  assert.equal(chooseAccount(accounts, states, 'claude-code', { ...options, userTurn: true })?.id, 'work');
});

test('chooseAccount ignores reset windows, honors warnings and blocks', () => {
  const states: PoolState = {
    [stateKey('claude-code', 'main')]: { windows: { five_hour: { used: 0.99, resetsAt: NOW - 1 } } },
    [stateKey('claude-code', 'work')]: { windows: { seven_day: { used: 0.2, warning: true } } },
    [stateKey('claude-code', 'spare')]: { windows: {}, blockedUntil: NOW + 1000 },
  };

  assert.equal(chooseAccount(accounts, states, 'claude-code', { current: 'work', userTurn: true, threshold: 0.9, now: NOW })?.id, 'main');

  const full: PoolState = {
    [stateKey('claude-code', 'main')]: { windows: { a: { used: 0.97 } } },
    [stateKey('claude-code', 'work')]: { windows: { a: { used: 0.93 } } },
    [stateKey('claude-code', 'spare')]: { windows: {}, blockedUntil: NOW + 1000 },
  };

  // Everything over the threshold: stay, or take the least used account.
  assert.equal(chooseAccount(accounts, full, 'claude-code', { current: 'main', userTurn: true, threshold: 0.9, now: NOW })?.id, 'main');
  assert.equal(chooseAccount(accounts, full, 'claude-code', { userTurn: true, threshold: 0.9, now: NOW })?.id, 'work');
  assert.equal(
    chooseAccount(accounts, full, 'claude-code', { userTurn: true, threshold: 0.9, now: NOW, exclude: new Set(['main', 'work']) }),
    undefined,
  );
});

test('classifyFailure recognizes quota and auth errors with their reset', () => {
  assert.deepEqual(classifyFailure('claude-code', 'Claude AI usage limit reached|1800003600', undefined, NOW), {
    reason: 'quota',
    until: 1_800_003_600_000,
  });
  assert.deepEqual(classifyFailure('openai-codex', 'You have hit your ChatGPT usage limit (plus plan). Try again in ~42 min.', undefined, NOW), {
    reason: 'quota',
    until: NOW + 42 * 60_000,
  });
  assert.equal(classifyFailure('claude-code', 'Claude Code is not logged in. Run claude auth login', undefined, NOW)?.reason, 'auth');
  assert.equal(classifyFailure('claude-code', 'Claude Code upstream server error (status 529)', undefined, NOW), undefined);

  const state = { windows: { five_hour: { used: 1, resetsAt: NOW + 7_200_000 } } };
  assert.equal(classifyFailure('claude-code', "You've hit your limit", state, NOW)?.until, NOW + 7_200_000);
});

test('claudeObservation reads the unified windows of the rate-limit diagnostic', () => {
  const message = assistant('claude-code', 'main', {
    diagnostics: [{
      type: 'claude-code.rate-limit',
      timestamp: 0,
      details: {
        status: 'allowed',
        resetsAt: 1_800_003_600,
        rateLimitType: 'five_hour',
        isUsingOverage: false,
        unifiedWindows: {
          five_hour: { utilization: 0.79, resetsAt: 1_800_003_600, status: 'allowed' },
          seven_day: { utilization: 0.16, resetsAt: 1_800_500_000, status: 'allowed_warning' },
        },
      },
    }],
  });

  assert.deepEqual(claudeObservation(message), {
    windows: {
      five_hour: { used: 0.79, resetsAt: 1_800_003_600_000 },
      seven_day: { used: 0.16, resetsAt: 1_800_500_000_000, warning: true },
    },
    blockedUntil: undefined,
  });
});

test('Codex usage comes from headers or the WebSocket rate-limit event', () => {
  assert.deepEqual(codexHeaderObservation({
    'x-codex-primary-used-percent': '42.5',
    'x-codex-primary-reset-at': '1800003600',
    'x-codex-secondary-used-percent': '10',
    'x-codex-secondary-reset-after-seconds': '60',
  }, NOW), {
    windows: {
      primary: { used: 0.425, resetsAt: 1_800_003_600_000 },
      secondary: { used: 0.1, resetsAt: NOW + 60_000 },
    },
  });
  assert.equal(codexHeaderObservation({ 'content-type': 'text/event-stream' }, NOW), undefined);

  assert.deepEqual(codexEventObservation({
    type: 'codex.rate_limits',
    rate_limits: { limit_reached: true, primary: { used_percent: 100, window_minutes: 300, reset_at: 1_800_003_600 } },
  }), { windows: { primary: { used: 1, resetsAt: 1_800_003_600_000, minutes: 300 } }, blockedUntil: 1_800_003_600_000 });
  assert.equal(codexEventObservation({ type: 'response.created' }), undefined);
});

test('forAccount strips what only another account can replay', () => {
  const messages = [user('hi'), assistant('claude-code', undefined), assistant('claude-code', 'work'), assistant('openai-codex', 'x')];
  const [, fromMain, fromWork, other] = forAccount(messages, 'claude-code', 'work', 'main') as AssistantMessage[];

  assert.deepEqual(fromMain.content, [{ type: 'text', text: 'hello' }, { type: 'toolCall', id: 'call', name: 'read', arguments: {} }]);
  assert.equal(fromWork, messages[2]);
  assert.equal(other, messages[3]);
});

interface Call {
  options?: SimpleStreamOptions;
  context: TranscriptContext;
}

function fakeProvider(script: (call: Call, index: number) => AssistantMessage, delta = false): { provider: Provider; calls: Call[] } {
  const calls: Call[] = [];
  const streamSimple = (model: Model<Api>, context: TranscriptContext, options?: SimpleStreamOptions) => {
    const call = { options, context };
    calls.push(call);
    const message = script(call, calls.length - 1);
    const out = createAssistantMessageEventStream();
    queueMicrotask(() => {
      out.push({ type: 'start', partial: { ...message, content: [] } });
      if (delta) out.push({ type: 'text_start', contentIndex: 0, partial: message });
      out.push(message.stopReason === 'error'
        ? { type: 'error', reason: 'error', error: message }
        : { type: 'done', reason: 'stop', message });
      out.end();
    });

    return out;
  };

  return {
    calls,
    provider: {
      id: 'claude-code',
      name: 'fake',
      auth: { apiKey: { name: 'fake', resolve: async () => ({ auth: {} }) } },
      getModels: () => [],
      stream: streamSimple as Provider['stream'],
      streamSimple,
    },
  };
}

const model = { id: 'm', provider: 'claude-code', api: 'test' } as unknown as Model<Api>;

function wrap(provider: Provider, states = store()) {
  return {
    states,
    pooled: wrapProvider(provider, {
      pool: 'claude-code',
      accounts,
      threshold: 0.9,
      store: states,
      now: () => NOW,
      async credentials(account) {
        return account.configDir ? { env: { PI_CLAUDE_CODE_CONFIG_DIR: account.configDir } } : {};
      },
    }),
  };
}

function ok(): AssistantMessage {
  return { ...assistant('claude-code', undefined), diagnostics: [] };
}

function failed(errorMessage: string): AssistantMessage {
  return { ...ok(), content: [], stopReason: 'error', errorMessage };
}

test('a quota failure before any output moves the request to the next account', async () => {
  const { provider, calls } = fakeProvider((_call, index) => (index === 0 ? failed('Claude AI usage limit reached|1800003600') : ok()));
  const { pooled, states } = wrap(provider);

  const result = await pooled.streamSimple(model, normalizeContext({ messages: [user('hi')] })).result();

  assert.equal(result.stopReason, 'stop');
  assert.equal(accountOf(result), 'work');
  assert.equal(calls.length, 2);
  assert.equal(calls[0].options?.env?.PI_CLAUDE_CODE_CONFIG_DIR, undefined);
  assert.equal(calls[1].options?.env?.PI_CLAUDE_CODE_CONFIG_DIR, '~/.claude-work');
  assert.equal(states.read()[stateKey('claude-code', 'main')]?.blockedUntil, 1_800_003_600_000);
});

test('a failure after streamed output is reported, not replayed', async () => {
  const { provider, calls } = fakeProvider(() => failed("You've hit your limit"), true);
  const { pooled } = wrap(provider);

  const result = await pooled.streamSimple(model, normalizeContext({ messages: [user('hi')] })).result();

  assert.equal(result.stopReason, 'error');
  assert.equal(calls.length, 1);
});

test('other errors are passed through on the same account', async () => {
  const { provider, calls } = fakeProvider(() => failed('Claude Code upstream server error'));
  const { pooled } = wrap(provider);

  const result = await pooled.streamSimple(model, normalizeContext({ messages: [user('hi')] })).result();

  assert.equal(result.errorMessage, 'Claude Code upstream server error');
  assert.equal(accountOf(result), 'main');
  assert.equal(calls.length, 1);
});

test('the session account sticks, and moves at a user turn once over the threshold', async () => {
  const { provider, calls } = fakeProvider((call) => {
    const message = ok();
    message.diagnostics = [{
      type: 'claude-code.rate-limit',
      timestamp: 0,
      details: { status: 'allowed', unifiedWindows: { five_hour: { utilization: call.options?.env?.PI_CLAUDE_CODE_CONFIG_DIR ? 0.1 : 0.95 } } },
    }];

    return message;
  });
  const { pooled } = wrap(provider);

  const first = await pooled.streamSimple(model, normalizeContext({ messages: [user('hi')] })).result();
  assert.equal(accountOf(first), 'main');

  // A tool continuation stays on main even though main is now over the threshold.
  const toolResult: Message = { role: 'toolResult', toolCallId: 'call', toolName: 'read', content: [], isError: false, timestamp: 0 };
  const second = await pooled.streamSimple(model, normalizeContext({ messages: [user('hi'), first, toolResult] })).result();
  assert.equal(accountOf(second), 'main');

  const third = await pooled.streamSimple(model, normalizeContext({ messages: [user('hi'), first, toolResult, second, user('next')] })).result();
  assert.equal(accountOf(third), 'work');

  // The new account does not receive main's signed thinking.
  assert.ok(calls[2].context.messages.every((message) => message.role !== 'assistant' || message.content.every((block) => block.type !== 'thinking')));
});

test('a plain 429 rate limit also moves to the next account, briefly', async () => {
  const { provider, calls } = fakeProvider((_call, index) => (index === 0 ? failed('429 Too Many Requests: rate_limit_error') : ok()));
  const { pooled, states } = wrap(provider);

  const result = await pooled.streamSimple(model, normalizeContext({ messages: [user('hi')] })).result();

  assert.equal(accountOf(result), 'work');
  assert.equal(calls.length, 2);
  assert.equal(states.read()[stateKey('claude-code', 'main')]?.blockReason, 'rate-limit');
  assert.equal(states.read()[stateKey('claude-code', 'main')]?.blockedUntil, NOW + 60_000);
});

test('each account has its own state file', () => {
  const states = store();
  states.update(stateKey('claude-code', 'main'), (state) => ({ ...state, windows: { a: { used: 0.5 } } }));
  states.update(stateKey('openai-codex', 'perso'), (state) => ({ ...state, blockedUntil: 1, blockReason: 'auth' }));

  assert.deepEqual(Object.keys(states.read()).sort(), ['claude-code/main', 'openai-codex/perso']);
  assert.equal(states.read()['claude-code/main']?.windows.a?.used, 0.5);
});

test('the display shows what the provider reported, a warning as a mark and not as usage', () => {
  const state = {
    windows: {
      five_hour: { used: 0.17, resetsAt: NOW + 3 * 3_600_000 },
      seven_day: { used: 0.85, resetsAt: NOW + 3 * 86_400_000, warning: true },
      seven_day_overage_included: { used: 0.88, resetsAt: NOW + 3 * 86_400_000 },
      primary: { used: 0.5, resetsAt: NOW - 1 },
    },
    updatedAt: NOW,
  };

  assert.equal(usage(state, 0.95, NOW), 0.95);
  // Merged, the two weekly windows show as one: the most used, with the warning of either.
  assert.deepEqual(shownWindows(state, NOW, { merge: true }).map(({ label, used, warning }) => ({ label, used, warning })), [
    { label: '5h', used: 0.17, warning: undefined },
    { label: '7d', used: 0.88, warning: true },
  ]);
  assert.equal(footerStatus('main', state, NOW), 'main · 5h ▂ · 7d ▇');
  assert.equal(footerStatus('main', undefined, NOW), 'main');
  assert.deepEqual(accountLines({ id: 'main', source: '~/.claude', inSession: true }, state, NOW), [
    '● main  ~/.claude',
    '  5h     ███▍░░░░░░░░░░░░░░░░  17%   resets in 3h',
    '  7d     █████████████████░░░  85% ! resets in 3d',
    '  fable  █████████████████▋░░  88%   resets in 3d',
  ]);
});

test('bars fill by eighths of a cell, and Codex windows are labelled by their length', () => {
  assert.equal(bar(0), '░'.repeat(20));
  assert.equal(bar(0.01), '▎' + '░'.repeat(19));
  assert.equal(bar(1.2), '█'.repeat(20));

  const state = {
    windows: { primary: { used: 0.14, minutes: 10_080 }, secondary: { used: 0 } },
    updatedAt: NOW - 3 * 86_400_000,
    blockedUntil: NOW + 600_000,
    blockReason: 'quota',
  };
  assert.deepEqual(accountLines({ id: 'perso', source: 'openai-codex-perso', inSession: false }, state, NOW), [
    '  perso  openai-codex-perso · blocked (quota) for 10m · reported 3d ago',
    '  7d   ██▊░░░░░░░░░░░░░░░░░  14%',
    '  2nd  ░░░░░░░░░░░░░░░░░░░░   0%',
  ]);
  assert.deepEqual(accountLines({ id: 'new', source: 'default login', inSession: false }, undefined, NOW), [
    '  new  default login',
    '  no usage reported yet',
  ]);
});
