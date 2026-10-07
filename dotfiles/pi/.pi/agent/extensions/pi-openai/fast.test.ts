import assert from 'node:assert/strict';
import { lstatSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import type { ExtensionAPI, ExtensionCommandContext, ExtensionContext } from '@earendil-works/pi-coding-agent';
import { isOfficialCodexModel, loadFastMode, registerFastMode, rewriteFastPayload, saveFastMode } from './fast.ts';

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

async function withConfig(run: (path: string) => void | Promise<void>): Promise<void> {
  const directory = mkdtempSync(join(tmpdir(), 'pi-openai-fast-'));
  try {
    await run(join(directory, 'pi-openai.json'));
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}

function harness(path: string) {
  type Handler = (event: unknown, ctx: ExtensionContext) => unknown;
  type Command = { handler: (args: string, ctx: ExtensionCommandContext) => Promise<void> };
  const handlers = new Map<string, Handler>();
  const commands = new Map<string, Command>();
  const statuses = new Map<string, string | undefined>();
  const notifications: { text: string; level: string }[] = [];
  const ctx = {
    model: codexModel,
    ui: {
      setStatus: (key: string, text: string | undefined) => statuses.set(key, text),
      notify: (text: string, level: string) => notifications.push({ text, level }),
    },
  } as unknown as ExtensionCommandContext;
  const pi = {
    on: (event: string, handler: Handler) => handlers.set(event, handler),
    registerCommand: (name: string, command: Command) => commands.set(name, command),
  } as unknown as ExtensionAPI;

  registerFastMode(pi, path);

  return {
    ctx,
    statuses,
    notifications,
    emit: (event: string, payload: unknown = {}) => handlers.get(event)?.(payload, ctx),
    fast: (args = '') => commands.get('fast')!.handler(args, ctx),
  };
}

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

test('requests priority or explicit standard routing without mutating the original payload', () => {
  const payload = { model: codexModel.id, input: [{ role: 'user', content: 'hi' }], service_tier: 'auto' };
  assert.deepEqual(rewriteFastPayload(payload, codexModel, true), { ...payload, service_tier: 'priority' });
  assert.deepEqual(rewriteFastPayload(payload, codexModel, false), { ...payload, service_tier: 'default' });
  assert.equal(payload.service_tier, 'auto');
  assert.equal(rewriteFastPayload(payload, { ...codexModel, provider: 'anthropic' }, true), undefined);

  for (const invalid of [null, [], 'text', 123]) {
    assert.equal(rewriteFastPayload(invalid, codexModel, true), undefined);
  }
});

test('defaults off and saves preferences while preserving unrelated keys and Stow symlinks', async () => {
  await withConfig((path) => {
    assert.equal(loadFastMode(path), false);
    const target = `${path}.source`;
    writeFileSync(target, '{"other":{"keep":true},"fastMode":false}\n');
    symlinkSync(target, path);

    saveFastMode(path, true);

    assert.equal(lstatSync(path).isSymbolicLink(), true);
    assert.equal(loadFastMode(path), true);
    assert.deepEqual(JSON.parse(readFileSync(target, 'utf8')), { other: { keep: true }, fastMode: true });
    saveFastMode(path, false);
    assert.equal(loadFastMode(path), false);
  });
});

test('rejects malformed and invalid settings without overwriting them', async () => {
  await withConfig((path) => {
    for (const text of ['{', '[]', 'null', '{"fastMode":"true"}', `{"other":"${'a'.repeat(64 * 1024)}"}`]) {
      writeFileSync(path, text);
      assert.throws(() => loadFastMode(path));
      assert.throws(() => saveFastMode(path, true));
      assert.equal(readFileSync(path, 'utf8'), text);
    }
  });
});

test('/fast persists toggles, supports on/off/status, and restores the preference at session start', async () => {
  await withConfig(async (path) => {
    const runtime = harness(path);
    runtime.emit('session_start');
    assert.equal(runtime.statuses.get('pi-openai'), undefined);

    await runtime.fast();
    assert.equal(loadFastMode(path), true);
    assert.equal(runtime.statuses.get('pi-openai'), 'fast');
    assert.deepEqual(runtime.emit('before_provider_request', { payload: { input: [] } }), {
      input: [], service_tier: 'priority',
    });

    const resumed = harness(path);
    resumed.emit('session_start');
    assert.equal(resumed.statuses.get('pi-openai'), 'fast');
    await resumed.fast('status');
    assert.match(resumed.notifications.at(-1)!.text, /on/u);

    await runtime.fast('off');
    assert.equal(loadFastMode(path), false);
    assert.equal(runtime.statuses.get('pi-openai'), undefined);
    await runtime.fast('on');
    await runtime.fast();
    assert.equal(loadFastMode(path), false);
    await assert.rejects(runtime.fast('perhaps'), /Usage/u);
  });
});

test('model switching hides Fast status and leaves other providers untouched', async () => {
  await withConfig(async (path) => {
    const runtime = harness(path);
    runtime.emit('session_start');
    await runtime.fast('on');

    runtime.ctx.model = { ...codexModel, provider: 'anthropic' };
    runtime.emit('model_select');
    assert.equal(runtime.statuses.get('pi-openai'), undefined);
    assert.equal(runtime.emit('before_provider_request', { payload: { input: [] } }), undefined);

    await runtime.fast('on');
    assert.equal(runtime.notifications.at(-1)!.level, 'warning');
    await runtime.fast('off');
    assert.equal(loadFastMode(path), false);

    runtime.ctx.model = codexModel;
    runtime.emit('model_select');
    assert.equal(runtime.statuses.get('pi-openai'), undefined);
  });
});

test('invalid settings and failed saves keep Fast mode off and surface the failure', async () => {
  await withConfig(async (path) => {
    writeFileSync(path, '{"fastMode":42}');
    const runtime = harness(path);
    runtime.emit('session_start');
    assert.equal(runtime.notifications.at(-1)!.level, 'warning');
    await runtime.fast('on');
    assert.equal(runtime.notifications.at(-1)!.level, 'error');
    assert.equal(runtime.statuses.get('pi-openai'), undefined);
    assert.deepEqual(runtime.emit('before_provider_request', { payload: {} }), { service_tier: 'default' });
    assert.equal(readFileSync(path, 'utf8'), '{"fastMode":42}');
  });
});
