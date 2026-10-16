import assert from 'node:assert/strict';
import { lstatSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import test from 'node:test';
import type { ExtensionAPI, ExtensionCommandContext, ExtensionContext } from '@earendil-works/pi-coding-agent';
import { matchesKey, visibleWidth } from '@earendil-works/pi-tui';
import {
  isAnthropicFastModel, isOfficialCodexModel, isOfficialOpenAIModel, loadFastMode, loadUltrafastMode,
  registerFastMode, rewriteFastPayload, saveFastMode,
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
  const shortcuts = new Map<string, Parameters<ExtensionAPI['registerShortcut']>[1]>();
  type UIFactory = Parameters<ExtensionContext['ui']['custom']>[0];
  let picker: Awaited<ReturnType<UIFactory>> | undefined;
  let dialogs = 0;
  const statuses = new Map<string, string | undefined>();
  const notifications: { text: string; level: string }[] = [];
  const ctx = {
    model: codexModel,
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
    registerCommand: (name: string, command: Command) => commands.set(name, command),
    registerShortcut: (key: string, options: Parameters<ExtensionAPI['registerShortcut']>[1]) =>
      shortcuts.set(key, options),
  } as unknown as ExtensionAPI;

  const anthropicPath = join(dirname(path), 'pi-anthropic.json');
  registerFastMode(pi, path, anthropicPath);

  return {
    ctx,
    anthropicPath,
    statuses,
    notifications,
    emit: (event: string, payload: unknown = {}) => handlers.get(event)?.(payload, ctx),
    fast: (args = '') => commands.get('fast')!.handler(args, ctx),
    ultrafast: (args = '') => commands.get('ultrafast')!.handler(args, ctx),
    shortcuts,
    selectSpeed: () => shortcuts.get('ctrl+shift+;')!.handler(ctx),
    renderPicker: (width = 100) => picker!.render(width),
    inputPicker: (data: string) => picker!.handleInput?.(data),
    get dialogs() { return dialogs; },
  };
}

test('Ctrl+Shift+semicolon registers a colored picker without replacing the model shortcut', async () => {
  await withConfig(async (path) => {
    const runtime = harness(path);
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
    assert.equal(loadFastMode(path), true);
    assert.equal(loadUltrafastMode(path), false);
    assert.equal(runtime.statuses.get('pi-openai'), 'fast');
    assert.deepEqual(runtime.emit('before_provider_request', { payload: {} }), { service_tier: 'priority' });
  });
});

test('picker initializes to current speed, persists all modes, and leaves cancellation unchanged', async () => {
  await withConfig(async (path) => {
    const runtime = harness(path);
    await runtime.fast('on');
    let selection = runtime.selectSpeed();
    assert.match(runtime.renderPicker().join('\n'), /Fast \(current\)/u);
    runtime.inputPicker('\x1b[B');
    runtime.inputPicker('\r');
    await selection;
    assert.equal(loadUltrafastMode(path), true);
    assert.equal(runtime.statuses.get('pi-openai'), 'ultrafast');

    selection = runtime.selectSpeed();
    runtime.inputPicker('\r');
    await selection;
    assert.equal(loadUltrafastMode(path), true);

    selection = runtime.selectSpeed();
    runtime.inputPicker('\x1b[B');
    runtime.inputPicker('\x1b');
    await selection;
    assert.equal(loadUltrafastMode(path), true);

    selection = runtime.selectSpeed();
    runtime.inputPicker('\x1b[B');
    runtime.inputPicker('\r');
    await selection;
    assert.equal(loadFastMode(path), false);
    assert.equal(loadUltrafastMode(path), false);
    assert.equal(runtime.statuses.get('pi-openai'), undefined);
  });
});

test('Anthropic picker preserves independent preferences and marks Ultrafast unavailable', async () => {
  await withConfig(async (path) => {
    const runtime = harness(path);
    saveFastMode(path, true, true);
    runtime.emit('session_start');
    runtime.ctx.model = anthropicModel;
    runtime.emit('model_select', { previousModel: codexModel, model: anthropicModel, source: 'set' });
    let selection = runtime.selectSpeed();
    assert.match(runtime.renderPicker().join('\n'), /Ultrafast \(unavailable\)/u);
    assert.match(runtime.renderPicker().join('\n'), /Fast \(current\)/u);
    runtime.inputPicker('\r');
    await selection;
    assert.equal(loadFastMode(runtime.anthropicPath), true);
    assert.equal(loadUltrafastMode(path), true);
    assert.equal(runtime.statuses.get('pi-openai'), 'fast');

    selection = runtime.selectSpeed();
    runtime.inputPicker('\x1b[B');
    runtime.inputPicker('\r');
    await selection;
    assert.equal(runtime.notifications.at(-1)!.level, 'warning');
    assert.equal(loadFastMode(runtime.anthropicPath), true);
    assert.equal(runtime.statuses.get('pi-openai'), 'fast');
  });
});

test('switching from OpenAI Ultrafast to Anthropic degrades to Fast and preserves Ultrafast on return', async () => {
  await withConfig(async (path) => {
    const runtime = harness(path);
    runtime.emit('session_start');
    await runtime.ultrafast('on');
    assert.equal(loadFastMode(runtime.anthropicPath), false);

    runtime.ctx.model = anthropicModel;
    runtime.emit('model_select', { previousModel: codexModel, model: anthropicModel, source: 'set' });
    assert.equal(runtime.statuses.get('pi-openai'), 'fast');
    assert.equal(loadFastMode(runtime.anthropicPath), true);
    assert.equal(loadUltrafastMode(path), true);
    assert.deepEqual(runtime.emit('before_provider_request', { payload: { model: anthropicModel.id } }), {
      model: anthropicModel.id, speed: 'fast', betas: ['fast-mode-2026-02-01'],
    });
    const selection = runtime.selectSpeed();
    assert.match(runtime.renderPicker().join('\n'), /Fast \(current\)/u);
    runtime.inputPicker('\x1b');
    await selection;

    // An explicit Normal choice remains effective across Anthropic-only model switches.
    await runtime.fast('off');
    const otherAnthropic = { ...anthropicModel, id: 'arbitrary-anthropic-model' };
    runtime.ctx.model = otherAnthropic;
    runtime.emit('model_select', { previousModel: anthropicModel, model: otherAnthropic, source: 'cycle' });
    assert.equal(runtime.statuses.get('pi-openai'), undefined);

    runtime.ctx.model = codexModel;
    runtime.emit('model_select', { previousModel: otherAnthropic, model: codexModel, source: 'cycle' });
    assert.equal(runtime.statuses.get('pi-openai'), 'ultrafast');
    assert.deepEqual(runtime.emit('before_provider_request', { payload: {} }), { service_tier: 'ultrafast' });

    runtime.ctx.model = otherAnthropic;
    runtime.emit('model_select', { previousModel: codexModel, model: otherAnthropic, source: 'cycle' });
    assert.equal(runtime.statuses.get('pi-openai'), 'fast');
    assert.equal(loadFastMode(runtime.anthropicPath), true);
  });
});

test('Anthropic degradation only follows effective Ultrafast and does not bypass failed saves', async () => {
  await withConfig(async (path) => {
    const runtime = harness(path);
    runtime.emit('session_start');
    for (const accelerated of [false, true]) {
      runtime.ctx.model = codexModel;
      await runtime.fast(accelerated ? 'on' : 'off');
      runtime.ctx.model = anthropicModel;
      runtime.emit('model_select', { previousModel: codexModel, model: anthropicModel, source: 'set' });
      assert.equal(runtime.statuses.get('pi-openai'), undefined);
      assert.equal(loadFastMode(runtime.anthropicPath), false);
    }

    runtime.ctx.model = codexModel;
    await runtime.ultrafast('on');
    const proxyModel = { ...anthropicModel, baseUrl: 'https://proxy.example/v1' };
    runtime.ctx.model = proxyModel;
    runtime.emit('model_select', { previousModel: codexModel, model: proxyModel, source: 'set' });
    assert.equal(loadFastMode(runtime.anthropicPath), false);

    writeFileSync(runtime.anthropicPath, '{');
    runtime.ctx.model = anthropicModel;
    runtime.emit('model_select', { previousModel: codexModel, model: anthropicModel, source: 'restore' });
    assert.equal(runtime.statuses.get('pi-openai'), undefined);
    assert.equal(runtime.notifications.at(-1)!.level, 'error');
    assert.equal(readFileSync(runtime.anthropicPath, 'utf8'), '{');
    assert.equal(loadUltrafastMode(path), true);
  });
});

test('picker ignores duplicate openings and rejects stale models or failed saves', async () => {
  await withConfig(async (path) => {
    const runtime = harness(path);
    let selection = runtime.selectSpeed();
    await runtime.selectSpeed();
    assert.equal(runtime.dialogs, 1);
    runtime.ctx.model = anthropicModel;
    runtime.inputPicker('\x1b[B');
    runtime.inputPicker('\r');
    await selection;
    assert.match(runtime.notifications.at(-1)!.text, /Model changed/u);
    assert.equal(loadFastMode(path), false);
    assert.equal(loadFastMode(runtime.anthropicPath), false);

    writeFileSync(runtime.anthropicPath, '{');
    selection = runtime.selectSpeed();
    runtime.inputPicker('\x1b[B');
    runtime.inputPicker('\r');
    await selection;
    assert.equal(runtime.notifications.at(-1)!.level, 'error');
    assert.equal(runtime.statuses.get('pi-openai'), undefined);
    assert.equal(readFileSync(runtime.anthropicPath, 'utf8'), '{');
  });
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
    for (const text of ['{', '[]', 'null', '{"fastMode":"true"}', '{"ultrafastMode":42}',
      `{"other":"${'a'.repeat(64 * 1024)}"}`]) {
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

    runtime.ctx.model = { ...codexModel, provider: 'google' };
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

test('Anthropic Fast mode accepts arbitrary model IDs on the official Messages API', () => {
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

test('Anthropic payloads preserve native betas and context without mutating or leaking to other requests', () => {
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
  assert.deepEqual(rewriteFastPayload({ model: anthropicModel.id }, anthropicModel, true), {
    model: anthropicModel.id, speed: 'fast', betas: ['fast-mode-2026-02-01'],
  });

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

test('/fast isolates provider preferences and keeps Anthropic Fast across arbitrary model switches', async () => {
  await withConfig(async (path) => {
    const runtime = harness(path);
    saveFastMode(path, true);
    runtime.emit('session_start');
    assert.equal(runtime.statuses.get('pi-openai'), 'fast');

    runtime.ctx.model = anthropicModel;
    runtime.emit('model_select');
    assert.equal(runtime.statuses.get('pi-openai'), undefined);
    await runtime.fast('status');
    assert.match(runtime.notifications.at(-1)!.text, /Anthropic Fast mode: off/u);

    await runtime.fast('on');
    assert.equal(loadFastMode(runtime.anthropicPath), true);
    assert.equal(loadFastMode(path), true);
    assert.equal(runtime.statuses.get('pi-openai'), 'fast');
    assert.match(runtime.notifications.at(-1)!.text, /usage credits.*not included/u);
    assert.equal((runtime.emit('before_provider_request', {
      payload: { model: anthropicModel.id },
    }) as { speed: string }).speed, 'fast');

    for (const id of ['claude-sonnet-5-5', 'claude-fable-5-1', 'arbitrary-future-model']) {
      runtime.ctx.model = { ...anthropicModel, id };
      runtime.emit('model_select');
      assert.equal(runtime.statuses.get('pi-openai'), 'fast');
      assert.deepEqual(runtime.emit('before_provider_request', { payload: { model: id } }), {
        model: id, speed: 'fast', betas: ['fast-mode-2026-02-01'],
      });
      await runtime.fast('status');
      assert.match(runtime.notifications.at(-1)!.text, /Anthropic Fast mode: on/u);
      await runtime.fast('on');
      assert.equal(runtime.notifications.at(-1)!.level, 'info');
      assert.equal(runtime.ctx.model.id, id);
    }

    runtime.ctx.model = anthropicModel;
    runtime.emit('model_select');
    assert.equal(runtime.statuses.get('pi-openai'), 'fast');
    const resumed = harness(path);
    resumed.ctx.model = anthropicModel;
    resumed.emit('session_start');
    assert.equal(resumed.statuses.get('pi-openai'), 'fast');

    await runtime.fast();
    assert.equal(loadFastMode(runtime.anthropicPath), false);
    assert.equal(loadFastMode(path), true);
    assert.equal(runtime.statuses.get('pi-openai'), undefined);
    runtime.ctx.model = codexModel;
    runtime.emit('model_select');
    assert.equal(runtime.statuses.get('pi-openai'), 'fast');
  });
});

test('OpenAI Ultrafast sends the requested tier for arbitrary model IDs on Codex and API endpoints', () => {
  for (const api of ['openai-responses', 'openai-completions']) {
    const model = { ...codexModel, id: 'arbitrary-model', provider: 'openai', api,
      baseUrl: 'https://api.openai.com/v1' };
    assert.equal(isOfficialOpenAIModel(model), true);
    assert.deepEqual(rewriteFastPayload({ model: model.id }, model, true, true), {
      model: model.id, service_tier: 'ultrafast',
    });
    assert.deepEqual(rewriteFastPayload({}, model, true), { service_tier: 'priority' });
    assert.deepEqual(rewriteFastPayload({}, model, false, true), { service_tier: 'default' });
  }

  const model = { ...codexModel, id: 'future-codex-model' };
  assert.deepEqual(rewriteFastPayload({ service_tier: 'auto' }, model, true, true), {
    service_tier: 'ultrafast',
  });
  assert.equal(rewriteFastPayload({ model: anthropicModel.id }, model, true, true), undefined);
  for (const baseUrl of ['https://proxy.example/v1', 'http://api.openai.com/v1',
    'https://api.openai.com.evil.test/v1', 'https://user:secret@api.openai.com/v1',
    'https://api.openai.com/other', 'invalid']) {
    const unsupported = { ...model, provider: 'openai', api: 'openai-responses', baseUrl };
    assert.equal(isOfficialOpenAIModel(unsupported), false);
    assert.equal(rewriteFastPayload({}, unsupported, true, true), undefined);
  }
  assert.equal(isOfficialOpenAIModel(anthropicModel), false);
});

test('/ultrafast persists, restores, switches cleanly to fast or off, and leaves Anthropic alone', async () => {
  await withConfig(async (path) => {
    const runtime = harness(path);
    runtime.emit('session_start');
    await runtime.fast('on');
    await runtime.ultrafast('off');
    assert.equal(loadFastMode(path), true);
    assert.equal(runtime.statuses.get('pi-openai'), 'fast');
    assert.deepEqual(runtime.emit('before_provider_request', { payload: {} }), { service_tier: 'priority' });
    await runtime.ultrafast();
    assert.equal(loadFastMode(path), true);
    assert.equal(loadUltrafastMode(path), true);
    assert.equal(runtime.statuses.get('pi-openai'), 'ultrafast');
    assert.deepEqual(runtime.emit('before_provider_request', { payload: {} }), {
      service_tier: 'ultrafast',
    });
    await runtime.ultrafast('status');
    assert.match(runtime.notifications.at(-1)!.text, /ultrafast/u);

    const resumed = harness(path);
    resumed.emit('session_start');
    assert.equal(resumed.statuses.get('pi-openai'), 'ultrafast');
    runtime.ctx.model = anthropicModel;
    runtime.emit('model_select', { previousModel: codexModel, model: anthropicModel, source: 'set' });
    assert.equal(runtime.statuses.get('pi-openai'), 'fast');
    await runtime.ultrafast('on');
    assert.equal(runtime.notifications.at(-1)!.level, 'warning');
    assert.equal(loadFastMode(runtime.anthropicPath), true);
    await runtime.fast('on');
    assert.equal(runtime.statuses.get('pi-openai'), 'fast');
    assert.equal(loadUltrafastMode(path), true);

    runtime.ctx.model = codexModel;
    runtime.emit('model_select');
    assert.equal(runtime.statuses.get('pi-openai'), 'ultrafast');
    await runtime.fast('on');
    assert.equal(loadUltrafastMode(path), false);
    assert.equal(runtime.statuses.get('pi-openai'), 'fast');
    await runtime.ultrafast('on');
    await runtime.fast('off');
    assert.equal(loadFastMode(path), false);
    assert.equal(loadUltrafastMode(path), false);
    assert.deepEqual(runtime.emit('before_provider_request', { payload: {} }), { service_tier: 'default' });
    await runtime.ultrafast('on');
    await runtime.ultrafast();
    assert.equal(loadFastMode(path), false);
    assert.equal(loadUltrafastMode(path), false);
    assert.equal(loadFastMode(runtime.anthropicPath), true);
    await assert.rejects(runtime.ultrafast('perhaps'), /Usage: \/ultrafast/u);
  });
});

test('Ultrafast preserves Stow symlinks and unrelated settings, and invalid configuration fails closed', async () => {
  await withConfig(async (path) => {
    const target = `${path}.source`;
    writeFileSync(target, '{"other":42,"fastMode":true}\n');
    symlinkSync(target, path);
    saveFastMode(path, true, true);
    assert.equal(lstatSync(path).isSymbolicLink(), true);
    assert.deepEqual(JSON.parse(readFileSync(target, 'utf8')), {
      other: 42, fastMode: true, ultrafastMode: true,
    });
    saveFastMode(path, false);
    assert.equal(loadUltrafastMode(path), false);

    writeFileSync(target, '{"fastMode":true,"ultrafastMode":"true"}');
    const runtime = harness(path);
    runtime.emit('session_start');
    assert.equal(runtime.statuses.get('pi-openai'), undefined);
    await runtime.ultrafast('on');
    assert.equal(runtime.notifications.at(-1)!.level, 'error');
    assert.equal(readFileSync(target, 'utf8'), '{"fastMode":true,"ultrafastMode":"true"}');
  });
});

test('invalid Anthropic settings fail closed without disabling Codex or overwriting the file', async () => {
  await withConfig(async (path) => {
    const runtime = harness(path);
    saveFastMode(path, true);
    writeFileSync(runtime.anthropicPath, '{"fastMode":42}');
    runtime.emit('session_start');
    assert.equal(runtime.statuses.get('pi-openai'), 'fast');
    assert.match(runtime.notifications.at(-1)!.text, /Anthropic: invalid settings/u);

    runtime.ctx.model = anthropicModel;
    runtime.emit('model_select');
    await runtime.fast('on');
    assert.equal(runtime.notifications.at(-1)!.level, 'error');
    assert.equal(runtime.statuses.get('pi-openai'), undefined);
    assert.equal(runtime.emit('before_provider_request', { payload: { model: anthropicModel.id } }), undefined);
    assert.equal(readFileSync(runtime.anthropicPath, 'utf8'), '{"fastMode":42}');
    assert.equal(loadFastMode(path), true);
  });
});
