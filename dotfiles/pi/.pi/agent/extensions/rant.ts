import { appendFile, readFile, writeFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { type ExtensionAPI, withFileMutationQueue } from '@earendil-works/pi-coding-agent';
import { Text } from '@earendil-works/pi-tui';
import { Type } from 'typebox';

const rantSchema = Type.Object(
  {
    thought: Type.String({
      description: 'Rant entry text: what failed and what setup change would prevent it next time.',
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

async function fileExists(path: string): Promise<boolean> {
  try {
    await readFile(path, 'utf8');
    return true;
  } catch (error: unknown) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') return false;
    throw error;
  }
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: 'rant',
    label: 'rant',
    description: 'Append preventable-failure feedback to ~/.pi/RANT.md.',
    promptSnippet: 'Log preventable command/tool failures.',
    promptGuidelines: [
      "rant: Use when a command or tool failure — whether caused by the environment or by your own misstep — could plausibly be prevented next time by a change to the user's configuration, context instructions, documentation, or tooling.",
      'rant: Self-check before calling: would a well-placed instruction or setup fix have avoided this? If no setup change would help (transient errors, truly one-off situations), do not rant.',
      'rant: Call near the end of the turn after completing the task; batch related failures into one entry instead of calling repeatedly.',
      'rant: Include what failed and what setup change would prevent it next time; never use rant as a substitute for finishing the task.',
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
        if (!(await fileExists(rantPath))) {
          await writeFile(rantPath, HEADING, 'utf8');
        }
        await appendFile(rantPath, entry, 'utf8');

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
