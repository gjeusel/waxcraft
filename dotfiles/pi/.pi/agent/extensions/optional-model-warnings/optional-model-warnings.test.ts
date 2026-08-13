import assert from 'node:assert/strict';
import test from 'node:test';
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';
import optionalModelWarnings from './index.ts';

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
    optionalModelWarnings(pi);

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
