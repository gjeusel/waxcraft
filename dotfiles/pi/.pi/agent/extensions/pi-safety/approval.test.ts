import assert from 'node:assert/strict';
import test from 'node:test';
import { initTheme, type ExtensionContext, type Theme } from '@earendil-works/pi-coding-agent';
import { stripTerminalSequences, TuiAltScreen, TuiMainScreen, visibleWidth, type OverlayHandle, type Terminal } from '@earendil-works/pi-tui';
import {
  ApprovalViewer,
  createApprovalPrompt,
  fileApproval,
  needsApprovalPager,
  normalizeSummary,
  reviewText,
  summarizeOperation,
  type ApprovalRequest,
} from './approval.ts';

initTheme('dark', false);
const theme = {
  fg: (_color: string, text: string) => text,
  style: (text: string) => `\x1b[30;43m${text}\x1b[0m`,
} as unknown as Theme;

const longOperation: ApprovalRequest = {
  title: 'bash', language: 'bash', reason: 'Infrastructure changes require approval',
  content: Array.from({ length: 80 }, (_, index) => `echo "operation line ${String(index + 1).padStart(2, '0')}"`).join('\n') + '\necho FINAL_SENTINEL',
};

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((settle) => { resolve = settle; });
  return { promise, resolve };
}

function flush() {
  return new Promise<void>((resolve) => setImmediate(resolve));
}

function viewer(request = longOperation, initialHeight = 20) {
  const decisions: boolean[] = [];
  let height = initialHeight;
  const component = new ApprovalViewer(request, theme, () => height, () => {}, (allowed) => decisions.push(allowed));
  component.focused = true;
  return {
    component, decisions,
    render: (width = 80) => component.render(width).map(stripTerminalSequences),
    resize: (rows: number) => { height = rows; },
  };
}

function harness(options: { mode?: string; hasUI?: boolean; signal?: AbortSignal; delayedSummary?: boolean; tuiMode?: 'regular' | 'fullscreen' } = {}) {
  const views: ApprovalViewer[] = [];
  const selections: string[] = [];
  const requests: { context: any; options: any }[] = [];
  const terminalWrites: string[] = [];
  const reply = deferred<any>();
  let renders = 0;
  const ctx = {
    mode: options.mode ?? 'tui',
    hasUI: options.hasUI ?? true,
    signal: options.signal,
    model: { provider: 'test', id: 'summary-model' },
    modelRegistry: {
      streamSimple: (_model: unknown, context: unknown, streamOptions: unknown) => {
        requests.push({ context, options: streamOptions });
        return {
          result: () => options.delayedSummary ? reply.promise : Promise.resolve({
            stopReason: 'stop', content: [{ type: 'text', text: 'Print operation progress lines without changing files.' }],
          }),
        };
      },
    },
    ui: {
      select: async (title: string, choices: string[]) => {
        selections.push(title);
        assert.deepEqual(choices, ['Allow', 'Deny']);
        return 'Allow';
      },
      custom: (factory: (...args: any[]) => ApprovalViewer, config: any) => {
        assert.equal(config.overlay, true);
        return new Promise<boolean>((resolve) => {
          const component = factory({ mode: options.tuiMode ?? 'fullscreen', terminal: { rows: 28, write: (text: string) => terminalWrites.push(text) }, requestRender: () => { renders++; } }, theme, {}, resolve);
          component.focused = true;
          views.push(component);
        });
      },
    },
  } as unknown as ExtensionContext;
  return { ctx, views, selections, requests, reply, terminalWrites, renders: () => renders };
}

test('small operations stay compact; long commands and multiline content get the pager', () => {
  assert.equal(needsApprovalPager({ title: 'bash', content: 'ls' }), false);
  assert.equal(needsApprovalPager({ title: 'bash', content: 'x'.repeat(601) }), true);
  assert.equal(needsApprovalPager({ title: 'bash', content: '\n'.repeat(6) }), true);
  assert.equal(needsApprovalPager(fileApproval('edit', { path: 'x', edits: [{ oldText: 'a', newText: 'b' }] }, '/x')), false);
});

