import assert from 'node:assert/strict';
import test from 'node:test';
import { SettingsManager, type ExtensionAPI } from '@earendil-works/pi-coding-agent';
import sessionOnlyModelSelection from './index.ts';

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
    sessionOnlyModelSelection(pi);

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
