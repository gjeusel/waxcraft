import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { initTheme, SessionManager } from '@earendil-works/pi-coding-agent';
import { stripTerminalSequences } from '@earendil-works/pi-tui';
import { AUTO_MODE_SOURCES, type AutoModeSource } from './auto-mode.ts';
import safety from './index.ts';
import { withWorkerParent } from './session-state.ts';

async function setup(
  configText = JSON.stringify({ shell: { deny: [{ command: 'sudo', reason: 'sudo denied in test' }] } }),
  env: Record<string, string | undefined> = { PI_AUTO_MODE: '0' },
) {
  const directory = mkdtempSync(join(tmpdir(), 'pi-safety-index-'));
  const configPath = join(directory, 'config.jsonc');
  writeFileSync(configPath, configText);
  const testEnv = { PI_AUTO_MODE: undefined, OPENAI_API_KEY: undefined, TYPESAFE_AI_API_KEY: undefined, ...env, PI_SAFETY_CONFIG: configPath };
  const previousEnv = Object.fromEntries(Object.keys(testEnv).map((key) => [key, process.env[key]]));
  for (const [key, value] of Object.entries(testEnv)) {
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }

  const sessionManager = SessionManager.inMemory(directory);
  const handlers = new Map<string, (...args: any[]) => any>();
  const commands = new Map<string, { handler: (args: string, ctx: any) => Promise<void> }>();
  await safety({
    on: (event: string, handler: (...args: any[]) => any) => handlers.set(event, (data: any, ctx: any) =>
      handler(data, Object.create(ctx ?? null, { sessionManager: { value: ctx?.sessionManager ?? sessionManager } }))),
    registerCommand: (name: string, command: { handler: (args: string, ctx: any) => Promise<void> }) =>
      commands.set(name, command),
  } as any);

  return {
    handlers,
    commands,
    restore() {
      handlers.get('session_shutdown')?.({});
      for (const [key, value] of Object.entries(previousEnv)) {
        if (value === undefined) delete process.env[key];
        else process.env[key] = value;
      }
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
  const context = (options: { hasUI: boolean; confirm?: boolean }) => ({
    cwd: '/project',
    hasUI: options.hasUI,
    ui: {
      select: async (title: string, choices: string[]) => {
        confirmations.push(title);
        assert.deepEqual(choices, ['Allow', 'Deny']);
        if (options.confirm === undefined) return undefined;

        return options.confirm ? 'Allow' : 'Deny';
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
    assert.equal(confirmations.at(-1), '🛡 edit /project/.env\n\n```diff\n--- /project/.env\n+++ /project/.env\n```\n\nRule: Matches protected path rule **/.env\n');

    const declined = await toolCall(editOf('.env'), context({ hasUI: true, confirm: false }));
    assert.match(declined.reason, /the user declined edit \/project\/\.env/);

    const cancelled = await toolCall(writeTo('.env'), context({ hasUI: true }));
    assert.equal(confirmations.at(-1), '🛡 write /project/.env\n\n```\nx\n```\n\nRule: Matches protected path rule **/.env\n');
    assert.equal(cancelled.block, true);
    assert.match(cancelled.reason, /the user declined write \/project\/\.env/);

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

function decisionFetch(source: AutoModeSource, choice: string, confidence: number): typeof fetch {
  const probabilities = { allow: 0, ask: 0, deny: 0, [choice]: 1 };
  const answer = { type: 'choice', choice, probabilities, confidence };
  const response = source === 'jev' ? { answers: { verdict: answer } } : {
    answers: [{
      ...answer,
      name: 'verdict',
      probabilities: Object.entries(probabilities).map(([value, probability]) => ({ value, probability })),
    }],
  };

  return async () => new Response(JSON.stringify(response));
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
      cwd: '/project',
      mode: 'rpc',
      hasUI: options.hasUI,
      signal: undefined,
      sessionManager: SessionManager.inMemory('/project'),
      ui: {
        setStatus: (name: string, status: string | undefined) => statuses.set(name, status),
        notify: (message: string) => notifications.push(message),
        select: async (title: string, choices: string[]) => {
          confirmations.push(title);
          assert.deepEqual(choices, ['Allow', 'Deny']);
          assert.doesNotMatch(title, /Allow execution\?|Auto mode: confirm/);
          if (options.confirm === undefined) return undefined;

          return options.confirm ? 'Allow' : 'Deny';
        },
      },
    },
  };
}

for (const enabled of [false, true]) {
  test(`shipped infra rules: auto mode ${enabled ? 'on asks' : 'off denies'}`, async (t) => {
    const config = readFileSync(new URL('../../pi-safety.jsonc', import.meta.url), 'utf8');
    const { handlers, commands, restore } = await setup(config, {
      PI_AUTO_MODE: enabled ? '1' : '0', OPENAI_API_KEY: 'test-key',
    });
    const accepting = autoModeContext({ hasUI: true, confirm: true });
    const toolCall = handlers.get('tool_call')!;
    let requests = 0;
    let classifierChoice = 'allow';
    t.mock.method(globalThis, 'fetch', (url: string, init: RequestInit) => {
      requests += 1;
      return decisionFetch('openai', classifierChoice, 1)(url, init);
    });
    try {
      for (const command of [
        'kubectl apply -f deployment.yaml', 'kubectl delete pod worker', 'kubectl edit deployment worker',
        'kubectl patch deployment worker --patch {}', 'kubectl scale deployment worker --replicas=3',
        'kubectl drain node-1', 'kubectl cordon node-1', 'kubectl uncordon node-1',
        'kubectl taint nodes node-1 key=value:NoSchedule', 'kubectl replace -f deployment.yaml',
        'kubectl create namespace staging', 'kubectl set image deployment/worker worker=image:v2',
        'kubectl annotate pod worker owner=me', 'kubectl label pod worker app=worker',
        'kubectl exec worker -- sh', 'kubectl rollout pause deployment/worker',
        'kubectl rollout restart deployment/worker', 'kubectl rollout resume deployment/worker',
        'kubectl rollout undo deployment/worker', 'helm install worker ./chart',
        'helm upgrade worker ./chart', 'helm uninstall worker', 'helm delete worker', 'helm rollback worker 1',
      ]) {
        const event = { type: 'tool_call', toolName: 'bash', input: { command } };
        const result = await toolCall(event, accepting.ctx);
        if (enabled) {
          assert.equal(result, undefined, command);
          assert.ok(accepting.confirmations.at(-1)?.startsWith(`🛡 bash\n\n\`\`\`bash\n${command}\n\`\`\``));
          assert.ok(event.input.command.endsWith(command));
        } else {
          assert.equal(result.block, true, command);
          assert.equal(event.input.command, command);
        }
      }
      assert.equal(requests, accepting.confirmations.length, 'a classifier allow must still require infra approval');

      for (const options of [
        { hasUI: true, confirm: false },
        { hasUI: true },
        { hasUI: false, confirm: true },
      ]) {
        const rejecting = autoModeContext(options);
        const result = await toolCall(
          { type: 'tool_call', toolName: 'bash', input: { command: 'kubectl apply -f deployment.yaml' } },
          rejecting.ctx,
        );
        assert.equal(result.block, true);
      }

      // Other hard rules still win, even when combined with an infra command.
      const beforeHardRules = requests;
      for (const command of ['sudo ls', 'kubectl apply -f deployment.yaml; sudo ls', 'kubectl apply -f d; /bin/rm x']) {
        const before = accepting.confirmations.length;
        const result = await toolCall({ type: 'tool_call', toolName: 'bash', input: { command } }, accepting.ctx);
        assert.equal(result.block, true, command);
        assert.equal(accepting.confirmations.length, before);
      }
      assert.equal(requests, beforeHardRules);

      const before = accepting.confirmations.length;
      for (const command of ['kubectl get pods', 'kubectl logs worker', 'kubectl rollout status deployment/worker', 'helm list']) {
        assert.equal(await toolCall({ type: 'tool_call', toolName: 'bash', input: { command } }, accepting.ctx), undefined);
      }
      assert.equal(accepting.confirmations.length, before);
      assert.equal(requests, beforeHardRules + (enabled ? 4 : 0));

      if (enabled) {
        // A known infra ask must not mask a classifier denial of the full command.
        classifierChoice = 'deny';
        const denied = await toolCall(
          { type: 'tool_call', toolName: 'bash', input: { command: 'kubectl apply -f deployment.yaml; cat ~/.ssh/id_ed25519' } },
          accepting.ctx,
        );
        assert.equal(denied.block, true);
        assert.match(denied.reason, /auto mode denied/);
        assert.equal(accepting.confirmations.length, before);

        await commands.get('toggle-auto-mode')!.handler('', accepting.ctx);
        const result = await toolCall(
          { type: 'tool_call', toolName: 'bash', input: { command: 'kubectl apply -f deployment.yaml' } },
          accepting.ctx,
        );
        assert.equal(result.block, true, 'toggling off restores the hard deny');
        assert.equal(accepting.confirmations.length, before);
      }
    } finally {
      restore();
    }
  });
}

for (const source of AUTO_MODE_SOURCES) {
  const apiKeyEnv = source === 'jev' ? 'TYPESAFE_AI_API_KEY' : 'OPENAI_API_KEY';
  const config = JSON.stringify({
    shell: { deny: [{ command: 'sudo', reason: 'sudo denied in test' }] },
    autoMode: { source, minConfidence: 0.5 },
  });

  test(`${source}: permissive defaults allow uncertain work but preserve asks and denials`, async (t) => {
    const { handlers, restore } = await setup(
      JSON.stringify({ autoMode: { source } }),
      { [apiKeyEnv]: 'test-key' },
    );
    const { ctx, confirmations } = autoModeContext({ hasUI: false });
    const toolCall = handlers.get('tool_call')!;
    let choice = 'allow';
    t.mock.method(globalThis, 'fetch', (url: string, init: RequestInit) => decisionFetch(source, choice, 0)(url, init));
    try {
      const event = () => ({ type: 'tool_call', toolName: 'bash', input: { command: 'npm install' } });
      assert.equal(await toolCall(event(), ctx), undefined);

      choice = 'ask';
      const ask = await toolCall(event(), ctx);
      assert.equal(ask.block, true);
      assert.match(ask.reason, /no UI to confirm/);

      choice = 'deny';
      const deny = await toolCall(event(), ctx);
      assert.equal(deny.block, true);
      assert.match(deny.reason, /auto mode denied/);
      assert.equal(confirmations.length, 0);
    } finally {
      restore();
    }
  });

  test(`${source}: /toggle-auto-mode requires the selected backend's API key`, async () => {
    const otherKey = source === 'jev' ? 'OPENAI_API_KEY' : 'TYPESAFE_AI_API_KEY';
    const { commands, restore } = await setup(config, { PI_AUTO_MODE: '0', [otherKey]: 'other-key' });
    const { ctx, statuses, notifications } = autoModeContext({ hasUI: true });
    try {
      await commands.get('toggle-auto-mode')!.handler('', ctx);
      assert.ok(notifications.at(-1)?.includes(apiKeyEnv));
      assert.equal(statuses.has('auto-mode'), false);
    } finally {
      restore();
    }
  });

  test(`${source}: auto mode gates Bash and toggles the footer status`, async () => {
    const { commands, handlers, restore } = await setup(config, { [apiKeyEnv]: 'test-key' });
    const previousFetch = globalThis.fetch;
    const toolCall = handlers.get('tool_call')!;
    const toggle = commands.get('toggle-auto-mode')!.handler;
    try {
      const { ctx, statuses, notifications, confirmations } = autoModeContext({ hasUI: true, confirm: false });
      await handlers.get('session_start')!({}, ctx);
      assert.equal(statuses.get('auto-mode'), 'auto-mode');

      // Deterministic rules still run first: no classifier call for a denied command.
      globalThis.fetch = async () => {
        throw new Error('classifier must not be called');
      };
      const ruleDenied = await toolCall({ type: 'tool_call', toolName: 'bash', input: { command: 'sudo ls' } }, ctx);
      assert.match(ruleDenied.reason, /sudo denied in test/);

      globalThis.fetch = decisionFetch(source, 'allow', 0.95);
      const allowed = { type: 'tool_call', toolName: 'bash', input: { command: 'ls' } };
      assert.equal(await toolCall(allowed, ctx), undefined);
      assert.match(allowed.input.command, /\nls$/);

      globalThis.fetch = decisionFetch(source, 'deny', 0.95);
      const denied = await toolCall({ type: 'tool_call', toolName: 'bash', input: { command: 'cat ~/.ssh/id_ed25519' } }, ctx);
      assert.equal(denied.block, true);
      assert.match(denied.reason, new RegExp(`auto mode denied: ${source}: deny 100%`));
      assert.equal(confirmations.length, 0);
      assert.match(notifications.at(-1) ?? '', /auto mode blocked/);

      globalThis.fetch = decisionFetch(source, 'ask', 0.95);
      const declined = await toolCall({ type: 'tool_call', toolName: 'bash', input: { command: 'rm -rf build' } }, ctx);
      assert.equal(declined.block, true);
      assert.match(declined.reason, /user declined/);
      assert.equal(confirmations.at(-1), `🛡 bash\n\n\`\`\`bash\nrm -rf build\n\`\`\`\n\nRule: ${source}: ask 100% (confidence 95%; allow 0%, deny 0%)\n`);

      const cancelled = await toolCall(
        { type: 'tool_call', toolName: 'bash', input: { command: 'ls' } },
        autoModeContext({ hasUI: true }).ctx,
      );
      assert.equal(cancelled.block, true);
      assert.match(cancelled.reason, /user declined/);

      // Low confidence and classifier failures both become a confirmation the user can accept.
      const accepting = autoModeContext({ hasUI: true, confirm: true });
      globalThis.fetch = decisionFetch(source, 'deny', 0.2);
      const lowConfidence = { type: 'tool_call', toolName: 'bash', input: { command: 'git push' } };
      assert.equal(await toolCall(lowConfidence, accepting.ctx), undefined);
      assert.match(accepting.confirmations.at(-1) ?? '', /below confidence floor 50%/);

      globalThis.fetch = async () => new Response('overloaded', { status: 529 });
      const unavailable = { type: 'tool_call', toolName: 'bash', input: { command: 'ls' } };
      assert.equal(await toolCall(unavailable, accepting.ctx), undefined);
      assert.ok(accepting.confirmations.at(-1)?.includes(`classifier unavailable (${source} 529`));

      const headlessFailure = autoModeContext({ hasUI: false });
      const failed = await toolCall({ type: 'tool_call', toolName: 'bash', input: { command: 'ls' } }, headlessFailure.ctx);
      assert.match(failed.reason, /no UI to confirm/);
      assert.equal(headlessFailure.confirmations.length, 0);

      // Without a UI, ask degrades to a block.
      const headless = autoModeContext({ hasUI: false });
      globalThis.fetch = decisionFetch(source, 'ask', 0.95);
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
      restore();
    }
  });
}

for (const { enabled, envOverride, expected } of [
  { enabled: undefined, envOverride: undefined, expected: true },
  { enabled: false, envOverride: undefined, expected: false },
  { enabled: true, envOverride: '0', expected: false },
  { enabled: false, envOverride: '1', expected: true },
]) {
  test(`${JSON.stringify({ enabled, envOverride })}: startup enablement and default OpenAI routing`, async (t) => {
    const { handlers, restore } = await setup(
      JSON.stringify({ autoMode: { enabled } }),
      { PI_AUTO_MODE: envOverride, OPENAI_API_KEY: ' openai-key ', TYPESAFE_AI_API_KEY: 'jev-key' },
    );
    const { ctx, statuses } = autoModeContext({ hasUI: false });
    let requests = 0;
    t.mock.method(globalThis, 'fetch', async (url: string, init: RequestInit) => {
      requests += 1;
      assert.equal(url, 'https://api.openai.com/v1/decisions');
      assert.equal((init.headers as Record<string, string>).authorization, 'Bearer openai-key');
      const body = JSON.parse(init.body as string);
      assert.equal(body.input, 'bash: ls');
      assert.equal(body.model, 'gpt-6-luna');
      return decisionFetch('openai', 'allow', 0.95)(url, init);
    });
    try {
      await handlers.get('session_start')!({}, ctx);
      assert.equal(statuses.get('auto-mode'), expected ? 'auto-mode' : undefined);
      const event = { type: 'tool_call', toolName: 'bash', input: { command: 'ls' } };
      assert.equal(await handlers.get('tool_call')!(event, ctx), undefined);
      assert.equal(requests, expected ? 1 : 0);
      assert.match(event.input.command, /\nls$/);
    } finally {
      restore();
    }
  });
}

for (const source of AUTO_MODE_SOURCES) {
  test(`${source}: a missing key never silently disables auto mode`, async (t) => {
    const apiKeyEnv = source === 'jev' ? 'TYPESAFE_AI_API_KEY' : 'OPENAI_API_KEY';
    const otherKey = source === 'jev' ? 'OPENAI_API_KEY' : 'TYPESAFE_AI_API_KEY';
    const { commands, handlers, restore } = await setup(
      JSON.stringify({ autoMode: { source } }),
      { [apiKeyEnv]: '  ', [otherKey]: 'other-key' },
    );
    const { ctx, statuses, notifications, confirmations } = autoModeContext({ hasUI: true, confirm: true });
    let requests = 0;
    t.mock.method(globalThis, 'fetch', async () => {
      requests += 1;
      throw new Error('must not call either provider');
    });
    try {
      await handlers.get('session_start')!({}, ctx);
      assert.equal(statuses.get('auto-mode'), 'auto-mode');
      assert.ok(notifications.at(-1)?.includes(apiKeyEnv));

      // /no-safety disables deterministic checks, not the separate auto-mode gate.
      await commands.get('no-safety')!.handler('', ctx);
      const event = { type: 'tool_call', toolName: 'bash', input: { command: 'ls' } };
      const blocked = await handlers.get('tool_call')!(event, ctx);
      assert.equal(blocked.block, true);
      assert.ok(blocked.reason.includes(apiKeyEnv));
      assert.equal(event.input.command, 'ls');
      assert.equal(confirmations.length, 0);

      await commands.get('toggle-auto-mode')!.handler('', ctx);
      assert.equal(statuses.get('auto-mode'), undefined);
      assert.equal(await handlers.get('tool_call')!(event, ctx), undefined);
      assert.equal(requests, 0);
    } finally {
      restore();
    }
  });
}

test('long Bash, write, and edit approvals reach the native pager without truncation', async (t) => {
  initTheme('dark', false);
  const { handlers, restore } = await setup(
    JSON.stringify({ paths: { ask: ['**/.env'] } }),
    { OPENAI_API_KEY: 'test-key' },
  );
  t.mock.method(globalThis, 'fetch', decisionFetch('openai', 'ask', 0.95));
  const screens: string[][] = [];
  const base = autoModeContext({ hasUI: true });
  const ctx = {
    ...base.ctx, cwd: '/project', mode: 'tui',
    ui: {
      ...base.ctx.ui,
      custom: (factory: (...args: any[]) => any) => new Promise<boolean>((done) => {
        const theme = { fg: (_color: string, text: string) => text, style: (text: string) => text };
        const component = factory({ terminal: { rows: 28 }, requestRender() {} }, theme, {}, done);
        component.render(100);
        component.handleInput('G');
        screens.push(component.render(100).map(stripTerminalSequences));
        component.handleInput('d');
      }),
    },
  };
  const body = Array.from({ length: 50 }, (_, index) => `echo line${index}`).join('\\n');
  try {
    const toolCall = handlers.get('tool_call')!;
    for (const [toolName, input, tail] of [
      ['bash', { command: body + '\\necho BASH_REVIEW_TAIL' }, 'BASH_REVIEW_TAIL'],
      ['write', { path: '.env', content: body + '\\nWRITE_REVIEW_TAIL' }, 'WRITE_REVIEW_TAIL'],
      ['edit', { path: '.env', edits: [{ oldText: body, newText: body + '\\nEDIT_REVIEW_TAIL' }] }, 'EDIT_REVIEW_TAIL'],
    ] as const) {
      const result = await toolCall({ type: 'tool_call', toolName, input }, ctx);
      assert.equal(result.block, true);
      assert.match(result.reason, /declined/);
      assert.ok(screens.at(-1)?.some((line) => line.includes(tail)), toolName);
      assert.ok(screens.at(-1)?.some((line) => line.includes(`🛡 ${toolName}`)), toolName);
    }
    assert.equal(base.confirmations.length, 0);
  } finally {
    restore();
  }
});

function linkedContexts(confirm = true, inMemory = false) {
  const directory = mkdtempSync(join(tmpdir(), 'pi-safety-linked-'));
  const parent = autoModeContext({ hasUI: true, confirm });
  parent.ctx.sessionManager = SessionManager.create('/project', directory);
  const child = autoModeContext({ hasUI: false });
  child.ctx.sessionManager = inMemory ? SessionManager.inMemory('/project') : SessionManager.create('/project', directory, {
    parentSession: parent.ctx.sessionManager.getSessionFile(),
  });
  child.ctx.sessionManager.appendSessionInfo('test-worker');

  return { parent, child };
}

test('worker classifier and protected-path asks reach the parent; hard denies never do', async (t) => {
  const config = JSON.stringify({ paths: { ask: ['**/.env'], deny: ['/protected/**'] } });
  const root = await setup(config, { OPENAI_API_KEY: 'test-key' });
  const { parent, child } = linkedContexts();
  await root.handlers.get('session_start')!({}, parent.ctx);
  const worker = await setup(config, { OPENAI_API_KEY: 'test-key' });
  await worker.handlers.get('session_start')!({}, child.ctx);
  t.mock.method(globalThis, 'fetch', async () => new Response(JSON.stringify({
    answers: [{ type: 'refusal', name: 'verdict' }],
  })));
  try {
    const call = worker.handlers.get('tool_call')!;
    const bash = { type: 'tool_call', toolName: 'bash', input: { command: 'ls' } };
    assert.equal(await call(bash, { ...child.ctx, cwd: '/project' }), undefined);
    assert.match(parent.confirmations[0], /classification refused/);
    assert.match(parent.confirmations[0], /Worker: test-worker\nCwd: \/project/);
    assert.match(bash.input.command, /\nls$/);
    for (const input of [
      { path: '.env', content: 'WRITE_CONTENT' },
      { path: '.env', edits: [{ oldText: 'BEFORE', newText: 'AFTER' }] },
    ]) {
      assert.equal(await call({ type: 'tool_call', toolName: 'content' in input ? 'write' : 'edit', input }, {
        ...child.ctx, cwd: '/project',
      }), undefined);
    }
    assert.match(parent.confirmations[1], /WRITE_CONTENT/);
    assert.match(parent.confirmations[2], /-BEFORE\n\+AFTER/);
    for (const message of parent.confirmations.slice(1)) {
      assert.ok(message.endsWith('\n\nRule: Matches protected path rule **/.env\n'));
    }
    assert.equal(child.confirmations.length, 0);
    const blocked = await call({ type: 'tool_call', toolName: 'write', input: { path: '/protected/key', content: '' } }, {
      ...child.ctx, cwd: '/project',
    });
    assert.equal(blocked.block, true);
    assert.equal(parent.confirmations.length, 3);
  } finally {
    worker.restore();
    root.restore();
  }
});

test('enabling the parent gate reaches an already-running in-memory worker that started with PI_AUTO_MODE=0', async (t) => {
  const env = { PI_AUTO_MODE: '0', OPENAI_API_KEY: 'test-key' };
  const root = await setup(undefined, env);
  const { parent, child } = linkedContexts(true, true);
  await root.handlers.get('session_start')!({}, parent.ctx);
  const worker = await setup(undefined, env);
  await withWorkerParent(parent.ctx, async () => worker.handlers.get('session_start')!({}, child.ctx));
  let requests = 0;
  t.mock.method(globalThis, 'fetch', (url: string, init: RequestInit) => {
    requests++;
    return decisionFetch('openai', 'ask', 1)(url, init);
  });
  try {
    const event = () => ({ type: 'tool_call', toolName: 'bash', input: { command: 'echo harmless' } });
    assert.equal(await worker.handlers.get('tool_call')!(event(), child.ctx), undefined);
    assert.equal(requests, 0);
    await root.commands.get('toggle-auto-mode')!.handler('', parent.ctx);
    assert.equal(child.statuses.get('auto-mode'), 'auto-mode');
    assert.equal(await worker.handlers.get('tool_call')!(event(), child.ctx), undefined);
    assert.equal(requests, 1);
    assert.equal(parent.confirmations.length, 1);
    assert.match(parent.confirmations[0], /Worker: test-worker/);
    assert.equal(child.confirmations.length, 0);
    assert.equal(child.ctx.sessionManager.getSessionFile(), undefined);
  } finally {
    worker.restore();
    root.restore();
  }
});

for (const kind of ['main', 'persisted worker', 'in-memory worker']) {
  test(`toggle cancels an in-flight ${kind} classification and affects the current response`, async (t) => {
    const root = await setup(undefined, { OPENAI_API_KEY: 'test-key' });
    const { parent, child } = linkedContexts(true, kind === 'in-memory worker');
    await root.handlers.get('session_start')!({}, parent.ctx);
    const worker = await setup(undefined, { OPENAI_API_KEY: 'test-key' });
    await withWorkerParent(parent.ctx, async () => worker.handlers.get('session_start')!({}, child.ctx));
    const runner = kind === 'main' ? root : worker;
    const ctx = kind === 'main' ? parent.ctx : child.ctx;
    let started!: () => void;
    const starting = new Promise<void>((resolve) => { started = resolve; });
    let requests = 0;
    let cancelled = false;
    t.mock.method(globalThis, 'fetch', (_url: string, init: RequestInit) => {
      requests++;
      started();
      return new Promise((_resolve, reject) => init.signal!.addEventListener('abort', () => {
        cancelled = true;
        reject(init.signal!.reason);
      }, { once: true }));
    });
    try {
      const first = { type: 'tool_call', toolName: 'bash', input: { command: 'echo first' } };
      const pending = runner.handlers.get('tool_call')!(first, ctx);
      await starting;
      await root.commands.get('toggle-auto-mode')!.handler('', parent.ctx);
      assert.equal(await pending, undefined);
      assert.equal(cancelled, true);
      assert.equal(parent.statuses.get('auto-mode'), undefined);
      assert.equal(child.statuses.get('auto-mode'), undefined);
      assert.match(first.input.command, /\necho first$/);
      const next = { type: 'tool_call', toolName: 'bash', input: { command: 'echo next' } };
      assert.equal(await runner.handlers.get('tool_call')!(next, ctx), undefined);
      assert.equal(requests, 1, 'later calls from this response must not classify while off');
      assert.equal(parent.confirmations.length, 0);

      t.mock.method(globalThis, 'fetch', decisionFetch('openai', 'deny', 1));
      await root.commands.get('toggle-auto-mode')!.handler('', parent.ctx);
      assert.equal(parent.statuses.get('auto-mode'), 'auto-mode');
      assert.equal(child.statuses.get('auto-mode'), 'auto-mode');
      const denied = await runner.handlers.get('tool_call')!({ type: 'tool_call', toolName: 'bash', input: { command: 'echo checked' } }, ctx);
      assert.equal(denied.block, true, 'enabling applies to the current response too');
    } finally {
      worker.restore();
      root.restore();
    }
  });
}

for (const { command, inMemory } of ['echo harmless', 'kubectl apply -f deployment.yaml'].flatMap((command) =>
  [false, true].map((inMemory) => ({ command, inMemory })))) {
  test(`turning off cancels a forwarded ${inMemory ? 'in-memory' : 'persisted'} approval and rechecks rules: ${command}`, async (t) => {
    const config = readFileSync(new URL('../../pi-safety.jsonc', import.meta.url), 'utf8');
    const root = await setup(config, { OPENAI_API_KEY: 'test-key' });
    const { parent, child } = linkedContexts(true, inMemory);
    let shown!: () => void;
    const showing = new Promise<void>((resolve) => { shown = resolve; });
    let dismissed = false;
    parent.ctx.ui.select = async (_title: string, _choices: string[], ...options: any[]) => {
      shown();
      return new Promise<undefined>((resolve) => options[0].signal.addEventListener('abort', () => {
        dismissed = true;
        resolve(undefined);
      }, { once: true }));
    };
    await root.handlers.get('session_start')!({}, parent.ctx);
    const worker = await setup(config, { OPENAI_API_KEY: 'test-key' });
    await withWorkerParent(parent.ctx, async () => worker.handlers.get('session_start')!({}, child.ctx));
    t.mock.method(globalThis, 'fetch', decisionFetch('openai', 'ask', 1));
    try {
      const event = { type: 'tool_call', toolName: 'bash', input: { command } };
      const pending = worker.handlers.get('tool_call')!(event, child.ctx);
      await Promise.race([showing, pending.then((result: unknown) => {
        throw new Error(`operation settled before review: ${JSON.stringify(result)}`);
      })]);
      await root.commands.get('toggle-auto-mode')!.handler('', parent.ctx);
      const result = await pending;
      assert.equal(dismissed, true);
      if (command.startsWith('kubectl')) {
        assert.equal(result.block, true);
        assert.match(result.reason, /mutating or remote-execution kubectl/);
        assert.equal(event.input.command, command);
      } else {
        assert.equal(result, undefined);
        assert.ok(event.input.command.endsWith(command));
      }
    } finally {
      worker.restore();
      root.restore();
    }
  });
}

test('auto-mode toggles leave an independent protected-path approval pending', async () => {
  const root = await setup(JSON.stringify({ paths: { ask: ['**/.env'] } }), { OPENAI_API_KEY: 'test-key' });
  const { ctx } = autoModeContext({ hasUI: true });
  let shown!: () => void;
  const showing = new Promise<void>((resolve) => { shown = resolve; });
  let finish!: (choice: 'Deny') => void;
  let reviewSignal!: AbortSignal;
  ctx.ui.select = async (_title: string, _choices: string[], ...options: any[]) => {
    reviewSignal = options[0].signal;
    shown();
    return new Promise<'Deny'>((resolve) => { finish = resolve; });
  };
  try {
    const pending = root.handlers.get('tool_call')!({ type: 'tool_call', toolName: 'write', input: { path: '.env', content: 'x' } }, ctx);
    await showing;
    await root.commands.get('toggle-auto-mode')!.handler('', ctx);
    assert.equal(reviewSignal.aborted, false);
    finish('Deny');
    assert.equal((await pending).block, true);
  } finally {
    root.restore();
  }
});

test('a mode change never revives a cancelled call after the live turn signal changes', async (t) => {
  const root = await setup(undefined, { OPENAI_API_KEY: 'test-key' });
  const { ctx } = autoModeContext({ hasUI: true });
  const original = new AbortController();
  let liveSignal: AbortSignal | undefined = original.signal;
  Object.defineProperty(ctx, 'signal', { get: () => liveSignal });
  let started!: () => void;
  const starting = new Promise<void>((resolve) => { started = resolve; });
  t.mock.method(globalThis, 'fetch', (_url: string, init: RequestInit) => {
    started();
    return new Promise((_resolve, reject) => init.signal!.addEventListener('abort', () => reject(init.signal!.reason), { once: true }));
  });
  try {
    const event = { type: 'tool_call', toolName: 'bash', input: { command: 'echo cancelled' } };
    const pending = root.handlers.get('tool_call')!(event, ctx);
    await starting;
    original.abort();
    liveSignal = undefined;
    await root.commands.get('toggle-auto-mode')!.handler('', ctx);
    const result = await pending;
    assert.equal(result.block, true);
    assert.match(result.reason, /operation cancelled/);
    assert.equal(event.input.command, 'echo cancelled');
  } finally {
    root.restore();
  }
});

test('an off/on race never authorizes from a stale classification', async (t) => {
  const root = await setup(undefined, { OPENAI_API_KEY: 'test-key' });
  const { ctx } = autoModeContext({ hasUI: true, confirm: false });
  let finish!: (response: Response) => void;
  let started!: () => void;
  const starting = new Promise<void>((resolve) => { started = resolve; });
  let calls = 0;
  t.mock.method(globalThis, 'fetch', (url: string, init: RequestInit) => {
    if (++calls > 1) return decisionFetch('openai', 'deny', 1)(url, init);
    started();
    return new Promise<Response>((resolve) => { finish = resolve; });
  });
  try {
    const event = { type: 'tool_call', toolName: 'bash', input: { command: 'echo stale' } };
    const pending = root.handlers.get('tool_call')!(event, ctx);
    await starting;
    await root.commands.get('toggle-auto-mode')!.handler('', ctx);
    await root.commands.get('toggle-auto-mode')!.handler('', ctx);
    finish(await decisionFetch('openai', 'allow', 1)('ignored'));
    const result = await pending;
    assert.equal(result.block, true);
    assert.match(result.reason, /auto mode denied/);
    assert.equal(calls, 2);
    assert.equal(event.input.command, 'echo stale');
  } finally {
    root.restore();
  }
});

test('OpenAI refusals require confirmation and block without a UI', async (t) => {
  const { handlers, restore } = await setup(undefined, { OPENAI_API_KEY: 'test-key' });
  t.mock.method(globalThis, 'fetch', async () => new Response(JSON.stringify({
    answers: [{ name: 'verdict', type: 'refusal' }],
  })));
  try {
    const accepting = autoModeContext({ hasUI: true, confirm: true });
    const event = { type: 'tool_call', toolName: 'bash', input: { command: 'ls' } };
    assert.equal(await handlers.get('tool_call')!(event, accepting.ctx), undefined);
    assert.match(accepting.confirmations[0], /classification refused \(openai/);
    assert.doesNotMatch(accepting.confirmations[0], /classifier unavailable/);

    const headless = autoModeContext({ hasUI: false });
    const blocked = await handlers.get('tool_call')!(
      { type: 'tool_call', toolName: 'bash', input: { command: 'ls' } },
      headless.ctx,
    );
    assert.equal(blocked.block, true);
    assert.match(blocked.reason, /no UI to confirm/);
  } finally {
    restore();
  }
});
