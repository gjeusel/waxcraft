import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import type { ExtensionAPI, ExtensionContext } from '@earendil-works/pi-coding-agent';
import { visibleWidth } from '@earendil-works/pi-tui';
import statusbar, { isLinkedWorktree } from './index.ts';

function harness(cwd = '/project') {
  const statuses = new Map<string, string>();
  let start!: (event: unknown, ctx: ExtensionContext) => Promise<void>;
  let render!: (width: number) => string[];
  const pi = {
    on: (_event: string, handler: typeof start) => { start = handler; },
    getSessionName: () => 'Test session',
  } as unknown as ExtensionAPI;
  const ctx = {
    model: { id: 'gpt-6.1-sol' },
    thinkingLevel: 'high',
    sessionManager: { getCwd: () => cwd },
    getContextUsage: () => ({ percent: 25 }),
    ui: {
      setFooter(factory: (
        tui: unknown,
        theme: { fg: (color: string, value: string) => string },
        data: { getExtensionStatuses: () => Map<string, string> },
      ) => { render: typeof render }) {
        render = factory(undefined, { fg: (_color, text) => text }, {
          getExtensionStatuses: () => statuses,
        }).render;
      },
    },
  } as unknown as ExtensionContext;

  statusbar(pi);

  return { statuses, start: () => start({}, ctx), render: (width = 120) => render(width)[0] };
}

test('shows Fast mode from pi-model-controls, without relying on provider usage reporting', async () => {
  const runtime = harness();
  await runtime.start();
  assert.ok(!runtime.render().includes(' · fast'));

  runtime.statuses.set('pi-model-controls', 'fast');
  assert.ok(runtime.render().includes('gpt-6.1-sol · high · fast · Test session'));
  runtime.statuses.set('pi-model-controls', 'ultrafast');
  assert.ok(runtime.render().includes('gpt-6.1-sol · high · ultrafast · Test session'));

  runtime.statuses.delete('pi-model-controls');
  runtime.statuses.set('usage', 'codex fast 59%');
  assert.ok(!runtime.render().includes(' · fast'));
});

test('keeps Fast mode and safety indicators within narrow footer widths', async () => {
  const runtime = harness();
  await runtime.start();
  runtime.statuses.set('pi-model-controls', 'fast');
  runtime.statuses.set('pi-safety', '🛡 disabled');

  assert.ok(runtime.render().includes('🛡 disabled · 25%'));
  for (const speed of ['fast', 'ultrafast']) {
    runtime.statuses.set('pi-model-controls', speed);
    for (const width of [1, 10, 40, 80]) {
      assert.ok(visibleWidth(runtime.render(width)) <= width);
    }
  }
});

test('hides the session name, the branch of a fired agent, in a linked worktree', async () => {
  const root = mkdtempSync(join(tmpdir(), 'statusbar-'));
  const main = join(root, 'main');
  const worktree = join(root, 'feature');
  execFileSync('git', ['init', '--quiet', main]);
  execFileSync('git', ['-C', main, '-c', 'user.name=t', '-c', 'user.email=t@t', 'commit', '--quiet', '--allow-empty', '-m', 'init']);
  execFileSync('git', ['-C', main, 'worktree', 'add', '--quiet', worktree]);

  assert.equal(isLinkedWorktree(main), false);
  assert.equal(isLinkedWorktree(worktree), true);

  const inMain = harness(main);
  await inMain.start();
  assert.ok(inMain.render().includes('gpt-6.1-sol · high · Test session'));

  const inWorktree = harness(worktree);
  await inWorktree.start();
  assert.ok(!inWorktree.render().includes('Test session'));
  assert.ok(inWorktree.render().includes('gpt-6.1-sol · high'));
});
