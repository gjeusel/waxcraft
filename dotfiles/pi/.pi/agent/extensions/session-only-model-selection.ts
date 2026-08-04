import { SettingsManager, type ExtensionAPI } from '@earendil-works/pi-coding-agent';

/**
 * Pi persists every model and thinking-level switch as global defaults. Keep
 * both selections session-local by suppressing those settings-manager writes.
 *
 * This patches pi implementation details because the extension API exposes no
 * session-only setters. Restore the original methods during /reload and session
 * replacement so stale extension instances do not retain the patches.
 */
export default function sessionOnlyModelSelection(pi: ExtensionAPI): void {
  const originalModelSetter = SettingsManager.prototype.setDefaultModelAndProvider;
  const originalThinkingSetter = SettingsManager.prototype.setDefaultThinkingLevel;
  const skipDefaultModelUpdate = (): void => {};
  const skipDefaultThinkingUpdate = (): void => {};

  SettingsManager.prototype.setDefaultModelAndProvider = skipDefaultModelUpdate;
  SettingsManager.prototype.setDefaultThinkingLevel = skipDefaultThinkingUpdate;

  pi.on('session_shutdown', () => {
    if (SettingsManager.prototype.setDefaultModelAndProvider === skipDefaultModelUpdate) {
      SettingsManager.prototype.setDefaultModelAndProvider = originalModelSetter;
    }
    if (SettingsManager.prototype.setDefaultThinkingLevel === skipDefaultThinkingUpdate) {
      SettingsManager.prototype.setDefaultThinkingLevel = originalThinkingSetter;
    }
  });
}
