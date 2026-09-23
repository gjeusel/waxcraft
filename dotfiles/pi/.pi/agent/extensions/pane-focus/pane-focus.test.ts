import assert from 'node:assert/strict';
import { PassThrough } from 'node:stream';
import { test } from 'node:test';
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';
import paneFocus from './index.ts';

test('dims the editor border on focus loss outside tmux', async () => {
  const previousTmux = process.env.TMUX;
  const previousPane = process.env.TMUX_PANE;
  delete process.env.TMUX;
  delete process.env.TMUX_PANE;

  const input = new PassThrough();
  const handlers = new Map<string, (event: unknown, ctx?: unknown) => Promise<void> | void>();
  const execCalls: string[] = [];
  const pi = {
    on: (event: string, handler: (event: unknown, ctx?: unknown) => Promise<void> | void) =>
      handlers.set(event, handler),
    exec: async (command: string) => {
      execCalls.push(command);
      return { code: 1, stdout: '', stderr: '' };
    },
  } as unknown as ExtensionAPI;

  const writes: string[] = [];
  let renders = 0;
  const tui = { terminal: { write: (data: string) => writes.push(data) }, requestRender: () => (renders += 1) };
  const editor = {
    borderColor: (text: string) => `active:${text}`,
    render(this: { borderColor: (text: string) => string }) {
      return [this.borderColor('border')];
    },
  };
  let terminalInput: ((data: string) => unknown) | undefined;
  const ctx = {
    mode: 'tui',
    ui: {
      theme: { fg: (_color: string, text: string) => `dim:${text}` },
      getEditorComponent: () => () => editor,
      setEditorComponent: (factory: (tui: unknown, theme: unknown, keybindings: unknown) => typeof editor) => {
        factory(tui, {}, {});
      },
      onTerminalInput: (handler: (data: string) => unknown) => {
        terminalInput = handler;
        return () => {};
      },
    },
  };

  try {
    paneFocus(pi, input);
    await handlers.get('session_start')!({}, ctx);
    assert.deepEqual(writes, ['\x1b[?1004h']);
    assert.deepEqual(execCalls, []);
    assert.deepEqual(editor.render(), ['active:border']);

    input.write('\x1b[O');
    assert.deepEqual(editor.render(), ['dim:border']);
    assert.equal(renders, 1);
    assert.deepEqual(terminalInput!('\x1b[Ohello'), { data: 'hello' });
    assert.deepEqual(terminalInput!('\x1b[I'), { consume: true });

    input.write('\x1b[I');
    assert.deepEqual(editor.render(), ['active:border']);

    await handlers.get('session_shutdown')!({});
    assert.equal(writes.at(-1), '\x1b[?1004l');
  } finally {
    input.destroy();
    if (previousTmux !== undefined) process.env.TMUX = previousTmux;
    if (previousPane !== undefined) process.env.TMUX_PANE = previousPane;
  }
});
