import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { Server } from 'node:http';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test, { type TestContext } from 'node:test';
import {
  SessionManager,
  type ExtensionAPI,
  type ExtensionCommandContext,
  type ExtensionContext,
  type ExtensionToolContext,
  type Theme,
  type ToolDefinition,
} from '@earendil-works/pi-coding-agent';
import artifactsExtension, { latestSessionArtifactId } from './index.ts';
import { listArtifacts, publishArtifact } from './store.ts';

async function harness(t: TestContext) {
  const workDir = await mkdtemp(join(tmpdir(), 'pi-artifacts-extension-test-'));
  const storeDir = join(workDir, '.pi', 'agent', 'artifacts');
  const sessionManager = SessionManager.create(workDir, join(workDir, 'sessions'));
  sessionManager.appendMessage({ role: 'user', content: 'Build an artifact', timestamp: Date.now() });

  type Handler = (event: unknown, ctx: ExtensionContext) => unknown;
  const handlers = new Map<string, Handler>();
  const commands = new Map<string, Parameters<ExtensionAPI['registerCommand']>[1]>();
  const shortcuts = new Map<string, Parameters<ExtensionAPI['registerShortcut']>[1]>();
  const tools: ToolDefinition[] = [];
  const notifications: { message: string; level?: string }[] = [];
  const exec = t.mock.fn<ExtensionAPI['exec']>(async () => ({
    stdout: '', stderr: '', code: 0, killed: false,
  }));
  const select = t.mock.fn(async (_title: string, _options: string[]): Promise<string | undefined> => undefined);
  const ctx = {
    cwd: workDir,
    hasUI: false,
    sessionManager,
    ui: {
      select,
      notify: (message: string, level?: string) => notifications.push({ message, level }),
    },
  } as unknown as ExtensionCommandContext & ExtensionToolContext;
  const pi = {
    on: (name: string, handler: Handler) => handlers.set(name, handler),
    registerTool: (tool: ToolDefinition) => tools.push(tool),
    registerCommand: (name: string, command: Parameters<ExtensionAPI['registerCommand']>[1]) =>
      commands.set(name, command),
    registerShortcut: (name: string, shortcut: Parameters<ExtensionAPI['registerShortcut']>[1]) =>
      shortcuts.set(name, shortcut),
    appendEntry: (customType: string, data: unknown) => sessionManager.appendCustomEntry(customType, data),
    sendMessage: (message: Parameters<ExtensionAPI['sendMessage']>[0]) =>
      sessionManager.appendCustomMessageEntry(message.customType, message.content, message.display, message.details),
    exec,
  } as unknown as ExtensionAPI;

  // Only factory initialization reads HOME; all asynchronous work uses the captured store path.
  const home = process.env.HOME;
  process.env.HOME = workDir;
  try {
    artifactsExtension(pi);
  } finally {
    if (home === undefined) delete process.env.HOME;
    else process.env.HOME = home;
  }

  const emit = async (name: string) => { await handlers.get(name)?.({}, ctx); };
  t.after(async () => {
    try {
      await emit('session_shutdown');
    } finally {
      await rm(workDir, { recursive: true, force: true });
    }
  });

  const tool = tools.find((entry) => entry.name === 'publish_artifact')!;
  const theme = { fg: (_color: string, text: string) => text } as Theme;

  return {
    workDir, storeDir, sessionManager, ctx, exec, select, notifications, emit,
    publish: (path: string, toolCallId = 'publish-call') =>
      tool.execute(toolCallId, { path }, undefined, undefined, ctx),
    command: () => commands.get('artifacts')!.handler('', ctx),
    reopen: async () => { await shortcuts.get('ctrl+]')!.handler(ctx); },
    render: (result: Awaited<ReturnType<ToolDefinition['execute']>>, isError = false) =>
      tool.renderResult!(result, { expanded: true, isPartial: false }, theme, {
        args: {}, toolCallId: 'publish-call', invalidate() {}, lastComponent: undefined, state: {},
        cwd: workDir, executionStarted: true, argsComplete: true, isPartial: false, expanded: true,
        showImages: false, isError,
      }).render(240).join('\n').trim(),
  };
}

