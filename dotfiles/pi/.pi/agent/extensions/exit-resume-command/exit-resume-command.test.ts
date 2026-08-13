import assert from 'node:assert/strict';
import test from 'node:test';
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';
import exitResumeCommand, { extractResumeCommand } from './index.ts';

test('extracts the command from the built-in exit message', () => {
  assert.equal(
    extractResumeCommand('\x1b[2mTo resume this session:\x1b[22m pi --session 019fcc16-f8b7-759a-813d-932749de61ca\n'),
    'pi --session 019fcc16-f8b7-759a-813d-932749de61ca',
  );
});

test('preserves a custom session directory', () => {
  assert.equal(
    extractResumeCommand("To resume this session: pi --session-dir '/tmp/pi sessions' --session abc123\n"),
    "pi --session-dir '/tmp/pi sessions' --session abc123",
  );
});

test('ignores unrelated stdout writes', () => {
  assert.equal(extractResumeCommand('ordinary output\n'), undefined);
  assert.equal(extractResumeCommand(new Uint8Array()), undefined);
});

test('rewrites only the built-in quit message using the dim theme color', () => {
  type ShutdownHandler = (
    event: { reason: string },
    ctx: { mode: string; ui: { theme: { fg: (color: string, text: string) => string } } },
  ) => void;

  let shutdownHandler: ShutdownHandler | undefined;
  const pi = {
    on(event: string, handler: ShutdownHandler) {
      if (event === 'session_shutdown') shutdownHandler = handler;
    },
  } as unknown as ExtensionAPI;
  exitResumeCommand(pi);
  assert.ok(shutdownHandler);

  const actualWrite = process.stdout.write;
  const writes: string[] = [];
  process.stdout.write = ((chunk: string | Uint8Array) => {
    writes.push(String(chunk));
    return true;
  }) as typeof process.stdout.write;

  try {
    shutdownHandler(
      { reason: 'quit' },
      { mode: 'tui', ui: { theme: { fg: (color, text) => `<${color}>${text}</${color}>` } } },
    );
    process.stdout.write('\x1b[2mTo resume this session:\x1b[22m pi --session abc123\n');
  } finally {
    process.stdout.write = actualWrite;
  }

  assert.deepEqual(writes, ['<dim>pi --session abc123</dim>\n']);
});
