import assert from 'node:assert/strict';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { SessionManager, type ExtensionContext } from '@earendil-works/pi-coding-agent';
import { createApprovalPrompt } from './approval.ts';
import { AutoModeState, forwardApproval, registerSafetySession } from './session-state.ts';

function context(options: {
  parent?: ExtensionContext;
  hasUI?: boolean;
  signal?: AbortSignal;
  select?: (title: string, choices: string[], options: { signal: AbortSignal }) => Promise<string | undefined>;
} = {}): ExtensionContext {
  const directory = mkdtempSync(join(tmpdir(), 'pi-safety-session-'));
  const sessionManager = SessionManager.create('/project', directory, {
    parentSession: options.parent?.sessionManager.getSessionFile(),
  });
  sessionManager.appendSessionInfo('worker-name');

  return {
    cwd: '/project', mode: 'rpc', hasUI: options.hasUI ?? false, signal: options.signal, sessionManager,
    ui: { select: options.select ?? (async () => { throw new Error('unexpected local UI'); }) },
  } as unknown as ExtensionContext;
}

const request = { title: 'bash', language: 'bash', content: 'echo hello', reason: 'review this operation' };

test('workers share only their native parent mode, including new workers and separate module instances', async (t) => {
  const lifetime = new AbortController();
  t.after(() => lifetime.abort());
  const root = context({ hasUI: true });
  const state = new AutoModeState(true);
  registerSafetySession(root, async () => true, state, lifetime.signal);
  const workerModule = await import(new URL('./session-state.ts?worker-copy', import.meta.url).href);
  const child = context({ parent: root });
  const registered = workerModule.registerSafetySession(child, async () => false, new AutoModeState(false), lifetime.signal);
  assert.equal(registered.mode, state);

  const previous = registered.mode.snapshot();
  let updates = 0;
  const unsubscribe = state.subscribe(() => { updates++; });
  state.setEnabled(false);
  assert.equal(previous.signal.aborted, true);
  assert.equal(registered.mode.snapshot().enabled, false);
  assert.equal(registered.mode.snapshot().signal.aborted, false);
  state.setEnabled(false);
  assert.equal(updates, 1, 'unchanged modes do not cancel work again');

  const future = registerSafetySession(context({ parent: root }), async () => false, new AutoModeState(true), lifetime.signal);
  assert.equal(future.mode.snapshot().enabled, false);
  const unrelated = registerSafetySession(context(), async () => false, new AutoModeState(true), lifetime.signal);
  assert.equal(unrelated.mode.snapshot().enabled, true);
  unsubscribe();
  state.setEnabled(true);
  assert.equal(updates, 1);
});

test('forwarding preserves full content, identifies the worker, and routes only to its parent UI', async (t) => {
  const lifetime = new AbortController();
  t.after(() => lifetime.abort());
  let displayed = '';
  let answer = 'Allow';
  const root = context({ hasUI: true, select: async (title, choices) => {
    displayed = title;
    assert.deepEqual(choices, ['Allow', 'Deny']);
    return answer;
  } });
  registerSafetySession(root, createApprovalPrompt(lifetime.signal), new AutoModeState(true), lifetime.signal);
  registerSafetySession(context({ hasUI: true }), async () => { throw new Error('wrong parent'); }, new AutoModeState(true), lifetime.signal);
  const child = context({ parent: root });
  const longRequest = { ...request, content: 'x'.repeat(8000) + '\nFULL_CONTENT_TAIL' };

  assert.equal(await forwardApproval(longRequest, child, lifetime.signal), true);
  assert.ok(displayed.includes(longRequest.content));
  assert.match(displayed, /Worker: worker-name\nCwd: \/project/);
  assert.equal('worker' in longRequest, false, 'never mutate the originating request');
  answer = 'Deny';
  assert.equal(await forwardApproval(request, child, lifetime.signal), false);
  assert.equal(await forwardApproval(request, context(), lifetime.signal), undefined);
});

