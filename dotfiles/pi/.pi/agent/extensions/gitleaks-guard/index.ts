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
  EndLine: number;
  StartColumn: number;
  EndColumn: number;
  Secret: string;
  Tags: string[];
}

export type ScanResult =
  | { status: 'clean' }
  | { status: 'leaks'; findings: Finding[] }
  | { status: 'error'; reason: string };

export function scan(text: string): ScanResult {
  const result = spawnSync(
    'gitleaks',
    ['stdin', '--no-banner', '--max-decode-depth', '5', '--report-format', 'json', '--report-path', '/dev/stdout'],
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
  suppressed?: true;
}

interface RedactionRange {
  start: number;
  end: number;
  ruleIds: Set<string>;
}

const UNMAPPABLE_REDACTION = '[REDACTED:gitleaks-unmappable-finding]';

function lineStartOffsets(buffer: Buffer): number[] {
  const offsets = [0];
  for (let index = 0; index < buffer.length; index += 1) {
    if (buffer[index] === 0x0a) offsets.push(index + 1);
  }
  return offsets;
}

function sourceRange(buffer: Buffer, lineStarts: number[], finding: Finding): RedactionRange | undefined {
  const startLine = lineStarts[finding.StartLine - 1];
  const endLine = lineStarts[finding.EndLine - 1];
  if (
    startLine === undefined ||
    endLine === undefined ||
    !Number.isInteger(finding.StartColumn) ||
    !Number.isInteger(finding.EndColumn) ||
    finding.StartColumn < 1 ||
    finding.EndColumn < 1
  ) {
    return undefined;
  }

  // Gitleaks reports UTF-8 byte columns. Its location calculation uses the
  // previous newline byte as the origin, so lines after the first carry an
  // extra column that must be removed when mapping back to the source.
  const startAdjustment = finding.StartLine > 1 ? 1 : 0;
  const endAdjustment = finding.EndLine > 1 ? 1 : 0;
  const start = startLine + finding.StartColumn - 1 - startAdjustment;
  const end = endLine + finding.EndColumn - endAdjustment;
  const endLineBoundary = lineStarts[finding.EndLine] === undefined ? buffer.length : lineStarts[finding.EndLine] - 1;
  if (start < startLine || end <= start || end > endLineBoundary) return undefined;

  return { start, end, ruleIds: new Set([finding.RuleID]) };
}

function literalRanges(buffer: Buffer, finding: Finding): RedactionRange[] {
  if (!finding.Secret) return [];

  const secret = Buffer.from(finding.Secret, 'utf8');
  if (secret.length === 0) return [];

  const ranges: RedactionRange[] = [];
  let offset = 0;
  while (offset <= buffer.length - secret.length) {
    const start = buffer.indexOf(secret, offset);
    if (start < 0) break;
    ranges.push({ start, end: start + secret.length, ruleIds: new Set([finding.RuleID]) });
    offset = start + secret.length;
  }
  return ranges;
}

function mergeRanges(ranges: RedactionRange[]): RedactionRange[] {
  const ordered = ranges.sort((a, b) => a.start - b.start || b.end - a.end);
  const merged: RedactionRange[] = [];

  for (const range of ordered) {
    const previous = merged.at(-1);
    if (!previous || range.start >= previous.end) {
      merged.push({ ...range, ruleIds: new Set(range.ruleIds) });
      continue;
    }

    previous.end = Math.max(previous.end, range.end);
    for (const ruleId of range.ruleIds) previous.ruleIds.add(ruleId);
  }

  return merged;
}

export function redactWithCount(text: string, findings: Finding[]): RedactionResult {
  if (findings.length === 0) return { text: UNMAPPABLE_REDACTION, count: 1, suppressed: true };

  const buffer = Buffer.from(text, 'utf8');
  const lineStarts = lineStartOffsets(buffer);
  const ranges: RedactionRange[] = [];

  for (const finding of findings) {
    const literal = literalRanges(buffer, finding);
    if (literal.length > 0) {
      ranges.push(...literal);
      continue;
    }

    const positional = sourceRange(buffer, lineStarts, finding);
    if (!positional) {
      return { text: UNMAPPABLE_REDACTION, count: findings.length, suppressed: true };
    }
    ranges.push(positional);
  }

  const merged = mergeRanges(ranges);
  if (merged.length === 0) return { text: UNMAPPABLE_REDACTION, count: findings.length, suppressed: true };

  let out = buffer;
  for (const range of [...merged].reverse()) {
    const ruleIds = [...range.ruleIds].sort().join('+');
    const replacement = Buffer.from(`[REDACTED:${ruleIds}]`, 'utf8');
    out = Buffer.concat([out.subarray(0, range.start), replacement, out.subarray(range.end)]);
  }

  return { text: out.toString('utf8'), count: merged.length };
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
