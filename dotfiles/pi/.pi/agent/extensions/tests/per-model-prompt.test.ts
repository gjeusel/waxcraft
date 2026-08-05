import assert from 'node:assert/strict';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';
import perModelPrompt, { loadModelPrompt, promptFileName } from '../per-model-prompt.ts';

type Handler = (
  event: { systemPrompt: string },
  ctx: { model?: { id: string } },
) => Promise<{ systemPrompt: string } | undefined>;

function capture(promptDir: string): Handler {
  let handler: Handler | undefined;
  const pi = {
    on(event: string, fn: Handler) {
      if (event === 'before_agent_start') handler = fn;
    },
  } as unknown as ExtensionAPI;
  perModelPrompt(pi, promptDir);
  assert.ok(handler, 'extension registered a before_agent_start handler');
  return handler;
}

test('per-model-prompt', async (t) => {
  const dir = await mkdtemp(join(tmpdir(), 'per-model-prompt-'));
  t.after(() => rm(dir, { recursive: true, force: true }));

  await writeFile(join(dir, 'claude-opus-4-7.md'), 'Opus specific guidance.\n', 'utf8');
  await writeFile(join(dir, 'gpt-5.2.md'), '   \n', 'utf8');
  await writeFile(join(dir, promptFileName('qwen/qwen3-coder')), 'Qwen guidance.', 'utf8');
  const handler = capture(dir);

  await t.test('appends the model prompt to the system prompt', async () => {
    const result = await handler({ systemPrompt: 'base prompt' }, { model: { id: 'claude-opus-4-7' } });
    assert.deepEqual(result, { systemPrompt: 'base prompt\n\nOpus specific guidance.' });
  });

  await t.test('flattens slashes in model ids', async () => {
    assert.equal(promptFileName('qwen/qwen3-coder'), 'qwen--qwen3-coder.md');
    const result = await handler({ systemPrompt: 'base' }, { model: { id: 'qwen/qwen3-coder' } });
    assert.deepEqual(result, { systemPrompt: 'base\n\nQwen guidance.' });
  });

  await t.test('leaves the prompt untouched when no file exists', async () => {
    assert.equal(await handler({ systemPrompt: 'base' }, { model: { id: 'unknown-model' } }), undefined);
  });

  await t.test('ignores whitespace-only prompt files', async () => {
    assert.equal(await handler({ systemPrompt: 'base' }, { model: { id: 'gpt-5.2' } }), undefined);
  });

  await t.test('does nothing when no model is active', async () => {
    assert.equal(await handler({ systemPrompt: 'base' }, {}), undefined);
  });

  await t.test('loadModelPrompt propagates non-ENOENT errors', async () => {
    await assert.rejects(loadModelPrompt(join(dir, 'claude-opus-4-7.md'), 'anything'), /ENOTDIR/);
  });
});