test('persisted nested workers walk registered ancestry; missing parents cannot choose another UI', async (t) => {
  const lifetime = new AbortController();
  t.after(() => lifetime.abort());
  const root = context({ hasUI: true });
  registerSafetySession(root, async () => true, new AutoModeState(true), lifetime.signal);
  const middle = context({ parent: root });
  const registered = registerSafetySession(middle, async () => { throw new Error('headless UI'); }, new AutoModeState(false), lifetime.signal);
  const leaf = context({ parent: middle });

  assert.equal(await forwardApproval(request, leaf, lifetime.signal), true);
  registered.dispose();
  assert.equal(await forwardApproval(request, leaf, lifetime.signal), undefined);
  assert.equal(await forwardApproval(request, context({ parent: context() }), lifetime.signal), undefined);
});

test('old runtime cleanup cannot unregister a replacement host', async (t) => {
  const oldLifetime = new AbortController();
  const newLifetime = new AbortController();
  t.after(() => newLifetime.abort());
  const root = context({ hasUI: true });
  registerSafetySession(root, async () => false, new AutoModeState(true), oldLifetime.signal);
  registerSafetySession(root, async () => true, new AutoModeState(true), newLifetime.signal);
  oldLifetime.abort();

  assert.equal(await forwardApproval(request, context({ parent: root }), newLifetime.signal), true);
  newLifetime.abort();
  assert.equal(await forwardApproval(request, context({ parent: root }), new AbortController().signal), undefined);
});

test('worker cancellation closes its prompt, independently of the parent turn signal', async (t) => {
  const lifetime = new AbortController();
  t.after(() => lifetime.abort());
  const workerTurn = new AbortController();
  let shown!: () => void;
  const showing = new Promise<void>((resolve) => { shown = resolve; });
  const root = context({ hasUI: true, signal: AbortSignal.abort(), select: async (_title, _choices, { signal }) => {
    assert.equal(signal.aborted, false, 'the unrelated parent turn must not cancel worker review');
    shown();
    return new Promise((resolve) => signal.addEventListener('abort', () => resolve(undefined), { once: true }));
  } });
  registerSafetySession(root, createApprovalPrompt(lifetime.signal), new AutoModeState(true), lifetime.signal);
  const pending = forwardApproval(request, context({ parent: root, signal: workerTurn.signal }), lifetime.signal);
  await showing;
  workerTurn.abort();
  assert.equal(await pending, false);
});

test('local and worker asks share a queue; cancellation settles queued work before the first closes', async (t) => {
  const lifetime = new AbortController();
  t.after(() => lifetime.abort());
  const queuedTurn = new AbortController();
  let firstShown!: () => void;
  const showing = new Promise<void>((resolve) => { firstShown = resolve; });
  let finishFirst!: (choice: string) => void;
  let calls = 0;
  const root = context({ hasUI: true, select: async () => {
    calls++;
    firstShown();
    return new Promise((resolve) => { finishFirst = resolve; });
  } });
  const prompt = createApprovalPrompt(lifetime.signal);
  registerSafetySession(root, prompt, new AutoModeState(true), lifetime.signal);
  const local = prompt(request, root);
  await showing;
  const worker = forwardApproval(request, context({ parent: root, signal: queuedTurn.signal }), lifetime.signal);
  queuedTurn.abort();
  assert.equal(await worker, false, 'must resolve while the local approval is still open');
  assert.equal(calls, 1);
  finishFirst('Allow');
  assert.equal(await local, true);
});

test('shutdown, throwing UI, and late Allow replies cannot authorize worker operations', async () => {
  const lifetime = new AbortController();
  const root = context({ hasUI: true });
  const child = context({ parent: root });
  let finish!: (allowed: boolean) => void;
  registerSafetySession(root, async () => new Promise((resolve) => { finish = resolve; }), new AutoModeState(true), lifetime.signal);
  const pending = forwardApproval(request, child, lifetime.signal);
  lifetime.abort();
  finish(true);
  assert.equal(await pending, false);

  const live = new AbortController();
  try {
    registerSafetySession(root, async () => { throw new Error('UI failed'); }, new AutoModeState(true), live.signal);
    assert.equal(await forwardApproval(request, child, live.signal), undefined);
    assert.equal(await forwardApproval(request, child, AbortSignal.abort()), false);
  } finally {
    live.abort();
  }
});
