import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import safety from './index.ts';

async function setup() {
  const directory = mkdtempSync(join(tmpdir(), 'pi-safety-index-'));
  const configPath = join(directory, 'config.jsonc');
  writeFileSync(configPath, JSON.stringify({ shell: { deny: [{ command: 'sudo', reason: 'sudo denied in test' }] } }));
  const previousConfig = process.env.PI_SAFETY_CONFIG;
  process.env.PI_SAFETY_CONFIG = configPath;

  const handlers = new Map<string, (...args: any[]) => any>();
  const commands = new Map<string, { handler: (args: string, ctx: any) => Promise<void> }>();
  await safety({
    on: (event: string, handler: (...args: any[]) => any) => handlers.set(event, handler),
    registerCommand: (name: string, command: { handler: (args: string, ctx: any) => Promise<void> }) =>
      commands.set(name, command),
  } as any);

  return {
    handlers,
    commands,
    restore() {
      if (previousConfig === undefined) delete process.env.PI_SAFETY_CONFIG;
      else process.env.PI_SAFETY_CONFIG = previousConfig;
    },
  };
}

test('checks Bash calls and ignores other tools', async () => {
  const { handlers, restore } = await setup();
  try {
    const toolCall = handlers.get('tool_call')!;
    assert.equal(await toolCall({ type: 'tool_call', toolName: 'read', input: { path: '/tmp/x' } }), undefined);

    const denied = await toolCall({ type: 'tool_call', toolName: 'bash', input: { command: 'sudo echo nope' } });
    assert.equal(denied.block, true);
    assert.match(denied.reason, /sudo denied in test/);

    const allowedEvent = { type: 'tool_call', toolName: 'bash', input: { command: 'echo ok' } };
    assert.equal(await toolCall(allowedEvent), undefined);
    assert.match(allowedEvent.input.command, /^export PATH=.*pi-safety\/bin/);
    assert.match(allowedEvent.input.command, /\necho ok$/);
  } finally {
    restore();
  }
});

test('/no-safety disables shell checks', async () => {
  const { commands, handlers, restore } = await setup();
  const statuses: string[] = [];
  const notifications: string[] = [];
  const ctx = {
    ui: {
      setStatus: (_name: string, status: string) => statuses.push(status),
      notify: (message: string) => notifications.push(message),
    },
  };
  try {
    await commands.get('no-safety')!.handler('', ctx);
    assert.equal(statuses.at(-1), '🛡 disabled');
    assert.match(notifications.at(-1) ?? '', /shell command checks are disabled/);
    const event = { type: 'tool_call', toolName: 'bash', input: { command: 'sudo rm file.txt' } };
    assert.equal(await handlers.get('tool_call')!(event), undefined);
    assert.match(event.input.command, /^export PATH=.*pi-safety\/bin/);
    assert.match(event.input.command, /\nsudo rm file\.txt$/);
  } finally {
    restore();
  }
});