for (const isError of [true, false]) {
  test(`renders result content without inventing success (isError=${isError})`, async (t) => {
    const h = await harness(t);
    const text = 'ENOENT: source file missing';
    const rendered = h.render({ content: [{ type: 'text', text }], details: undefined }, isError);

    assert.equal(rendered, text);
    assert.doesNotMatch(rendered, /✓|published/);
  });
}

test('an error result takes precedence over success-shaped details', async (t) => {
  const h = await harness(t);
  const rendered = h.render({
    content: [{ type: 'text', text: 'Publication blocked' }],
    details: { id: 'page', title: 'Page', url: 'http://127.0.0.1/page/', version: 1, created: true },
  }, true);

  assert.equal(rendered, 'Publication blocked');
});

test('/artifacts distinguishes identical titles, versions, and ages when attaching', async (t) => {
  const h = await harness(t);
  const now = new Date();
  for (const name of ['first.html', 'second.html']) {
    await writeFile(join(h.workDir, name), '<title>Report</title>');
    await publishArtifact(h.storeDir, { sourcePath: name, cwd: h.workDir, now });
  }
  const artifacts = await listArtifacts(h.storeDir);
  h.select.mock.mockImplementation(async (title, options) =>
    title === 'Artifacts' ? options[1] : 'Attach to session');

  await h.command();

  const labels = h.select.mock.calls[0].arguments[1];
  assert.equal(new Set(labels).size, 2);
  assert.ok(labels[1].endsWith(artifacts[1].id));
  assert.equal(latestSessionArtifactId(h.sessionManager.getBranch()), artifacts[1].id);
});

test('records nested publishes durably and follows the active branch rather than the global latest', async (t) => {
  const h = await harness(t);
  await writeFile(join(h.workDir, 'first.html'), '<title>First</title>');
  const first = await h.publish('first.html');
  const firstLeaf = h.sessionManager.appendMessage({
    role: 'toolResult', toolCallId: 'publish-call', toolName: 'publish_artifact',
    content: first.content, details: JSON.parse(JSON.stringify(first.details)),
    isError: false, timestamp: Date.now(),
  });
  const firstId = latestSessionArtifactId(h.sessionManager.getBranch())!;

  await writeFile(join(h.workDir, 'nested.html'), '<title>Nested</title>');
  await h.publish('nested.html', 'codemode-call/0');
  h.sessionManager.appendMessage({
    role: 'toolResult', toolCallId: 'codemode-call', toolName: 'codemode',
    content: [{ type: 'text', text: 'Published the nested artifact' }], isError: false, timestamp: Date.now(),
  });
  const nestedId = (await listArtifacts(h.storeDir)).find((meta) => meta.title === 'Nested')!.id;
  assert.equal(latestSessionArtifactId(h.sessionManager.getBranch()), nestedId);

  await writeFile(join(h.workDir, 'unrelated.html'), '<title>Another session</title>');
  await publishArtifact(h.storeDir, {
    sourcePath: 'unrelated.html', cwd: h.workDir, now: new Date(Date.now() + 60_000),
  });
  const restored = SessionManager.open(h.sessionManager.getSessionFile()!);
  assert.equal(latestSessionArtifactId(restored.getBranch()), nestedId);

  await h.reopen();
  assert.ok(h.exec.mock.calls.at(-1)!.arguments[1][0].endsWith(`/${nestedId}/`));

  h.sessionManager.branch(firstLeaf);
  await h.reopen();
  assert.equal(latestSessionArtifactId(h.sessionManager.getBranch()), firstId);
  assert.ok(h.exec.mock.calls.at(-1)!.arguments[1][0].endsWith(`/${firstId}/`));
});

test('a failed publish adds no artifact entry and renders the actual failure', async (t) => {
  const h = await harness(t);
  const before = h.sessionManager.getEntries();
  await assert.rejects(h.publish('missing.html'), (error: NodeJS.ErrnoException) => {
    assert.equal(error.code, 'ENOENT');
    assert.match(h.render({ content: [{ type: 'text', text: error.message }], details: undefined }, true), /ENOENT/);
    return true;
  });

  assert.deepEqual(h.sessionManager.getEntries(), before);
  assert.equal(h.exec.mock.callCount(), 0);
});