test('file reviews preserve complete write contents and every requested replacement', () => {
  const content = '# Heading\n```\n' + 'x'.repeat(2000) + '\nWRITE_TAIL';
  assert.deepEqual(fileApproval('write', { path: 'x.md', content }, '/x.md'), {
    title: 'write /x.md', content, language: 'markdown',
  });
  const request = fileApproval('edit', {
    path: 'x', edits: [{ oldText: 'old\nvalue', newText: 'new\nvalue' }, { oldText: 'last', newText: 'EDIT_TAIL' }],
  }, '/x');
  assert.equal(request.language, 'diff');
  assert.equal(request.content, '--- /x\n+++ /x\n@@ replacement 1 @@\n-old\n-value\n+new\n+value\n@@ replacement 2 @@\n-last\n+EDIT_TAIL');
});

test('review text exposes terminal escapes and invisible controls without dropping the operation', () => {
  assert.equal(reviewText('echo\tOK\r\n\x1b[2J\u202ehidden\0'), 'echo    OK\n\\u001b[2J\\u202ehidden\\u0000');
});

test('summaries are one sentence, no more than 20 words, and bounded even for giant tokens', () => {
  assert.equal(normalizeSummary('Summary: **Update** the deployment. Then restart everything.'), 'Update the deployment.');
  const summary = normalizeSummary(Array.from({ length: 50 }, (_, index) => `word${index}`).join(' '));
  assert.equal(summary.split(/\s+/).length, 20);
  assert.ok(summary.endsWith('word19.'));
  assert.equal(normalizeSummary(''), 'Summary unavailable; inspect the complete operation below.');
  assert.equal(normalizeSummary('x'.repeat(1000)), 'Summary unavailable; inspect the complete operation below.');
  assert.doesNotMatch(normalizeSummary('\x1b[2JPrint output.'), /\x1b/);
});

test('forwarded reviews identify the worker and working directory without mixing them into code', () => {
  const view = viewer({ ...longOperation, worker: { name: 'reviewer#123', cwd: '/project/worktree' } });
  const lines = view.render();
  assert.ok(lines.some((line) => line.includes('Worker: reviewer#123')));
  assert.ok(lines.some((line) => line.includes('Cwd: /project/worktree')));
  assert.ok(lines.some((line) => line.includes('operation line 01')));
  assert.ok(lines.some((line) => line.includes('[a] Allow')));
});

