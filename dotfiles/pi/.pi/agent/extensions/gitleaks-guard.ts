/**
 * gitleaks-guard — block prompts containing secrets.
 *
 * Every input reaching the prompt (typed, pasted, rpc, extension-injected) is
 * piped to `gitleaks stdin` before it reaches the LLM. On a hit the message is
 * blocked and the findings shown; submitting the *exact same text again*
 * bypasses the guard (deliberate escape hatch for false positives).
 *
 * spawnSync is used (not pi.exec) because pi.exec hardcodes stdin to "ignore" —
 * gitleaks' stdin mode is what lets us scan the text without a temp file. The
 * ~20ms blocking call is imperceptible at input time.
 *
 * Fail-open: if gitleaks is missing or errors, the prompt goes through with a
 * warning — the guard must never make pi unusable.
 */
import { spawnSync } from 'node:child_process';
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';

const stripAnsi = (s: string) => s.replace(/\x1b\[[0-9;]*m/g, '');

export default function (pi: ExtensionAPI) {
  let lastBlocked: string | null = null;

  // Guard ALL sources — interactive, rpc, and extension-injected messages alike.
  pi.on('input', async (event, ctx) => {
    if (lastBlocked !== null && event.text === lastBlocked) {
      lastBlocked = null;
      ctx.ui.notify('gitleaks-guard: bypassed (resubmitted verbatim)', 'warning');
      return { action: 'continue' };
    }

    // --redact: never echo the secret back; -v: findings on stdout.
    const result = spawnSync('gitleaks', ['stdin', '--no-banner', '--redact', '-v'], {
      input: event.text,
      encoding: 'utf8',
      timeout: 10_000,
    });

    if (result.status === 0) return { action: 'continue' };

    if (result.status === 1) {
      lastBlocked = event.text;
      const findings = stripAnsi(result.stdout).trim();
      ctx.ui.notify(
        `gitleaks-guard: prompt BLOCKED — secret(s) detected:\n${findings}\n` +
          'Remove the secret, or resend the exact same message to bypass.',
        'error',
      );
      return { action: 'handled' };
    }

    // gitleaks not found / crashed / timed out → fail open.
    const reason = result.error ? result.error.message : `exit ${result.status}`;
    ctx.ui.notify(`gitleaks-guard: scan failed (${reason}), prompt sent unscanned`, 'warning');
    return { action: 'continue' };
  });
}
