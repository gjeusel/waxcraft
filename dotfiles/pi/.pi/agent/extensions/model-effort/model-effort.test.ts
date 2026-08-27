import assert from 'node:assert/strict';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';
import modelEffort, { effortForModel, loadModelEffortDefaults, type EffortLevel } from './index.ts';

type ModelSelectHandler = (event: { model: { provider: string; id: string } }) => void;

async function capture(settingsPath: string): Promise<{
  handler: ModelSelectHandler;
  selectedEfforts: EffortLevel[];
}> {
  let handler: ModelSelectHandler | undefined;
  const selectedEfforts: EffortLevel[] = [];
  const pi = {
    on(event: string, fn: ModelSelectHandler) {
      if (event === 'model_select') handler = fn;
    },
    setThinkingLevel(level: EffortLevel) {
      selectedEfforts.push(level);
    },
  } as unknown as ExtensionAPI;

  await modelEffort(pi, settingsPath);
  assert.ok(handler, 'extension registered a model_select handler');
  return { handler, selectedEfforts };
}

test('model-effort', async (t) => {
  const dir = await mkdtemp(join(tmpdir(), 'model-effort-'));
  t.after(() => rm(dir, { recursive: true, force: true }));
  const settingsPath = join(dir, 'settings.json');
  await writeFile(
    settingsPath,
    JSON.stringify({
      modelEffortDefaults: {
        'gpt-5.6-luna': 'high',
        '*gpt-5.6-sol': 'low',
      },
    }),
  );

  await t.test('loads defaults from settings.json', async () => {
    assert.deepEqual(await loadModelEffortDefaults(settingsPath), {
      'gpt-5.6-luna': 'high',
      '*gpt-5.6-sol': 'low',
    });
  });

  await t.test('selects configured effort when the model changes', async () => {
    const { handler, selectedEfforts } = await capture(settingsPath);
    handler({ model: { provider: 'openai-codex', id: 'gpt-5.6-luna' } });
    handler({ model: { provider: 'openai-codex', id: 'preview-gpt-5.6-sol' } });
    assert.deepEqual(selectedEfforts, ['high', 'low']);
  });

  await t.test('leaves effort unchanged for models without a default', async () => {
    const { handler, selectedEfforts } = await capture(settingsPath);
    handler({ model: { provider: 'anthropic', id: 'claude-opus-4-7' } });
    assert.deepEqual(selectedEfforts, []);
  });

  await t.test('supports provider-qualified patterns', () => {
    const defaults = { 'anthropic/claude-*': 'max' } as const;
    assert.equal(effortForModel('anthropic', 'claude-opus-4-7', defaults), 'max');
    assert.equal(effortForModel('claude-bridge', 'claude-opus-4-7', defaults), undefined);
  });

  await t.test('uses no defaults when the setting is absent', async () => {
    const path = join(dir, 'empty-settings.json');
    await writeFile(path, '{}');
    assert.deepEqual(await loadModelEffortDefaults(path), {});
  });

  await t.test('rejects invalid effort levels', async () => {
    const path = join(dir, 'invalid-settings.json');
    await writeFile(path, JSON.stringify({ modelEffortDefaults: { model: 'extreme' } }));
    await assert.rejects(loadModelEffortDefaults(path), /Invalid modelEffortDefaults entry: model/);
  });
});
