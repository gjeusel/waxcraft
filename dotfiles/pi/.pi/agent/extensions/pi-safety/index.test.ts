import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import safety from './index.ts';

async function setup(sandboxed: boolean) {
  const directory = mkdtempSync(join(tmpdir(), 'pi-safety-index-'));
  const configPath = join(directory, 'config.jsonc');
  writeFileSync(
    configPath,
    JSON.stringify({
      filesystem: { denyRead: [], denyWrite: [] },
      shell: { deny: [{ command: 'sudo', reason: 'sudo denied in test' }] },
    }),
  );

  const previous = {
    sandboxed: process.env.PI_SAFETY_SANDBOXED,
    config: process.env.PI_SAFETY_CONFIG,
  };
  if (sandboxed) process.env.PI_SAFETY_SANDBOXED = '1';
  else delete process.env.PI_SAFETY_SANDBOXED;
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
      if (previous.sandboxed === undefined) delete process.env.PI_SAFETY_SANDBOXED;
      else process.env.PI_SAFETY_SANDBOXED = previous.sandboxed;
      if (previous.config === undefined) delete process.env.PI_SAFETY_CONFIG;
      else process.env.PI_SAFETY_CONFIG = previous.config;
    },
  };
}

test('blocks every model tool when Pi bypasses the launcher', async () => {
  const { handlers, restore } = await setup(false);
  try {
    const result = await handlers.get('tool_call')!({ type: 'tool_call', toolName: 'read', input: { path: '/tmp/x' } });
    assert.equal(result.block, true);
    assert.match(result.reason, /not running under sandbox-exec/);
  } finally {
    restore();
  }
});

test('uses PI_SAFETY_CONFIG for shell rules and injects the rm shim only after approval', async () => {
  const { handlers, restore } = await setup(true);
  try {
    const toolCall = handlers.get('tool_call')!;
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

test('/no-safety disables shell checks but keeps rm/rmdir routing and Seatbelt active', async () => {
  const { commands, handlers, restore } = await setup(true);
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
    assert.match(statuses.at(-1) ?? '', /filesystem only/);
    assert.match(notifications.at(-1) ?? '', /rm\/rmdir-to-trash routing and filesystem Seatbelt remain active/);

    const event = { type: 'tool_call', toolName: 'bash', input: { command: 'sudo rm file.txt' } };
    assert.equal(await handlers.get('tool_call')!(event), undefined);
    assert.match(event.input.command, /^export PATH=.*pi-safety\/bin/);
    assert.match(event.input.command, /\nsudo rm file\.txt$/);
  } finally {
    restore();
  }
});
