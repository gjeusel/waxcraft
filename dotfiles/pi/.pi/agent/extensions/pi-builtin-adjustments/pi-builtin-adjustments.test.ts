import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { SettingsManager, type ExtensionAPI } from '@earendil-works/pi-coding-agent';
import {
  adjustExitResumeCommand,
  adjustMonorepoSkillDiscovery,
  adjustOptionalModelWarnings,
  adjustSessionOnlyModelSelection,
  collectAncestorSkillPaths,
  extractResumeCommand,
} from './index.ts';

test('collects Claude and Agent skill directories from cwd through the Git root', () => {
  const repository = mkdtempSync(join(tmpdir(), 'pi-monorepo-skills-'));
  const application = join(repository, 'apps', 'example');
  const nestedDirectory = join(application, 'src', 'components');

  mkdirSync(join(repository, '.git'));
  mkdirSync(join(repository, '.claude', 'skills'), { recursive: true });
  mkdirSync(join(repository, '.agents', 'skills'), { recursive: true });
  mkdirSync(join(application, '.claude', 'skills'), { recursive: true });
  mkdirSync(join(application, '.agents', 'skills'), { recursive: true });
  mkdirSync(nestedDirectory, { recursive: true });

  assert.deepEqual(collectAncestorSkillPaths(nestedDirectory), [
    join(application, '.claude', 'skills'),
    join(application, '.agents', 'skills'),
    join(repository, '.claude', 'skills'),
    join(repository, '.agents', 'skills'),
  ]);
});

test('only contributes ancestor skills for trusted projects', () => {
  type ResourcesHandler = (
    event: { cwd: string },
    ctx: { isProjectTrusted: () => boolean },
  ) => { skillPaths?: string[] } | undefined;

  const repository = mkdtempSync(join(tmpdir(), 'pi-trusted-skills-'));
  const skillPath = join(repository, '.claude', 'skills');
  mkdirSync(join(repository, '.git'));
  mkdirSync(skillPath, { recursive: true });

  let resourcesHandler: ResourcesHandler | undefined;
  const pi = {
    on(event: string, handler: ResourcesHandler) {
      if (event === 'resources_discover') resourcesHandler = handler;
    },
  } as unknown as ExtensionAPI;
  adjustMonorepoSkillDiscovery(pi);
  assert.ok(resourcesHandler);

  assert.equal(resourcesHandler({ cwd: repository }, { isProjectTrusted: () => false }), undefined);
  assert.deepEqual(resourcesHandler({ cwd: repository }, { isProjectTrusted: () => true }), {
    skillPaths: [skillPath],
  });
});

test('extracts the command from the built-in exit message', () => {
  assert.equal(
    extractResumeCommand('\x1b[2mTo resume this session:\x1b[22m pi --session 019fcc16-f8b7-759a-813d-932749de61ca\n'),
    'pi --session 019fcc16-f8b7-759a-813d-932749de61ca',
  );
});

test('preserves a custom session directory', () => {
  assert.equal(
    extractResumeCommand("To resume this session: pi --session-dir '/tmp/pi sessions' --session abc123\n"),
    "pi --session-dir '/tmp/pi sessions' --session abc123",
  );
});

test('ignores unrelated stdout writes', () => {
  assert.equal(extractResumeCommand('ordinary output\n'), undefined);
  assert.equal(extractResumeCommand(new Uint8Array()), undefined);
});

test('rewrites only the built-in quit message using the dim theme color', () => {
  type ShutdownHandler = (
    event: { reason: string },
    ctx: { mode: string; ui: { theme: { fg: (color: string, text: string) => string } } },
  ) => void;

  let shutdownHandler: ShutdownHandler | undefined;
  const pi = {
    on(event: string, handler: ShutdownHandler) {
      if (event === 'session_shutdown') shutdownHandler = handler;
    },
  } as unknown as ExtensionAPI;
  adjustExitResumeCommand(pi);
  assert.ok(shutdownHandler);

  const actualWrite = process.stdout.write;
  const writes: string[] = [];
  process.stdout.write = ((chunk: string | Uint8Array) => {
    writes.push(String(chunk));
    return true;
  }) as typeof process.stdout.write;

  try {
    shutdownHandler(
      { reason: 'quit' },
      { mode: 'tui', ui: { theme: { fg: (color, text) => `<${color}>${text}</${color}>` } } },
    );
    process.stdout.write('\x1b[2mTo resume this session:\x1b[22m pi --session abc123\n');
  } finally {
    process.stdout.write = actualWrite;
  }

  assert.deepEqual(writes, ['<dim>pi --session abc123</dim>\n']);
});

test('suppresses no-match warnings except for mandatory providers during startup', () => {
  type Handler = () => void;

  const actualWarn = console.warn;
  const warnings: unknown[][] = [];
  const handlers = new Map<string, Handler>();
  console.warn = (...args: unknown[]): void => {
    warnings.push(args);
  };

  const pi = {
    on(event: string, handler: Handler) {
      handlers.set(event, handler);
    },
  } as unknown as ExtensionAPI;

  try {
    adjustOptionalModelWarnings(pi);

    console.warn('Warning: No models match pattern "moonshotai/kimi-k3"');
    console.warn('Warning: No models match pattern "deepseek/deepseek-v4-pro"');
    console.warn('Warning: No models match pattern "claude-bridge/claude-opus-4-8"');
    console.warn('Warning: No models match pattern "openai-codex/gpt-5.6-sol"');
    console.warn('A different warning');

    assert.deepEqual(warnings, [
      ['Warning: No models match pattern "claude-bridge/claude-opus-4-8"'],
      ['Warning: No models match pattern "openai-codex/gpt-5.6-sol"'],
      ['A different warning'],
    ]);

    handlers.get('session_start')?.();
    console.warn('Warning: No models match pattern "moonshotai/kimi-k3"');

    assert.deepEqual(warnings.at(-1), ['Warning: No models match pattern "moonshotai/kimi-k3"']);
  } finally {
    handlers.get('session_shutdown')?.();
    console.warn = actualWarn;
  }
});

test('keeps model and thinking-level defaults unchanged during a session', () => {
  type ShutdownHandler = () => void;

  const originalModelSetter = SettingsManager.prototype.setDefaultModelAndProvider;
  const originalThinkingSetter = SettingsManager.prototype.setDefaultThinkingLevel;
  let shutdownHandler: ShutdownHandler | undefined;
  const pi = {
    on(event: string, handler: ShutdownHandler) {
      if (event === 'session_shutdown') shutdownHandler = handler;
    },
  } as unknown as ExtensionAPI;

  try {
    adjustSessionOnlyModelSelection(pi);

    assert.notEqual(SettingsManager.prototype.setDefaultModelAndProvider, originalModelSetter);
    assert.notEqual(SettingsManager.prototype.setDefaultThinkingLevel, originalThinkingSetter);
    assert.doesNotThrow(() => {
      SettingsManager.prototype.setDefaultModelAndProvider.call({} as SettingsManager, 'provider', 'model');
      SettingsManager.prototype.setDefaultThinkingLevel.call({} as SettingsManager, 'low');
    });
  } finally {
    shutdownHandler?.();
  }

  assert.equal(SettingsManager.prototype.setDefaultModelAndProvider, originalModelSetter);
  assert.equal(SettingsManager.prototype.setDefaultThinkingLevel, originalThinkingSetter);
});
