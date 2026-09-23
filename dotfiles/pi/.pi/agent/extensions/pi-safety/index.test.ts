import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import safety from './index.ts';

async function setup(
  configText = JSON.stringify({ shell: { deny: [{ command: 'sudo', reason: 'sudo denied in test' }] } }),
) {
  const directory = mkdtempSync(join(tmpdir(), 'pi-safety-index-'));
  const configPath = join(directory, 'config.jsonc');
  writeFileSync(configPath, configText);
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

test('write and edit: deny and ask protected paths, other paths pass', async () => {
  const { handlers, restore } = await setup(
    JSON.stringify({ paths: { deny: ['/protected/**'], ask: ['**/.env'] } }),
  );
  const toolCall = handlers.get('tool_call')!;
  const confirmations: string[] = [];
  const context = (options: { hasUI: boolean; confirm: boolean }) => ({
    cwd: '/project',
    hasUI: options.hasUI,
    ui: {
      confirm: async (_title: string, message: string) => {
        confirmations.push(message);
        return options.confirm;
      },
    },
  });
  try {
    const writeTo = (path: string) => ({ type: 'tool_call', toolName: 'write', input: { path, content: 'x' } });
    const editOf = (path: string) => ({ type: 'tool_call', toolName: 'edit', input: { path, edits: [] } });

    const denied = await toolCall(writeTo('/protected/key'), context({ hasUI: true, confirm: true }));
    assert.equal(denied.block, true);
    assert.match(denied.reason, /write \/protected\/key is denied by protected path rule \/protected\/\*\*/);
    assert.equal(confirmations.length, 0);

    assert.equal(await toolCall(editOf('.env'), context({ hasUI: true, confirm: true })), undefined);
    assert.match(confirmations.at(-1) ?? '', /^edit \/project\/\.env\n\nMatches protected path rule \*\*\/\.env/);

    const declined = await toolCall(editOf('.env'), context({ hasUI: true, confirm: false }));
    assert.match(declined.reason, /the user declined edit \/project\/\.env/);

    const headless = await toolCall(writeTo('.env'), context({ hasUI: false, confirm: true }));
    assert.match(headless.reason, /needs user confirmation .* no UI/);

    assert.equal(await toolCall(writeTo('src/index.ts'), context({ hasUI: false, confirm: false })), undefined);
  } finally {
    restore();
  }
});

test('an invalid configuration disables Bash until /no-safety', async () => {
  const { commands, handlers, restore } = await setup(JSON.stringify({ shell: { deny: [{ command: 'sudo', typo: 1 }] } }));
  const statuses = new Map<string, string | undefined>();
  const notifications: string[] = [];
  const ctx = {
    ui: {
      setStatus: (name: string, status: string | undefined) => statuses.set(name, status),
      notify: (message: string) => notifications.push(message),
    },
  };
  try {
    await handlers.get('session_start')!({}, ctx);
    assert.equal(statuses.get('pi-safety'), '\u{1F6E1} config invalid');
    assert.match(notifications.at(-1) ?? '', /unknown property "typo".*Bash, write, and edit are disabled until it is fixed/);

    const toolCall = handlers.get('tool_call')!;
    const blocked = await toolCall({ type: 'tool_call', toolName: 'bash', input: { command: 'echo ok' } });
    assert.equal(blocked.block, true);
    assert.match(blocked.reason, /invalid .*config\.jsonc/);
    const blockedWrite = await toolCall(
      { type: 'tool_call', toolName: 'write', input: { path: '/tmp/x', content: '' } },
      { cwd: '/', hasUI: false },
    );
    assert.match(blockedWrite.reason, /Bash, write, and edit are disabled/);

    await commands.get('no-safety')!.handler('', ctx);
    assert.equal(statuses.get('pi-safety'), '\u{1F6E1} disabled');
    assert.equal(await toolCall({ type: 'tool_call', toolName: 'bash', input: { command: 'echo ok' } }), undefined);
  } finally {
    restore();
  }
});

test('a valid configuration clears the footer status', async () => {
  const { handlers, restore } = await setup();
  const statuses = new Map<string, string | undefined>();
  const ctx = { ui: { setStatus: (name: string, status: string | undefined) => statuses.set(name, status), notify() {} } };
  try {
    await handlers.get('session_start')!({}, ctx);
    assert.ok(statuses.has('pi-safety'));
    assert.equal(statuses.get('pi-safety'), undefined);
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
    assert.match(notifications.at(-1) ?? '', /shell command and protected-path checks are disabled/);
    const event = { type: 'tool_call', toolName: 'bash', input: { command: 'sudo rm file.txt' } };
    assert.equal(await handlers.get('tool_call')!(event), undefined);
    assert.match(event.input.command, /^export PATH=.*pi-safety\/bin/);
    assert.match(event.input.command, /\nsudo rm file\.txt$/);
  } finally {
    restore();
  }
});

function jevFetch(choice: string, confidence: number): typeof fetch {
  return async () =>
    new Response(
      JSON.stringify({
        answers: { verdict: { type: 'choice', choice, probabilities: { [choice]: 1 }, confidence } },
      }),
    );
}

function autoModeContext(options: { hasUI: boolean; confirm?: boolean }) {
  const statuses = new Map<string, string | undefined>();
  const notifications: string[] = [];
  const confirmations: string[] = [];
  return {
    statuses,
    notifications,
    confirmations,
    ctx: {
      hasUI: options.hasUI,
      signal: undefined,
      sessionManager: { getBranch: () => [] },
      ui: {
        setStatus: (name: string, status: string | undefined) => statuses.set(name, status),
        notify: (message: string) => notifications.push(message),
        confirm: async (_title: string, message: string) => {
          confirmations.push(message);
          return options.confirm ?? false;
        },
      },
    },
  };
}

test('/toggle-auto-mode requires the API key', async () => {
  const { commands, restore } = await setup();
  const previousKey = process.env.TYPESAFE_AI_API_KEY;
  delete process.env.TYPESAFE_AI_API_KEY;
  const { ctx, statuses, notifications } = autoModeContext({ hasUI: true });
  try {
    await commands.get('toggle-auto-mode')!.handler('', ctx);
    assert.match(notifications.at(-1) ?? '', /TYPESAFE_AI_API_KEY/);
    assert.equal(statuses.has('auto-mode'), false);
  } finally {
    if (previousKey !== undefined) process.env.TYPESAFE_AI_API_KEY = previousKey;
    restore();
  }
});

test('auto mode gates Bash through jev and toggles the footer status', async () => {
  const { commands, handlers, restore } = await setup();
  const previousKey = process.env.TYPESAFE_AI_API_KEY;
  const previousFetch = globalThis.fetch;
  process.env.TYPESAFE_AI_API_KEY = 'test-key';
  const toolCall = handlers.get('tool_call')!;
  const toggle = commands.get('toggle-auto-mode')!.handler;
  try {
    const { ctx, statuses, notifications, confirmations } = autoModeContext({ hasUI: true, confirm: false });
    await toggle('', ctx);
    assert.equal(statuses.get('auto-mode'), 'auto-mode');

    // Deterministic rules still run first: no classifier call for a denied command.
    globalThis.fetch = async () => {
      throw new Error('classifier must not be called');
    };
    const ruleDenied = await toolCall({ type: 'tool_call', toolName: 'bash', input: { command: 'sudo ls' } }, ctx);
    assert.match(ruleDenied.reason, /sudo denied in test/);

    globalThis.fetch = jevFetch('allow', 0.95);
    const allowed = { type: 'tool_call', toolName: 'bash', input: { command: 'ls' } };
    assert.equal(await toolCall(allowed, ctx), undefined);
    assert.match(allowed.input.command, /\nls$/);

    globalThis.fetch = jevFetch('deny', 0.95);
    const denied = await toolCall({ type: 'tool_call', toolName: 'bash', input: { command: 'cat ~/.ssh/id_ed25519' } }, ctx);
    assert.equal(denied.block, true);
    assert.match(denied.reason, /auto mode denied: jev: deny 100%/);
    assert.match(notifications.at(-1) ?? '', /auto mode blocked/);

    globalThis.fetch = jevFetch('ask', 0.95);
    const declined = await toolCall({ type: 'tool_call', toolName: 'bash', input: { command: 'rm -rf build' } }, ctx);
    assert.equal(declined.block, true);
    assert.match(declined.reason, /user declined/);
    assert.match(confirmations.at(-1) ?? '', /^rm -rf build\n\njev: ask 100%/);

    // Low confidence and classifier failures both become a confirmation the user can accept.
    const accepting = autoModeContext({ hasUI: true, confirm: true });
    globalThis.fetch = jevFetch('deny', 0.2);
    const lowConfidence = { type: 'tool_call', toolName: 'bash', input: { command: 'git push' } };
    assert.equal(await toolCall(lowConfidence, accepting.ctx), undefined);
    assert.match(accepting.confirmations.at(-1) ?? '', /below confidence floor 50%/);

    globalThis.fetch = async () => new Response('overloaded', { status: 529 });
    const unavailable = { type: 'tool_call', toolName: 'bash', input: { command: 'ls' } };
    assert.equal(await toolCall(unavailable, accepting.ctx), undefined);
    assert.match(accepting.confirmations.at(-1) ?? '', /classifier unavailable \(jev 529/);

    // Without a UI, ask degrades to a block.
    const headless = autoModeContext({ hasUI: false });
    globalThis.fetch = jevFetch('ask', 0.95);
    const blocked = await toolCall({ type: 'tool_call', toolName: 'bash', input: { command: 'ls' } }, headless.ctx);
    assert.match(blocked.reason, /no UI to confirm/);
    assert.equal(headless.confirmations.length, 0);

    await toggle('', ctx);
    assert.equal(statuses.get('auto-mode'), undefined);
    globalThis.fetch = async () => {
      throw new Error('classifier must not be called');
    };
    assert.equal(await toolCall({ type: 'tool_call', toolName: 'bash', input: { command: 'ls' } }, ctx), undefined);
  } finally {
    globalThis.fetch = previousFetch;
    if (previousKey === undefined) delete process.env.TYPESAFE_AI_API_KEY;
    else process.env.TYPESAFE_AI_API_KEY = previousKey;
    restore();
  }
});