test('the pager shows syntax-highlighted content with pinned summary and approval controls', () => {
  const view = viewer();
  view.component.setSummary('Print operation progress lines without modifying files.');
  const initial = view.render();
  assert.equal(initial.length, 20);
  assert.ok(initial.some((line) => line.includes('🛡 | bash')));
  assert.ok(initial.some((line) => line.includes('Summary: Print operation progress')));
  assert.ok(initial.some((line) => line.includes('operation line 01')));
  assert.ok(initial.some((line) => line.includes('[a] Allow  [d/Esc] Deny')));
  assert.ok(!initial.some((line) => line.includes('FINAL_SENTINEL')));
  assert.ok(view.component.render(80).some((line) => /\x1b\[/.test(line) && line.includes('echo')));

  view.component.handleInput('G');
  const end = view.render();
  assert.ok(end.some((line) => line.includes('FINAL_SENTINEL')));
  assert.ok(end.some((line) => line.includes('Summary: Print operation progress')));
  assert.ok(end.some((line) => line.includes('[a] Allow  [d/Esc] Deny')));
  view.component.handleInput('g');
  assert.ok(view.render().some((line) => line.includes('operation line 01')));
});

test('title is centered, summary and actions have breathing room, and the navigation legend is hidden', () => {
  const view = viewer();
  view.component.setSummary('Update the deployment.');
  const rows = view.render();
  const title = rows.find((line) => line.includes('🛡 | bash'))!.slice(1, -1);
  const left = visibleWidth(title.match(/^\s*/)?.[0] ?? '');
  const right = visibleWidth(title.match(/\s*$/)?.[0] ?? '');
  assert.ok(Math.abs(left - right) <= 1);

  const summary = rows.findIndex((line) => line.includes('Summary: Update'));
  const actions = rows.findIndex((line) => line.includes('[a] Allow'));
  for (const index of [summary - 1, summary + 1, actions - 1]) {
    assert.equal(rows[index].slice(1, -1).trim(), '');
  }
  assert.ok(!rows.some((line) => line.includes('j/k')));
});

test('short TUI approvals show separate highlighted code and support direct a/d/Esc', async () => {
  for (const [key, expected] of [['a', true], ['d', false], ['\x1b', false]] as const) {
    const runtime = harness();
    const pending = createApprovalPrompt()({
      title: 'bash', content: 'printf "hello\\n"', language: 'bash', reason: 'Review this operation',
    }, runtime.ctx);
    await flush();
    assert.equal(runtime.requests.length, 0, 'short approvals do not spend a summary request');
    assert.equal(runtime.selections.length, 0);
    const rows = runtime.views[0].render(80);
    const plain = rows.map(stripTerminalSequences);
    assert.ok(plain.length < 23, 'compact card uses its natural content height');
    const title = plain.findIndex((line) => line.includes('🛡 | bash'));
    const code = plain.findIndex((line) => line.includes('printf'));
    assert.equal(plain[title + 1].slice(1, -1).trim(), '');
    assert.ok(code > title + 1);
    assert.ok(rows[code].includes('\x1b['));
    assert.ok(plain.some((line) => line.includes('Rule: Review this operation')));
    runtime.views[0].handleInput(key);
    assert.equal(await pending, expected);
  }
});

test('regular-mode mouse capture is enabled only while the approval dialog is open', async () => {
  const controller = new AbortController();
  const runtime = harness({ tuiMode: 'regular', signal: controller.signal });
  const pending = createApprovalPrompt()(longOperation, runtime.ctx);
  await flush();
  assert.deepEqual(runtime.terminalWrites, ['\x1b[?1000h\x1b[?1006h']);
  controller.abort();
  assert.equal(await pending, false);
  assert.deepEqual(runtime.terminalWrites, ['\x1b[?1000h\x1b[?1006h', '\x1b[?1006l\x1b[?1000l']);
});

test('scroll keys navigate without approving, including Ctrl-d versus d', () => {
  for (const key of ['j', '\x1b[B', '\x05', '\x04', '\x1b[6~', ' ']) {
    const view = viewer();
    view.render();
    view.component.handleInput(key);
    assert.ok(!view.render().some((line) => line.includes('operation line 01')), JSON.stringify(key));
    assert.deepEqual(view.decisions, []);
  }
  for (const key of ['k', '\x1b[A', '\x19', '\x15', '\x1b[5~']) {
    const view = viewer();
    view.render();
    view.component.handleInput('G');
    view.render();
    view.component.handleInput(key);
    assert.ok(!view.render().some((line) => line.includes('FINAL_SENTINEL')), JSON.stringify(key));
    assert.deepEqual(view.decisions, []);
  }
});

test('literal search jumps to matches, highlights them, and supports n/N', () => {
  const request = { ...longOperation, content: Array.from({ length: 70 }, (_, index) => index === 25 || index === 55 ? `needle.* match ${index}` : `line ${index}`).join('\n') };
  const view = viewer(request);
  view.render();
  view.component.handleInput('/');
  view.component.handleInput('needle.*');
  view.component.handleInput('\r');
  assert.ok(view.render().some((line) => line.includes('needle.* match 25')));
  assert.ok(view.component.render(80).some((line) => line.includes('\x1b[30;43mneedle.*')));
  view.component.handleInput('n');
  assert.ok(view.render().some((line) => line.includes('needle.* match 55')));
  view.component.handleInput('N');
  assert.ok(view.render().some((line) => line.includes('needle.* match 25')));
  assert.deepEqual(view.decisions, []);
});

test('search text cannot approve or deny, and Escape leaves search before denying', () => {
  const view = viewer();
  view.render();
  view.component.handleInput('/');
  view.component.handleInput('a');
  view.component.handleInput('d');
  view.component.handleInput('\x1b');
  assert.deepEqual(view.decisions, []);
  view.component.handleInput('\x1b');
  assert.deepEqual(view.decisions, [false]);
});

test('only explicit approval allows; Enter, pasted text, and keys after closing cannot approve', () => {
  for (const [key, expected] of [['a', true], ['d', false], ['\x1b', false], ['\x03', false]] as const) {
    const view = viewer();
    view.component.handleInput('\r');
    view.component.handleInput('\x1b[200~a\x1b[201~');
    assert.deepEqual(view.decisions, []);
    view.component.handleInput(key);
    view.component.handleInput('a');
    assert.deepEqual(view.decisions, [expected]);
  }
});

test('wrapping preserves the full long line; unwrapped search pans to an off-screen match', () => {
  const view = viewer({ title: 'bash', content: 'x'.repeat(180) + ' WIDE_TAIL', language: 'bash' });
  view.render(40);
  view.component.handleInput('G');
  assert.ok(view.render(40).some((line) => line.includes('WIDE_TAIL')));
  view.component.handleInput('w');
  view.render(40);
  view.component.handleInput('/');
  view.component.handleInput('WIDE_TAIL');
  view.component.handleInput('\r');
  assert.ok(view.render(40).some((line) => line.includes('WIDE_TAIL')));
  view.component.handleInput('h');
  view.component.handleInput('l');
  assert.deepEqual(view.decisions, []);
});

test('rendering fits narrow terminals and resize while keeping wide Unicode visible', () => {
  const view = viewer({ ...longOperation, content: ('界🙂 e\u0301 '.repeat(40) + '\n').repeat(8) });
  for (const width of [20, 40, 80, 120]) {
    for (const height of [8, 16, 28]) {
      view.resize(height);
      const rows = view.component.render(width);
      assert.equal(rows.length, height);
      assert.ok(rows.every((line) => visibleWidth(line) <= width), `${width}x${height}`);
      assert.ok(rows.map(stripTerminalSequences).some((line) => /Allow.*Deny/.test(line)));
      view.component.handleInput('G');
    }
  }
});

for (const Screen of [TuiMainScreen, TuiAltScreen]) {
  test(`native ${Screen.name}: overlay renders, routes keys, resizes, and restores focus`, () => {
    let input!: (data: string) => void;
    let resize!: () => void;
    const terminal: Terminal & { columns: number; rows: number } = {
      columns: 90, rows: 30, kittyProtocolActive: false,
      start: (onInput, onResize) => { input = onInput; resize = onResize; },
      stop() {}, drainInput: async () => {}, write() {}, moveBy() {}, hideCursor() {}, showCursor() {},
      clearLine() {}, clearFromCursor() {}, clearScreen() {}, setTitle() {}, setProgress() {},
    };
    const tui = new Screen(terminal);
    const editor = { focused: false, render: () => ['editor'], invalidate() {} };
    const decisions: boolean[] = [];
    let overlay: OverlayHandle | undefined;
    const component = new ApprovalViewer(longOperation, theme, () => Math.floor(terminal.rows * 0.9) - 2, () => tui.requestRender(), (allowed) => {
      decisions.push(allowed);
      tui.hideOverlay();
    }, { mouseBounds: () => overlay?.getBounds() });
    const screen = () => (tui instanceof TuiAltScreen ? tui.getScreenLines() : tui.captureRenderState().previousLines).map(stripTerminalSequences);
    tui.addChild(editor);
    tui.setFocus(editor);
    tui.start();
    try {
      overlay = tui.showOverlay(component, { width: '96%', maxHeight: '90%', margin: 1 });
      tui.renderNow(true);
      assert.equal(component.focused, true);
      assert.ok(screen().some((line) => line.includes('[a] Allow')));
      input('\x1b[<65;1;1M');
      tui.renderNow();
      assert.ok(screen().some((line) => line.includes('operation line 01')), 'wheel outside panel does not scroll it');
      const bounds = overlay.getBounds()!;
      const position = `${bounds.col + 3};${bounds.row + Math.floor(bounds.height / 2)}`;
      input(`\x1b[<65;${position}M`);
      tui.renderNow();
      assert.ok(!screen().some((line) => line.includes('operation line 01')), 'wheel inside panel scrolls down');
      input(`\x1b[<64;${position}M`);
      tui.renderNow();
      assert.ok(screen().some((line) => line.includes('operation line 01')), 'wheel inside panel scrolls up');
      input('G');
      tui.renderNow();
      assert.ok(screen().some((line) => line.includes('FINAL_SENTINEL')));

      terminal.columns = 44;
      terminal.rows = 16;
      resize();
      tui.renderNow(true);
      assert.ok(screen().some((line) => line.includes('Allow')));
      input('/');
      input('a');
      tui.renderNow();
      assert.deepEqual(decisions, []);
      input('\x1b');
      input('a');
      assert.deepEqual(decisions, [true]);
      assert.equal(editor.focused, true);
    } finally {
      tui.stop();
    }
  });
}

test('summary requests use the active model, full operation, low effort, and cancellation', async () => {
  const runtime = harness();
  const controller = new AbortController();
  const summary = await summarizeOperation(longOperation, runtime.ctx, controller.signal);
  assert.equal(summary, 'Print operation progress lines without changing files.');
  const request = runtime.requests[0];
  assert.equal(request.options.reasoning, 'low');
  assert.equal(request.options.cacheRetention, 'none');
  assert.equal(request.options.signal, controller.signal);
  assert.match(request.context.systemPrompt, /at most 20 words/);
  assert.equal(JSON.parse(request.context.messages[0].content[0].text).content, longOperation.content);
});

test('the viewer opens before its summary completes and closing aborts the summary', async () => {
  const runtime = harness({ delayedSummary: true });
  const approve = createApprovalPrompt();
  const pending = approve(longOperation, runtime.ctx);
  await flush();
  assert.equal(runtime.views.length, 1);
  assert.ok(runtime.views[0].render(80).map(stripTerminalSequences).some((line) => line.includes('Summarizing')));
  runtime.views[0].finish(true);
  assert.equal(await pending, true);
  assert.equal(runtime.requests[0].options.signal.aborted, true);
  const renders = runtime.renders();
  runtime.reply.resolve({ stopReason: 'stop', content: [{ type: 'text', text: 'Late summary.' }] });
  await flush();
  assert.equal(runtime.renders(), renders);
});

test('failed summaries and unavailable models leave review usable', async () => {
  for (const reply of [
    { stopReason: 'error', content: [] },
    { stopReason: 'stop', content: [] },
  ]) {
    const runtime = harness({ delayedSummary: true });
    const pending = createApprovalPrompt()(longOperation, runtime.ctx);
    await flush();
    runtime.reply.resolve(reply);
    await flush();
    assert.ok(runtime.views[0].render(80).map(stripTerminalSequences).some((line) => line.includes('Summary unavailable')));
    runtime.views[0].finish(false);
    assert.equal(await pending, false);
  }
  const runtime = harness();
  const ctx = { ...runtime.ctx, model: undefined };
  assert.equal(await summarizeOperation(longOperation, ctx, new AbortController().signal), 'Summary unavailable; inspect the complete operation below.');
  assert.equal(runtime.requests.length, 0);
});

test('compact and RPC prompts use the new separator and never truncate long content', async () => {
  const runtime = harness({ mode: 'rpc' });
  const approve = createApprovalPrompt();
  assert.equal(await approve({ title: 'bash', content: 'ls', language: 'bash' }, runtime.ctx), true);
  assert.equal(runtime.selections[0], '🛡 | bash\n\n```bash\nls\n```\n');
  assert.equal(runtime.views.length, 0);
  assert.equal(runtime.requests.length, 0);

  const rpc = harness({ mode: 'rpc' });
  assert.equal(await approve(longOperation, rpc.ctx), true);
  assert.ok(rpc.selections[0].includes('FINAL_SENTINEL'));
  const file = fileApproval('write', { path: '/x', content: longOperation.content }, '/x');
  assert.equal(await approve(file, rpc.ctx), true);
  assert.ok(rpc.selections[1].includes('FINAL_SENTINEL'));
  await approve(fileApproval('write', { path: '/x', content: 'SHORT_FILE_CONTENT' }, '/x'), rpc.ctx);
  assert.ok(rpc.selections[2].includes('SHORT_FILE_CONTENT'));
  assert.equal(rpc.views.length, 0);
  assert.equal(rpc.requests.length, 0);
});

test('headless and already-aborted requests never open a dialog', async () => {
  for (const options of [{ hasUI: false }, { signal: AbortSignal.abort() }]) {
    const runtime = harness(options);
    assert.equal(await createApprovalPrompt()(longOperation, runtime.ctx), false);
    assert.equal(runtime.views.length, 0);
    assert.equal(runtime.requests.length, 0);
  }
});

test('turn or extension shutdown cancels an open viewer and its summary', async () => {
  for (const kind of ['turn', 'shutdown']) {
    const controller = new AbortController();
    const runtime = harness({ delayedSummary: true, signal: kind === 'turn' ? controller.signal : undefined });
    const pending = createApprovalPrompt(kind === 'shutdown' ? controller.signal : undefined)(longOperation, runtime.ctx);
    await flush();
    controller.abort();
    assert.equal(await pending, false);
    assert.equal(runtime.requests[0].options.signal.aborted, true);
    runtime.reply.resolve({ stopReason: 'aborted', content: [] });
  }
});

test('a queued approval retains its original turn signal after the live context moves on', async () => {
  const runtime = harness();
  const approve = createApprovalPrompt();
  const first = approve(longOperation, runtime.ctx);
  const original = new AbortController();
  let liveSignal: AbortSignal | undefined = original.signal;
  const localContext = Object.create(runtime.ctx, { signal: { get: () => liveSignal } });
  const cancelled = approve(longOperation, localContext);
  await flush();
  original.abort();
  assert.equal(await cancelled, false);
  liveSignal = undefined;
  runtime.views[0].finish(false);
  assert.equal(await first, false);
  await flush();
  assert.equal(runtime.views.length, 1, 'a cancelled queued dialog must never reopen');

  const next = approve(longOperation, localContext);
  await flush();
  assert.equal(runtime.views.length, 2);
  runtime.views[1].finish(true);
  assert.equal(await next, true);
});

test('concurrent approvals are serialized and a cancelled queued request never opens', async () => {
  const runtime = harness();
  const approve = createApprovalPrompt();
  const first = approve(longOperation, runtime.ctx);
  const controller = new AbortController();
  const second = approve(longOperation, { ...runtime.ctx, signal: controller.signal });
  const third = approve(longOperation, runtime.ctx);
  await flush();
  assert.equal(runtime.views.length, 1);
  controller.abort();
  runtime.views[0].finish(false);
  assert.equal(await first, false);
  assert.equal(await second, false);
  await flush();
  assert.equal(runtime.views.length, 2);
  runtime.views[1].finish(true);
  assert.equal(await third, true);
});
