import { SettingsManager, type ExtensionAPI } from '@earendil-works/pi-coding-agent';

/**
 * Pi persists every model switch as the global default. Keep model selection
 * session-local by suppressing that one settings-manager write.
 *
 * This patches a pi implementation detail because the extension API exposes no
 * session-only model setter. Restore the original method during /reload and
 * session replacement so stale extension instances do not retain the patch.
 */
export default function sessionOnlyModelSelection(pi: ExtensionAPI): void {
  const original = SettingsManager.prototype.setDefaultModelAndProvider;
  const skipDefaultModelUpdate = (): void => {};

  SettingsManager.prototype.setDefaultModelAndProvider = skipDefaultModelUpdate;

  pi.on('session_shutdown', () => {
    if (SettingsManager.prototype.setDefaultModelAndProvider === skipDefaultModelUpdate) {
      SettingsManager.prototype.setDefaultModelAndProvider = original;
    }
  });
}
