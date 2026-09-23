import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';
import perModelPrompt, { PROMPT_SECTION, appendDirective, buildRephrasePrompt, loadModelPrompt, promptFileName } from './index.ts';

type Handler = (
  event: { systemPromptOptions: { sections: Record<string, string> } },
  ctx: { model?: { id: string } },
) => Promise<unknown>;

/** Run the handler and return the sections it left on the event. */
async function sectionsFor(handler: Handler, ctx: { model?: { id: string } }): Promise<Record<string, string>> {
  const event = { systemPromptOptions: { sections: { existing: 'kept' } as Record<string, string> } };
  assert.equal(await handler(event, ctx), undefined);
  return event.systemPromptOptions.sections;
}

function capture(promptDir: string): { handler: Handler; commands: string[] } {
  let handler: Handler | undefined;
  const commands: string[] = [];
  const pi = {
    on(event: string, fn: Handler) {
      if (event === 'before_agent_start') handler = fn;
    },
    registerCommand(name: string) {
      commands.push(name);
    },
  } as unknown as ExtensionAPI;
  perModelPrompt(pi, promptDir);
  assert.ok(handler, 'extension registered a before_agent_start handler');
  return { handler, commands };
}

test('per-model-prompt', async (t) => {
  const dir = await mkdtemp(join(tmpdir(), 'per-model-prompt-'));
  t.after(() => rm(dir, { recursive: true, force: true }));

  await writeFile(join(dir, 'claude-opus-4-7.md'), 'Opus specific guidance.\n', 'utf8');
  await writeFile(join(dir, 'gpt-5.2.md'), '   \n', 'utf8');
  await writeFile(join(dir, promptFileName('qwen/qwen3-coder')), 'Qwen guidance.', 'utf8');
  const { handler, commands } = capture(dir);

  await t.test('adds the model prompt as a system prompt section', async () => {
    assert.deepEqual(await sectionsFor(handler, { model: { id: 'claude-opus-4-7' } }), {
      existing: 'kept',
      [PROMPT_SECTION]: 'Opus specific guidance.',
    });
  });

  await t.test('flattens slashes in model ids', async () => {
    assert.equal(promptFileName('qwen/qwen3-coder'), 'qwen--qwen3-coder.md');
    assert.deepEqual(await sectionsFor(handler, { model: { id: 'qwen/qwen3-coder' } }), {
      existing: 'kept',
      [PROMPT_SECTION]: 'Qwen guidance.',
    });
  });

  await t.test('leaves the prompt untouched when no file exists', async () => {
    assert.deepEqual(await sectionsFor(handler, { model: { id: 'unknown-model' } }), { existing: 'kept' });
  });

  await t.test('ignores whitespace-only prompt files', async () => {
    assert.deepEqual(await sectionsFor(handler, { model: { id: 'gpt-5.2' } }), { existing: 'kept' });
  });

  await t.test('does nothing when no model is active', async () => {
    assert.deepEqual(await sectionsFor(handler, {}), { existing: 'kept' });
  });

  await t.test('loadModelPrompt propagates non-ENOENT errors', async () => {
    await assert.rejects(loadModelPrompt(join(dir, 'claude-opus-4-7.md'), 'anything'), /ENOTDIR/);
  });

  await t.test('registers the /mfb command', () => {
    assert.deepEqual(commands, ['mfb']);
  });

  await t.test('appendDirective creates a missing file with a single bullet', async () => {
    const file = await appendDirective(dir, 'fresh-model', 'Always do X.');
    assert.equal(file, join(dir, 'fresh-model.md'));
    assert.equal(await readFile(file, 'utf8'), '- Always do X.\n');
  });

  await t.test('appendDirective appends after existing content, fixing a missing trailing newline', async () => {
    const file = join(dir, 'existing-model.md');
    await writeFile(file, 'Some paragraph.', 'utf8');
    await appendDirective(dir, 'existing-model', ' Never do Y. ');
    await appendDirective(dir, 'existing-model', 'Before Z, check W.');
    assert.equal(await readFile(file, 'utf8'), 'Some paragraph.\n- Never do Y.\n- Before Z, check W.\n');
  });

  await t.test('buildRephrasePrompt embeds the raw feedback', () => {
    const prompt = buildRephrasePrompt('stop being verbose');
    assert.match(prompt, /Feedback:\nstop being verbose$/);
    assert.match(prompt, /single concise imperative directive/);
  });
});
