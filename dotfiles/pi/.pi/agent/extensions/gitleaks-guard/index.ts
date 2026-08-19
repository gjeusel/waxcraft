/**
 * gitleaks-guard — keep secrets away from the LLM.
 *
 * Two guards:
 *  1. Prompt guard: every input reaching the prompt (typed, pasted, rpc,
 *     extension-injected) is scanned. On a hit the message is blocked;
 *     submitting the *exact same text again* bypasses the guard (deliberate
 *     escape hatch for false positives).
 *  2. Tool-result guard: every tool output (read, bash, grep, MCP tools, ...)
 *     is scanned before it reaches the model. Detected secrets are redacted
 *     in place ([REDACTED:rule-id]) so the model can still use the rest of
 *     the content.
 *
 * spawnSync is used (not pi.exec) because pi.exec hardcodes stdin to "ignore" —
 * gitleaks' stdin mode is what lets us scan text without a temp file. The
 * ~20ms blocking call is imperceptible.
 *
 * Fail-open: if gitleaks is missing or errors, content goes through with a
 * warning — the guard must never make pi unusable.
 */
import { spawnSync } from 'node:child_process';
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';

export interface Finding {
  RuleID: string;
  StartLine: number;
  Secret: string;
}

export type ScanResult =
  | { status: 'clean' }
  | { status: 'leaks'; findings: Finding[] }
  | { status: 'error'; reason: string };

export function scan(text: string): ScanResult {
  const result = spawnSync(
    'gitleaks',
    ['stdin', '--no-banner', '--report-format', 'json', '--report-path', '/dev/stdout'],
    { input: text, encoding: 'utf8', timeout: 10_000, maxBuffer: 64 * 1024 * 1024 },
  );

  if (result.status === 0) return { status: 'clean' };

  if (result.status === 1) {
    try {
      return { status: 'leaks', findings: JSON.parse(result.stdout) as Finding[] };
    } catch {
      return { status: 'error', reason: 'unparseable findings report' };
    }
  }

  const reason = result.error ? result.error.message : `exit ${result.status}`;
  return { status: 'error', reason };
}

// Findings summary that never echoes the secret itself.
export const describe = (findings: Finding[]) => findings.map((f) => `  ${f.RuleID} (line ${f.StartLine})`).join('\n');

export interface RedactionResult {
  text: string;
  count: number;
}

export function redactWithCount(text: string, findings: Finding[]): RedactionResult {
  let out = text;
  let count = 0;

  // Gitleaks can report overlapping findings for one secret. Process each
  // unique candidate longest-first so a nested match is not counted twice.
  const uniqueFindings = new Map<string, Finding>();
  for (const finding of findings) {
    if (finding.Secret && !uniqueFindings.has(finding.Secret)) {
      uniqueFindings.set(finding.Secret, finding);
    }
  }

  const orderedFindings = [...uniqueFindings.values()].sort((a, b) => b.Secret.length - a.Secret.length);
  for (const finding of orderedFindings) {
    const parts = out.split(finding.Secret);
    const occurrences = parts.length - 1;
    if (occurrences === 0) continue;

    count += occurrences;
    out = parts.join(`[REDACTED:${finding.RuleID}]`);
  }

  return { text: out, count };
}

export function redact(text: string, findings: Finding[]): string {
  return redactWithCount(text, findings).text;
}

export default function (pi: ExtensionAPI) {
  let lastBlocked: string | null = null;

  // Guard ALL prompt sources — interactive, rpc, and extension-injected alike.
  pi.on('input', async (event, ctx) => {
    if (lastBlocked !== null && event.text === lastBlocked) {
      lastBlocked = null;
      ctx.ui.notify('gitleaks-guard: bypassed (resubmitted verbatim)', 'warning');
      return { action: 'continue' };
    }

    const result = scan(event.text);

    if (result.status === 'leaks') {
      lastBlocked = event.text;
      ctx.ui.notify(
        `gitleaks-guard: prompt BLOCKED — secret(s) detected:\n${describe(result.findings)}\n` +
          'Remove the secret, or resend the exact same message to bypass.',
        'error',
      );
      return { action: 'handled' };
    }

    if (result.status === 'error') {
      ctx.ui.notify(`gitleaks-guard: scan failed (${result.reason}), prompt sent unscanned`, 'warning');
    }
    return { action: 'continue' };
  });

  // Guard tool outputs (read, bash, grep, MCP tools, ...) — redact in place.
  pi.on('tool_result', async (event, ctx) => {
    let redactedCount = 0;

    const content = event.content.map((block) => {
      if (block.type !== 'text' || !block.text) return block;

      const result = scan(block.text);

      if (result.status === 'leaks') {
        const redaction = redactWithCount(block.text, result.findings);
        redactedCount += redaction.count;
        return { ...block, text: redaction.text };
      }

      if (result.status === 'error') {
        ctx.ui.notify(
          `gitleaks-guard: scan failed (${result.reason}), ${event.toolName} result sent unscanned`,
          'warning',
        );
      }
      return block;
    });

    if (redactedCount === 0) return undefined;

    ctx.ui.notify(`gitleaks-guard: redacted ${redactedCount} secret(s) in ${event.toolName} result`, 'warning');
    return { content };
  });
}
