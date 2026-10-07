import assert from 'node:assert/strict';
import test from 'node:test';
import type { ExtensionAPI, ExtensionContext } from '@earendil-works/pi-coding-agent';
import { visibleWidth } from '@earendil-works/pi-tui';
import statusbar from './index.ts';

function harness() {
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
    sessionManager: { getCwd: () => '/project' },
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

test('shows Fast mode from pi-openai, without relying on provider usage reporting', async () => {
  const runtime = harness();
  await runtime.start();
  assert.ok(!runtime.render().includes(' · fast'));

  runtime.statuses.set('pi-openai', 'fast');
  assert.ok(runtime.render().includes('gpt-6.1-sol · high · fast · Test session'));

  runtime.statuses.delete('pi-openai');
  runtime.statuses.set('usage', 'codex fast 59%');
  assert.ok(!runtime.render().includes(' · fast'));
});

test('keeps Fast mode and safety indicators within narrow footer widths', async () => {
  const runtime = harness();
  await runtime.start();
  runtime.statuses.set('pi-openai', 'fast');
  runtime.statuses.set('pi-safety', '🛡 disabled');

  assert.ok(runtime.render().includes('🛡 disabled · 25%'));
  for (const width of [1, 10, 40, 80]) {
    assert.ok(visibleWidth(runtime.render(width)) <= width);
  }
});
