import { appendFile, readFile, writeFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { type ExtensionAPI, withFileMutationQueue } from '@earendil-works/pi-coding-agent';
import { Text } from '@earendil-works/pi-tui';
import { Type } from 'typebox';

const rantSchema = Type.Object(
  {
    thought: Type.String({
      description:
        'Actionable maintenance proposal: what failed, the config/context file or setting to change, the specific edit, and why it would prevent recurrence.',
    }),
    trigger: Type.Optional(Type.String({ description: 'Optional short trigger label.' })),
  },
  { additionalProperties: false },
);

const HEADING =
  '# RANT\n\nFailure log. Command and tool failures that a change to configuration, context instructions, docs, or tooling could prevent. Human-read only.\n\n';

function clean(input: string): string {
  return input.trim().replace(/\r\n/g, '\n');
}

export function formatTimestamp(now: Date): string {
  const date = [
    String(now.getFullYear()).slice(-2),
    String(now.getMonth() + 1).padStart(2, '0'),
    String(now.getDate()).padStart(2, '0'),
  ].join('-');
  const time = [String(now.getHours()).padStart(2, '0'), String(now.getMinutes()).padStart(2, '0')].join(':');
  return `${date} ${time}`;
}

export function formatRantEntry(thought: string, cwd: string, now: Date, trigger?: string): string {
  return [`## ${formatTimestamp(now)}${trigger ? ` — ${trigger}` : ''}`, '', `cwd: ${cwd}`, '', thought, ''].join('\n');
}

function entrySeparator(existingContent: string | undefined): string {
  if (existingContent === undefined || existingContent.length === 0 || existingContent.endsWith('\n\n')) return '';
  return existingContent.endsWith('\n') ? '\n' : '\n\n';
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: 'rant',
    label: 'rant',
    description: 'Append actionable config/context change proposals to ~/.pi/RANT.md. Not a general error log.',
    promptSnippet: 'Propose concrete config/context edits justified by observed failures.',
    promptGuidelines: [
      'rant: Use only when an observed failure reveals a missing or incorrect configuration or durable context instruction AND you can propose a concrete, worthwhile edit. The purpose is to generate maintenance actions, not record every failure.',
      'rant: Before calling, identify the config/context file or setting to change (e.g. AGENTS.md, a skill, tool description, shell config, or pi settings), the specific edit, and why it would prevent recurrence. If you cannot name all three from available evidence, do not rant; do not invent a fix just to justify an entry.',
      'rant: Skip transient outages, rate limits, routine retries, typos, incorrect arguments already covered by the tool schema, ignored existing instructions, and ordinary debugging. "Be more careful", "read the docs", "retry", or "check first" are not maintenance proposals. Do not add redundant instructions or rules for isolated mistakes.',
      'rant: Good example: a check failed because the package lives in a non-obvious subdirectory; propose adding its exact working directory and test command to the project AGENTS.md. Bad example: a malformed tool call succeeded after correcting an argument already documented in its schema.',
      'rant: Call near the end of the turn after completing the task; batch related failures into one entry instead of calling repeatedly.',
      'rant: Keep the entry concise: failure evidence; target file/setting; proposed edit; prevention rationale. Skip proposals already implemented during this task unless a distinct follow-up remains. Logging a proposal does not authorize unrelated config changes; never use rant as a substitute for finishing the task.',
      'rant: RANT.md is a human-read maintenance log; never read it back for context.',
    ],
    parameters: rantSchema,
    executionMode: 'sequential',

    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      const thought = clean(params.thought);
      if (!thought) throw new Error('rant.thought must not be empty');

      const trigger = params.trigger ? clean(params.trigger) : undefined;
      const rantPath = join(homedir(), '.pi', 'RANT.md');
      const now = new Date();
      const timestamp = formatTimestamp(now);
      const entry = formatRantEntry(thought, ctx.cwd, now, trigger);

      return withFileMutationQueue(rantPath, async () => {
        let existingContent: string | undefined;
        try {
          existingContent = await readFile(rantPath, 'utf8');
        } catch (error: unknown) {
          if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
          await writeFile(rantPath, HEADING, 'utf8');
        }

        // Keep each Markdown heading separated from the previous entry.
        await appendFile(rantPath, `${entrySeparator(existingContent)}${entry}`, 'utf8');

        return {
          content: [{ type: 'text' as const, text: `Appended rant entry to ~/.pi/RANT.md (${timestamp}).` }],
          details: { path: rantPath, timestamp, trigger, thought },
        };
      });
    },

    renderCall(args, theme, _context) {
      const trigger = typeof args?.trigger === 'string' && args.trigger.trim() ? ` ${args.trigger.trim()}` : '';
      return new Text(`${theme.fg('toolTitle', theme.bold('rant'))}${theme.fg('muted', trigger)}`, 0, 0);
    },

    renderResult(result, { expanded }, theme) {
      const details = result.details as { timestamp?: unknown; thought?: unknown } | undefined;
      const timestamp = typeof details?.timestamp === 'string' ? details.timestamp : 'saved';
      let text = `${theme.fg('success', '✓')} wrote ${theme.fg('accent', '~/.pi/RANT.md')} ${theme.fg('dim', timestamp)}`;

      if (expanded && typeof details?.thought === 'string') {
        text += `\n\n${details.thought}`;
      }

      return new Text(text, 0, 0);
    },
  });
}