for (const failure of ['nonzero exit', 'rejected exec']) {
  test(`browser ${failure} returns publication success with a visible warning`, async (t) => {
    const h = await harness(t);
    h.ctx.hasUI = true;
    const autoOpen = process.env.PI_ARTIFACT_AUTO_OPEN;
    process.env.PI_ARTIFACT_AUTO_OPEN = '1';
    t.after(() => {
      if (autoOpen === undefined) delete process.env.PI_ARTIFACT_AUTO_OPEN;
      else process.env.PI_ARTIFACT_AUTO_OPEN = autoOpen;
    });
    h.exec.mock.mockImplementation(async () => {
      if (failure === 'rejected exec') throw new Error('Browser unavailable');
      return { stdout: '', stderr: 'Browser unavailable', code: 1, killed: false };
    });
    await writeFile(join(h.workDir, 'page.html'), '<title>Saved</title>');

    const result = await h.publish('page.html');

    assert.equal(h.exec.mock.callCount(), 1);
    const artifacts = await listArtifacts(h.storeDir);
    assert.equal(artifacts.length, 1);
    assert.equal(artifacts[0].version, 1);
    assert.equal(latestSessionArtifactId(h.sessionManager.getBranch()), artifacts[0].id);
    assert.match(await readFile(join(h.storeDir, artifacts[0].id, 'index.html'), 'utf8'), /Saved/);
    const rendered = h.render(result);
    assert.match(rendered, /✓ Saved new http:\/\/127\.0\.0\.1:/);
    assert.match(rendered, /Could not open browser/);
    assert.match(rendered, /Browser unavailable/);
    assert.match(result.content.filter((part) => part.type === 'text').map((part) => part.text).join('\n'),
      /Warning: Could not open browser/);
    assert.equal(h.notifications.at(-1)!.level, 'warning');
  });
}

test('overlapping shortcuts share a server and shutdown closes the owned listener', async (t) => {
  const h = await harness(t);
  h.sessionManager.appendCustomMessageEntry('artifact', 'Attached', true, { id: 'page' });

  await Promise.all([h.reopen(), h.reopen()]);

  const urls = h.exec.mock.calls.map((call) => call.arguments[1][0]);
  assert.equal(urls.length, 2);
  assert.equal(urls[0], urls[1]);
  const identityUrl = new URL('/__pi_artifacts', urls[0]);
  assert.deepEqual(await (await fetch(identityUrl)).json(), { storeDir: h.storeDir });

  await h.emit('session_shutdown');
  await h.emit('session_shutdown');

  await assert.rejects(fetch(identityUrl, { signal: AbortSignal.timeout(1000) }));
  await assert.rejects(h.reopen(), /shutting down/);
  assert.equal(h.exec.mock.callCount(), 2);
});

test('failed server startup is shared and does not prevent a later retry', async (t) => {
  const h = await harness(t);
  h.sessionManager.appendCustomMessageEntry('artifact', 'Attached', true, { id: 'page' });
  const listen = t.mock.method(Server.prototype, 'listen', () => { throw new Error('Cannot listen'); });

  await Promise.all([
    assert.rejects(h.reopen(), /Cannot listen/),
    assert.rejects(h.reopen(), /Cannot listen/),
  ]);
  assert.equal(listen.mock.callCount(), 1);
  assert.equal(h.exec.mock.callCount(), 0);
  listen.mock.restore();

  await h.reopen();
  assert.equal(h.exec.mock.callCount(), 1);
});

test('shutdown drains in-flight startup and a later session can start again', async (t) => {
  const h = await harness(t);
  h.sessionManager.appendCustomMessageEntry('artifact', 'Attached', true, { id: 'page' });

  const opening = assert.rejects(h.reopen(), /shutting down/);
  await h.emit('session_shutdown');
  await opening;
  assert.equal(h.exec.mock.callCount(), 0);

  await h.emit('session_start');
  await h.reopen();
  assert.equal(h.exec.mock.callCount(), 1);
  const identityUrl = new URL('/__pi_artifacts', h.exec.mock.calls[0].arguments[1][0]);
  assert.deepEqual(await (await fetch(identityUrl)).json(), { storeDir: h.storeDir });

  await h.emit('session_shutdown');
  await assert.rejects(fetch(identityUrl, { signal: AbortSignal.timeout(1000) }));
});
