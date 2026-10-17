import assert from 'node:assert/strict';
import { existsSync, mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import {
  SessionManager, type CustomEntry, type ExtensionAPI, type ExtensionCommandContext, type ExtensionContext,
} from '@earendil-works/pi-coding-agent';
import { matchesKey, visibleWidth } from '@earendil-works/pi-tui';
import {
  isAnthropicFastModel, isOfficialCodexModel, isOfficialOpenAIModel, registerFastMode,
  rewriteFastPayload, SPEED_ENTRY_TYPE,
} from './fast.ts';

const codexModel: NonNullable<ExtensionContext['model']> = {
  id: 'gpt-6.1-sol',
  name: 'GPT 6.1 Sol',
  provider: 'openai-codex',
  api: 'openai-codex-responses',
  baseUrl: 'https://chatgpt.com/backend-api',
  reasoning: true,
  input: ['text', 'image'],
  cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
  contextWindow: 1_000_000,
  maxTokens: 128_000,
};

const anthropicModel: NonNullable<ExtensionContext['model']> = {
  ...codexModel,
  id: 'claude-opus-5-5',
  name: 'Claude Opus 5.5',
  provider: 'anthropic',
  api: 'anthropic-messages',
  baseUrl: 'https://api.anthropic.com',
};

function speedEntries(manager: SessionManager): CustomEntry[] {
  return manager.getEntries().filter((entry): entry is CustomEntry =>
    entry.type === 'custom' && entry.customType === SPEED_ENTRY_TYPE);
}

function snapshots(manager: SessionManager): unknown[] {
  return speedEntries(manager).map((entry) => entry.data);
}

function snapshot(openai: 'normal' | 'fast' | 'ultrafast', anthropic: 'normal' | 'fast' = 'normal') {
  return { version: 1, openai, anthropic };
}

async function withSessionDirectory(run: (directory: string) => Promise<void>): Promise<void> {
  const directory = mkdtempSync(join(tmpdir(), 'pi-model-controls-fast-'));
  try {
    await run(directory);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}

function harness(manager = SessionManager.inMemory()) {
  type Handler = (event: unknown, ctx: ExtensionContext) => unknown;
  type Command = { handler: (args: string, ctx: ExtensionCommandContext) => Promise<void> };
  const handlers = new Map<string, Handler>();
  const commands = new Map<string, Command>();
  const shortcuts = new Map<string, Parameters<ExtensionAPI['registerShortcut']>[1]>();
  type UIFactory = Parameters<ExtensionContext['ui']['custom']>[0];
  let picker: Awaited<ReturnType<UIFactory>> | undefined;
  let dialogs = 0;
  const statuses = new Map<string, string | undefined>();
  const notifications: { text: string; level: string }[] = [];
  const ctx = {
    model: codexModel,
    sessionManager: manager,
    mode: 'tui',
    ui: {
      custom: (factory: UIFactory) => new Promise((done) => {
        dialogs++;
        const palette: Record<string, number> = { muted: 90, dim: 90, success: 32, warning: 33, accent: 36 };
        picker = factory(
          { requestRender() {} } as Parameters<UIFactory>[0],
          {
            bold: (text: string) => `\x1b[1m${text}\x1b[22m`,
            fg: (color: string, text: string) => `\x1b[${palette[color]}m${text}\x1b[39m`,
          } as Parameters<UIFactory>[1],
          {} as Parameters<UIFactory>[2],
          done,
        ) as Awaited<ReturnType<UIFactory>>;
      }),
      setStatus: (key: string, text: string | undefined) => statuses.set(key, text),
      notify: (text: string, level: string) => notifications.push({ text, level }),
    },
  } as unknown as ExtensionCommandContext;
  const pi = {
    on: (event: string, handler: Handler) => handlers.set(event, handler),
    appendEntry: (customType: string, data: unknown) =>
      (ctx.sessionManager as SessionManager).appendCustomEntry(customType, data),
    registerCommand: (name: string, command: Command) => commands.set(name, command),
    registerShortcut: (key: string, options: Parameters<ExtensionAPI['registerShortcut']>[1]) =>
      shortcuts.set(key, options),
  } as unknown as ExtensionAPI;

  registerFastMode(pi);

  return {
    ctx,
    statuses,
    notifications,
    manager,
    emit: (event: string, payload: unknown = {}) => handlers.get(event)?.(payload, ctx),
    fast: (args = '') => commands.get('fast')!.handler(args, ctx),
    ultrafast: (args = '') => commands.get('ultrafast')!.handler(args, ctx),
    switchModel: (model: NonNullable<ExtensionContext['model']>) => {
      const previousModel = ctx.model;
      ctx.model = model;
      return handlers.get('model_select')?.({ previousModel, model, source: 'set' }, ctx);
    },
    shortcuts,
    selectSpeed: () => shortcuts.get('ctrl+shift+;')!.handler(ctx),
    renderPicker: (width = 100) => picker!.render(width),
    inputPicker: (data: string) => picker!.handleInput?.(data),
    get dialogs() { return dialogs; },
  };
}

test('Ctrl+Shift+semicolon opens a colored, bounded picker and persists its selection', async () => {
  const runtime = harness();
  runtime.emit('session_start');
  assert.deepEqual([...runtime.shortcuts.keys()], ['ctrl+shift+;']);
  assert.equal(matchesKey('\x1b[59;6u', 'ctrl+shift+;'), true);
  assert.equal(matchesKey('\x1b[59:58;6u', 'ctrl+shift+;'), true);
  const selection = runtime.selectSpeed();
  const rendered = runtime.renderPicker().join('\n');
  assert.match(rendered, /\x1b\[90mNormal \(current\)/u);
  assert.match(rendered, /\x1b\[32mFast/u);
  assert.match(rendered, /\x1b\[33mUltrafast/u);
  for (const width of [1, 10, 40, 80]) {
    assert.ok(runtime.renderPicker(width).every((line) => visibleWidth(line) <= width));
  }
  runtime.inputPicker('\x1b[B');
  runtime.inputPicker('\r');
  await selection;
  assert.deepEqual(snapshots(runtime.manager), [snapshot('fast')]);
  assert.equal(runtime.statuses.get('pi-model-controls'), 'fast');
  assert.deepEqual(runtime.emit('before_provider_request', { payload: {} }), { service_tier: 'priority' });
});

test('picker initializes to current speed, selects every mode, and leaves cancellation unchanged', async () => {
  const runtime = harness();
  runtime.emit('session_start');
  await runtime.fast('on');
  let selection = runtime.selectSpeed();
  assert.match(runtime.renderPicker().join('\n'), /Fast \(current\)/u);
  runtime.inputPicker('\x1b[B');
  runtime.inputPicker('\r');
  await selection;
  assert.equal(runtime.statuses.get('pi-model-controls'), 'ultrafast');
  assert.deepEqual(snapshots(runtime.manager).at(-1), snapshot('ultrafast'));

  selection = runtime.selectSpeed();
  assert.match(runtime.renderPicker().join('\n'), /Ultrafast \(current\)/u);
  runtime.inputPicker('\r');
  await selection;
  const beforeCancel = runtime.manager.getEntries();
  selection = runtime.selectSpeed();
  runtime.inputPicker('\x1b[B');
  runtime.inputPicker('\x1b');
  await selection;
  assert.deepEqual(runtime.manager.getEntries(), beforeCancel);
  assert.equal(runtime.statuses.get('pi-model-controls'), 'ultrafast');
  assert.deepEqual(runtime.emit('before_provider_request', { payload: {} }), { service_tier: 'ultrafast' });

  selection = runtime.selectSpeed();
  runtime.inputPicker('\x1b[B');
  runtime.inputPicker('\r');
  await selection;
  assert.equal(runtime.statuses.get('pi-model-controls'), undefined);
  assert.deepEqual(snapshots(runtime.manager).at(-1), snapshot('normal'));
});

test('Anthropic picker preserves OpenAI preference and marks Ultrafast unavailable', async () => {
  const runtime = harness();
  runtime.emit('session_start');
  await runtime.ultrafast('on');
  runtime.switchModel(anthropicModel);
  let selection = runtime.selectSpeed();
  assert.match(runtime.renderPicker().join('\n'), /Ultrafast \(unavailable\)/u);
  assert.match(runtime.renderPicker().join('\n'), /Fast \(current\)/u);
  runtime.inputPicker('\r');
  await selection;
  assert.deepEqual(snapshots(runtime.manager).at(-1), snapshot('ultrafast', 'fast'));

  const beforeUnavailable = runtime.manager.getEntries();
  selection = runtime.selectSpeed();
  runtime.inputPicker('\x1b[B');
  runtime.inputPicker('\r');
  await selection;
  assert.equal(runtime.notifications.at(-1)!.level, 'warning');
  assert.deepEqual(runtime.manager.getEntries(), beforeUnavailable);
  assert.equal(runtime.statuses.get('pi-model-controls'), 'fast');
});

test('picker ignores duplicate openings and rejects a stale model', async () => {
  const runtime = harness();
  runtime.emit('session_start');
  const selection = runtime.selectSpeed();
  await runtime.selectSpeed();
  assert.equal(runtime.dialogs, 1);
  runtime.switchModel(anthropicModel);
  runtime.inputPicker('\x1b[B');
  runtime.inputPicker('\r');
  await selection;
  assert.match(runtime.notifications.at(-1)!.text, /Model changed/u);
  assert.deepEqual(snapshots(runtime.manager), []);
  assert.equal(runtime.statuses.get('pi-model-controls'), undefined);
});

for (const boundary of ['session_start', 'session_shutdown'] as const) {
  test(`late picker cannot save after ${boundary}, even with the same context and model`, async () => {
    const runtime = harness();
    runtime.emit('session_start');
    await runtime.fast('on');
    const selection = runtime.selectSpeed();
    const entries = runtime.manager.getEntries();
    runtime.emit(boundary);
    runtime.inputPicker('\x1b[B');
    runtime.inputPicker('\r');
    await selection;
    assert.deepEqual(runtime.manager.getEntries(), entries);
    assert.equal(runtime.statuses.get('pi-model-controls'), 'fast');
    assert.deepEqual(runtime.emit('before_provider_request', { payload: {} }), { service_tier: 'priority' });
  });
}

test('session replacement invalidates a pending picker instead of writing into the new discussion', async () => {
  const runtime = harness();
  runtime.emit('session_start');
  const selection = runtime.selectSpeed();
  const replacement = SessionManager.inMemory();
  runtime.ctx.sessionManager = replacement;
  runtime.emit('session_start');
  runtime.inputPicker('\x1b[B');
  runtime.inputPicker('\r');
  await selection;
  assert.deepEqual(snapshots(runtime.manager), []);
  assert.deepEqual(snapshots(replacement), []);
  assert.equal(runtime.statuses.get('pi-model-controls'), undefined);
});

test('/fast and /ultrafast persist full snapshots and preserve their command semantics', async () => {
  const runtime = harness();
  runtime.emit('session_start');
  assert.equal(SPEED_ENTRY_TYPE, 'pi-speed-mode');
  assert.deepEqual(snapshots(runtime.manager), []);
  assert.deepEqual(runtime.emit('before_provider_request', { payload: {} }), { service_tier: 'default' });

  await runtime.fast();
  assert.deepEqual(snapshots(runtime.manager).at(-1), snapshot('fast'));
  await runtime.fast('status');
  assert.match(runtime.notifications.at(-1)!.text, /on/u);
  await runtime.ultrafast('off');
  assert.equal(runtime.statuses.get('pi-model-controls'), 'fast');
  await runtime.ultrafast();
  assert.deepEqual(snapshots(runtime.manager).at(-1), snapshot('ultrafast'));
  assert.deepEqual(runtime.emit('before_provider_request', { payload: {} }), { service_tier: 'ultrafast' });
  const beforeStatus = runtime.manager.getEntries();
  await runtime.ultrafast('status');
  assert.match(runtime.notifications.at(-1)!.text, /ultrafast/u);
  assert.deepEqual(runtime.manager.getEntries(), beforeStatus);

  await runtime.fast(' ON ');
  assert.equal(runtime.statuses.get('pi-model-controls'), 'fast');
  await runtime.ultrafast('on');
  await runtime.fast('off');
  assert.deepEqual(snapshots(runtime.manager).at(-1), snapshot('normal'));
  await runtime.ultrafast('on');
  await runtime.ultrafast();
  assert.equal(runtime.statuses.get('pi-model-controls'), undefined);
  await runtime.fast('on');
  await runtime.fast();
  assert.deepEqual(snapshots(runtime.manager).at(-1), snapshot('normal'));
  await assert.rejects(runtime.fast('perhaps'), /Usage: \/fast/u);
  await assert.rejects(runtime.ultrafast('perhaps'), /Usage: \/ultrafast/u);
});

test('in-memory --no-session history survives reload but unrelated conversations default to Normal', async () => {
  const runtime = harness();
  runtime.emit('session_start');
  await runtime.ultrafast('on');
  runtime.switchModel(anthropicModel);
  assert.deepEqual(snapshots(runtime.manager).at(-1), snapshot('ultrafast', 'fast'));
  assert.equal(runtime.manager.isPersisted(), false);
  assert.equal(runtime.manager.getSessionFile(), undefined);

  const reloaded = harness(runtime.manager);
  reloaded.emit('session_start');
  assert.equal(reloaded.statuses.get('pi-model-controls'), 'ultrafast');
  reloaded.ctx.model = anthropicModel;
  reloaded.emit('session_start');
  assert.equal(reloaded.statuses.get('pi-model-controls'), 'fast');

  const separate = SessionManager.inMemory();
  reloaded.ctx.sessionManager = separate;
  reloaded.emit('session_start');
  assert.equal(reloaded.statuses.get('pi-model-controls'), undefined);
  assert.equal(reloaded.emit('before_provider_request', { payload: { model: anthropicModel.id } }), undefined);
  reloaded.ctx.model = codexModel;
  reloaded.emit('session_start');
  assert.deepEqual(reloaded.emit('before_provider_request', { payload: {} }), { service_tier: 'default' });
  assert.deepEqual(snapshots(separate), []);

  reloaded.ctx.sessionManager = runtime.manager;
  reloaded.emit('session_start');
  assert.equal(reloaded.statuses.get('pi-model-controls'), 'ultrafast');
});

test('early toggles flush with the first user message, resume from disk, and never enter model context', async () => {
  await withSessionDirectory(async (directory) => {
    const manager = SessionManager.create(directory, directory);
    const runtime = harness(manager);
    runtime.emit('session_start');
    await runtime.fast('on');
    await runtime.ultrafast('on');
    const file = manager.getSessionFile()!;
    assert.equal(existsSync(file), false);
    assert.deepEqual(manager.buildSessionContext().messages, []);

    const message = { role: 'user' as const, content: 'Hello', timestamp: Date.now() };
    manager.appendMessage(message);
    assert.equal(existsSync(file), true);
    assert.deepEqual(manager.buildSessionContext().messages, [message]);
    const diskEntries = readFileSync(file, 'utf8').trim().split('\n').map((line) => JSON.parse(line));
    assert.equal(diskEntries.filter((entry) => entry.customType === SPEED_ENTRY_TYPE).length, 2);

    const resumed = harness(SessionManager.open(file));
    resumed.emit('session_start');
    assert.deepEqual(snapshots(resumed.manager), [snapshot('fast'), snapshot('ultrafast')]);
    assert.equal(resumed.statuses.get('pi-model-controls'), 'ultrafast');
    assert.deepEqual(resumed.emit('before_provider_request', { payload: {} }), { service_tier: 'ultrafast' });
    assert.deepEqual(resumed.manager.buildSessionContext().messages, [message]);
    await resumed.fast('off');
    const restarted = harness(SessionManager.open(file));
    restarted.emit('session_start');
    assert.equal(restarted.statuses.get('pi-model-controls'), undefined);
    assert.deepEqual(snapshots(restarted.manager).at(-1), snapshot('normal'));
  });
});

test('/tree navigation does not undo the latest discussion-wide preference, including after reload', async () => {
  const runtime = harness();
  runtime.emit('session_start');
  const root = runtime.manager.appendMessage({ role: 'user', content: 'root', timestamp: Date.now() });
  await runtime.fast('on');
  await runtime.ultrafast('on');
  runtime.manager.branch(root);
  runtime.emit('session_tree');
  assert.equal(runtime.statuses.get('pi-model-controls'), 'ultrafast');
  assert.equal(runtime.manager.getBranch().some((entry) => entry.type === 'custom'), false);
  runtime.manager.appendMessage({ role: 'user', content: 'another branch', timestamp: Date.now() });
  runtime.manager.appendCustomEntry('another-extension', snapshot('normal'));
  const reloaded = harness(runtime.manager);
  reloaded.emit('session_start');
  assert.equal(reloaded.statuses.get('pi-model-controls'), 'ultrafast');
  assert.deepEqual(reloaded.emit('before_provider_request', { payload: {} }), { service_tier: 'ultrafast' });
  await reloaded.fast('off');
  runtime.manager.branch(root);
  runtime.emit('session_start');
  assert.equal(runtime.statuses.get('pi-model-controls'), undefined);
});

test('forks and branch copies inherit only copied history, then keep independent preferences', async () => {
  await withSessionDirectory(async (directory) => {
    const source = harness(SessionManager.create(directory, directory));
    source.emit('session_start');
    const root = source.manager.appendMessage({ role: 'user', content: 'source', timestamp: Date.now() });
    await source.ultrafast('on');
    source.switchModel(anthropicModel);
    const file = source.manager.getSessionFile()!;
    const copiedPath = SessionManager.open(file).createBranchedSession(source.manager.getLeafId()!)!;
    const earlyPath = SessionManager.open(file).createBranchedSession(root)!;
    const fork = SessionManager.forkFrom(file, directory, directory);

    for (const manager of [fork, SessionManager.open(copiedPath)]) {
      const inherited = harness(manager);
      inherited.emit('session_start');
      assert.equal(inherited.statuses.get('pi-model-controls'), 'ultrafast');
      inherited.ctx.model = anthropicModel;
      inherited.emit('session_start');
      assert.equal(inherited.statuses.get('pi-model-controls'), 'fast');
      await inherited.fast('off');
      assert.deepEqual(snapshots(manager).at(-1), snapshot('ultrafast', 'normal'));
      assert.deepEqual(snapshots(SessionManager.open(file)).at(-1), snapshot('ultrafast', 'fast'));
    }

    const early = harness(SessionManager.open(earlyPath));
    early.emit('session_start');
    assert.deepEqual(snapshots(early.manager), []);
    assert.equal(early.statuses.get('pi-model-controls'), undefined);
  });
});

test('invalid latest snapshot and unknown schemas fail closed rather than reviving older paid state', () => {
  for (const invalid of [undefined, null, [], 'fast', {},
    { version: 2, openai: 'ultrafast', anthropic: 'fast' },
    { version: 1, openai: 'priority', anthropic: 'fast' },
    { version: 1, openai: 'ultrafast', anthropic: 'ultrafast' },
    { version: 1, openai: 'fast' }]) {
    const runtime = harness();
    runtime.manager.appendCustomEntry(SPEED_ENTRY_TYPE, snapshot('ultrafast', 'fast'));
    runtime.manager.appendCustomEntry(SPEED_ENTRY_TYPE, invalid);
    runtime.manager.appendCustomEntry('another-extension', snapshot('ultrafast', 'fast'));
    const entries = runtime.manager.getEntries();
    runtime.emit('session_start');
    assert.equal(runtime.notifications.at(-1)!.level, 'warning');
    assert.equal(runtime.statuses.get('pi-model-controls'), undefined);
    assert.deepEqual(runtime.emit('before_provider_request', { payload: {} }), { service_tier: 'default' });
    runtime.switchModel(anthropicModel);
    assert.equal(runtime.statuses.get('pi-model-controls'), undefined);
    assert.equal(runtime.emit('before_provider_request', { payload: { model: anthropicModel.id } }), undefined);
    assert.deepEqual(runtime.manager.getEntries(), entries);
  }
});

test('failed native persistence appends compensation after the failed in-memory update', async (t) => {
  await withSessionDirectory(async (directory) => {
    const manager = SessionManager.create(directory, directory);
    manager.appendMessage({ role: 'user', content: 'persist me', timestamp: Date.now() });
    const runtime = harness(manager);
    runtime.emit('session_start');
    await runtime.fast('on');
    t.mock.method(manager, '_persist', (entry: CustomEntry) => {
      // SessionManager appends to memory before attempting disk I/O; throwing earlier hides the bug.
      assert.equal(manager.getEntries().at(-1), entry);
      assert.deepEqual(entry.data, snapshot('ultrafast'));
      throw new Error('disk full');
    }, { times: 1 });

    await runtime.ultrafast('on');
    assert.equal(runtime.notifications.at(-1)!.level, 'error');
    assert.match(runtime.notifications.at(-1)!.text, /Could not save.*speed in session history.*disk full/u);
    assert.deepEqual(snapshots(manager), [snapshot('fast'), snapshot('ultrafast'), snapshot('fast')]);
    assert.equal(runtime.statuses.get('pi-model-controls'), 'fast');
    assert.deepEqual(runtime.emit('before_provider_request', { payload: {} }), { service_tier: 'priority' });
    for (const reloadedManager of [manager, SessionManager.open(manager.getSessionFile()!)]) {
      const reloaded = harness(reloadedManager);
      reloaded.emit('session_start');
      assert.equal(reloaded.statuses.get('pi-model-controls'), 'fast');
    }
  });
});

test('failed picker save and failed compensation still leave in-memory reload at Normal', async (t) => {
  const runtime = harness();
  runtime.emit('session_start');
  t.mock.method(runtime.manager, '_persist', () => { throw new Error('read-only disk'); });
  const selection = runtime.selectSpeed();
  runtime.inputPicker('\x1b[B');
  runtime.inputPicker('\r');
  await selection;
  assert.equal(runtime.notifications.at(-1)!.level, 'error');
  assert.deepEqual(snapshots(runtime.manager), [snapshot('fast'), snapshot('normal')]);
  assert.equal(runtime.statuses.get('pi-model-controls'), undefined);
  assert.deepEqual(runtime.emit('before_provider_request', { payload: {} }), { service_tier: 'default' });

  const reloaded = harness(runtime.manager);
  reloaded.emit('session_start');
  assert.equal(reloaded.statuses.get('pi-model-controls'), undefined);
  assert.deepEqual(reloaded.emit('before_provider_request', { payload: {} }), { service_tier: 'default' });
});

test('failed automatic Anthropic degradation compensates without disabling OpenAI Ultrafast', async (t) => {
  const runtime = harness();
  runtime.emit('session_start');
  await runtime.ultrafast('on');
  t.mock.method(runtime.manager, '_persist', () => { throw new Error('disk full'); }, { times: 1 });
  runtime.switchModel(anthropicModel);
  assert.equal(runtime.notifications.at(-1)!.level, 'error');
  assert.deepEqual(snapshots(runtime.manager), [
    snapshot('ultrafast'), snapshot('ultrafast', 'fast'), snapshot('ultrafast'),
  ]);
  assert.equal(runtime.statuses.get('pi-model-controls'), undefined);
  assert.equal(runtime.emit('before_provider_request', { payload: { model: anthropicModel.id } }), undefined);
  runtime.switchModel(codexModel);
  assert.equal(runtime.statuses.get('pi-model-controls'), 'ultrafast');
  runtime.emit('session_start');
  assert.equal(runtime.statuses.get('pi-model-controls'), 'ultrafast');
});

test('provider preferences are independent and Anthropic model changes keep its explicit Normal choice', async () => {
  const runtime = harness();
  runtime.emit('session_start');
  await runtime.fast('on');
  runtime.switchModel(anthropicModel);
  assert.equal(runtime.statuses.get('pi-model-controls'), undefined);
  await runtime.fast('status');
  assert.match(runtime.notifications.at(-1)!.text, /Anthropic Fast mode: off/u);
  await runtime.fast('on');
  assert.match(runtime.notifications.at(-1)!.text, /usage credits.*not included/u);
  assert.deepEqual(snapshots(runtime.manager).at(-1), snapshot('fast', 'fast'));
  for (const id of ['claude-sonnet-5-5', 'claude-fable-5-1', 'arbitrary-future-model']) {
    runtime.switchModel({ ...anthropicModel, id });
    assert.equal(runtime.statuses.get('pi-model-controls'), 'fast');
    assert.deepEqual(runtime.emit('before_provider_request', { payload: { model: id } }), {
      model: id, speed: 'fast', betas: ['fast-mode-2026-02-01'],
    });
    assert.equal(runtime.ctx.model!.id, id);
  }
  const entries = runtime.manager.getEntries();
  await runtime.ultrafast('on');
  assert.equal(runtime.notifications.at(-1)!.level, 'warning');
  assert.deepEqual(runtime.manager.getEntries(), entries);
  await runtime.fast();
  runtime.switchModel(anthropicModel);
  assert.equal(runtime.statuses.get('pi-model-controls'), undefined);
  assert.deepEqual(snapshots(runtime.manager).at(-1), snapshot('fast', 'normal'));
  runtime.switchModel(codexModel);
  assert.equal(runtime.statuses.get('pi-model-controls'), 'fast');
});

test('OpenAI Ultra degrades to Anthropic Fast, preserves Ultra on return, and never enables proxy requests', async () => {
  const runtime = harness();
  runtime.emit('session_start');
  await runtime.ultrafast('on');
  runtime.switchModel({ ...anthropicModel, baseUrl: 'https://proxy.example/v1' });
  assert.deepEqual(snapshots(runtime.manager).at(-1), snapshot('ultrafast'));
  assert.equal(runtime.statuses.get('pi-model-controls'), undefined);
  runtime.switchModel(codexModel);
  runtime.switchModel(anthropicModel);
  assert.deepEqual(snapshots(runtime.manager).at(-1), snapshot('ultrafast', 'fast'));
  assert.equal(runtime.statuses.get('pi-model-controls'), 'fast');
  await runtime.fast('off');
  runtime.switchModel({ ...anthropicModel, id: 'another-anthropic-model' });
  assert.equal(runtime.statuses.get('pi-model-controls'), undefined);
  runtime.switchModel(codexModel);
  assert.equal(runtime.statuses.get('pi-model-controls'), 'ultrafast');
  assert.deepEqual(runtime.emit('before_provider_request', { payload: {} }), { service_tier: 'ultrafast' });
  runtime.switchModel(anthropicModel);
  assert.equal(runtime.statuses.get('pi-model-controls'), 'fast');
});

test('unsupported providers hide the status, cannot enable paid speed, and leave requests untouched', async () => {
  const runtime = harness();
  runtime.emit('session_start');
  await runtime.fast('on');
  runtime.switchModel({ ...codexModel, provider: 'google' });
  assert.equal(runtime.statuses.get('pi-model-controls'), undefined);
  assert.equal(runtime.emit('before_provider_request', { payload: {} }), undefined);
  const entries = runtime.manager.getEntries();
  await runtime.fast('on');
  assert.equal(runtime.notifications.at(-1)!.level, 'warning');
  assert.deepEqual(runtime.manager.getEntries(), entries);
  await runtime.fast('status');
  assert.match(runtime.notifications.at(-1)!.text, /inactive/u);
  await runtime.fast('off');
  runtime.switchModel(codexModel);
  assert.equal(runtime.statuses.get('pi-model-controls'), undefined);
});

test('accepts current and future models only on the official Codex Responses endpoint', () => {
  assert.equal(isOfficialCodexModel(codexModel), true);
  assert.equal(isOfficialCodexModel({ ...codexModel, id: 'gpt-future' }), true);
  for (const baseUrl of ['https://chatgpt.com/backend-api/', 'https://chatgpt.com/backend-api/codex',
    'https://chatgpt.com/backend-api/codex/responses/']) {
    assert.equal(isOfficialCodexModel({ ...codexModel, baseUrl }), true, baseUrl);
  }
  for (const baseUrl of ['https://proxy.example/codex', 'http://chatgpt.com/backend-api/codex',
    'https://chatgpt.com/other', 'https://user:secret@chatgpt.com/backend-api/codex', 'invalid']) {
    assert.equal(isOfficialCodexModel({ ...codexModel, baseUrl }), false, baseUrl);
  }
  assert.equal(isOfficialCodexModel({ ...codexModel, provider: 'openai' }), false);
  assert.equal(isOfficialCodexModel({ ...codexModel, api: 'openai-responses' }), false);
  assert.equal(isOfficialCodexModel(undefined), false);
});

test('OpenAI tiers preserve payloads, reject mismatched models, and accept only official API endpoints', () => {
  const payload = { model: codexModel.id, input: [{ role: 'user', content: 'hi' }], service_tier: 'auto' };
  assert.deepEqual(rewriteFastPayload(payload, codexModel, true), { ...payload, service_tier: 'priority' });
  assert.deepEqual(rewriteFastPayload(payload, codexModel, false), { ...payload, service_tier: 'default' });
  assert.equal(payload.service_tier, 'auto');
  assert.equal(rewriteFastPayload({ model: 'different-model' }, codexModel, true, true), undefined);
  assert.equal(rewriteFastPayload(payload, { ...codexModel, provider: 'anthropic' }, true), undefined);
  for (const invalid of [null, [], 'text', 123]) {
    assert.equal(rewriteFastPayload(invalid, codexModel, true), undefined);
  }
  for (const api of ['openai-responses', 'openai-completions']) {
    for (const baseUrl of ['https://api.openai.com', 'https://api.openai.com/v1/',
      'https://api.openai.com/v1/responses', 'https://api.openai.com/v1/chat/completions']) {
      const model = { ...codexModel, id: 'arbitrary-model', provider: 'openai', api, baseUrl };
      assert.equal(isOfficialOpenAIModel(model), true);
      assert.deepEqual(rewriteFastPayload({ model: model.id }, model, true, true), {
        model: model.id, service_tier: 'ultrafast',
      });
      assert.deepEqual(rewriteFastPayload({}, model, true), { service_tier: 'priority' });
      assert.deepEqual(rewriteFastPayload({}, model, false, true), { service_tier: 'default' });
    }
  }
  for (const baseUrl of ['https://proxy.example/v1', 'http://api.openai.com/v1',
    'https://api.openai.com.evil.test/v1', 'https://user:secret@api.openai.com/v1',
    'https://api.openai.com/other', 'invalid']) {
    const model = { ...codexModel, provider: 'openai', api: 'openai-responses', baseUrl };
    assert.equal(isOfficialOpenAIModel(model), false);
    assert.equal(rewriteFastPayload({}, model, true, true), undefined);
  }
  assert.equal(isOfficialOpenAIModel(anthropicModel), false);
});

test('Anthropic Fast accepts arbitrary IDs only on the official Messages endpoint', () => {
  for (const id of ['claude-opus-5-5', 'claude-sonnet-5-5', 'claude-fable-5-1', 'arbitrary-future-model']) {
    for (const baseUrl of ['https://api.anthropic.com', 'https://api.anthropic.com/',
      'https://api.anthropic.com/v1/']) {
      const model = { ...anthropicModel, id, baseUrl };
      assert.equal(isAnthropicFastModel(model), true);
      assert.deepEqual(rewriteFastPayload({ model: id }, model, true), {
        model: id, speed: 'fast', betas: ['fast-mode-2026-02-01'],
      });
    }
  }
  for (const baseUrl of ['https://proxy.example', 'http://api.anthropic.com',
    'https://api.anthropic.com.evil.test', 'https://user:secret@api.anthropic.com',
    'https://api.anthropic.com/other', 'invalid']) {
    assert.equal(isAnthropicFastModel({ ...anthropicModel, baseUrl }), false, baseUrl);
  }
  assert.equal(isAnthropicFastModel({ ...anthropicModel, provider: 'amazon-bedrock' }), false);
  assert.equal(isAnthropicFastModel({ ...anthropicModel, api: 'openai-completions' }), false);
  assert.equal(isAnthropicFastModel(undefined), false);
});

test('Anthropic payloads preserve native betas and context without mutation or cross-request leakage', () => {
  const payload = {
    model: anthropicModel.id,
    messages: [{ role: 'user', content: 'hi' }],
    betas: ['oauth-2025-04-20', 'claude-code-20250219'],
    thinking: { type: 'adaptive' },
  };
  const fast = rewriteFastPayload(payload, anthropicModel, true);
  assert.deepEqual(fast, {
    ...payload, speed: 'fast', betas: [...payload.betas, 'fast-mode-2026-02-01'],
  });
  assert.deepEqual(rewriteFastPayload(fast, anthropicModel, true), fast);
  assert.deepEqual(payload.betas, ['oauth-2025-04-20', 'claude-code-20250219']);
  assert.equal('speed' in payload, false);
  assert.equal(rewriteFastPayload(payload, anthropicModel, false), undefined);
  for (const model of [undefined, { ...anthropicModel, id: 'claude-sonnet-5-5' }]) {
    assert.equal(rewriteFastPayload(payload, model, true), undefined);
  }
  for (const model of ['claude-sonnet-5-5', 'claude-opus-4-8', undefined]) {
    assert.equal(rewriteFastPayload({ ...payload, model }, anthropicModel, true), undefined);
  }
  for (const invalid of [null, [], 'text', 123]) {
    assert.equal(rewriteFastPayload(invalid, anthropicModel, true), undefined);
  }
});
