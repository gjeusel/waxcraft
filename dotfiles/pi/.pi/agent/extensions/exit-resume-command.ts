import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';

const ANSI_CSI_PATTERN = /\x1b\[[0-?]*[ -/]*[@-~]/g;
const RESUME_MESSAGE_PREFIX = 'To resume this session:';
const STYLE_PLACEHOLDER = '__PI_RESUME_COMMAND__';

export function extractResumeCommand(chunk: unknown): string | undefined {
  if (typeof chunk !== 'string') return undefined;

  const plain = chunk.replace(ANSI_CSI_PATTERN, '').trimEnd();
  if (!plain.startsWith(RESUME_MESSAGE_PREFIX)) return undefined;

  const command = plain.slice(RESUME_MESSAGE_PREFIX.length).trim();
  if (!/(?:^|\s)--session\s+\S+$/.test(command)) return undefined;
  return command;
}

export default function (pi: ExtensionAPI) {
  pi.on('session_shutdown', (event, ctx) => {
    if (event.reason !== 'quit' || ctx.mode !== 'tui') return;

    // Pi writes its built-in resume hint only after all shutdown handlers have
    // finished, so intercept that one stdout write and leave every other write
    // untouched. Precompute the themed wrapper while the extension context is live.
    const styledTemplate = ctx.ui.theme.fg('dim', STYLE_PLACEHOLDER);
    const stdout = process.stdout;
    const originalWrite = stdout.write;

    stdout.write = ((chunk: string | Uint8Array, ...args: unknown[]): boolean => {
      const command = extractResumeCommand(chunk);
      if (!command) {
        return Reflect.apply(originalWrite, stdout, [chunk, ...args]) as boolean;
      }

      stdout.write = originalWrite;
      const styledCommand = styledTemplate.replace(STYLE_PLACEHOLDER, command);
      return Reflect.apply(originalWrite, stdout, [`${styledCommand}\n`, ...args]) as boolean;
    }) as typeof stdout.write;
  });
}
