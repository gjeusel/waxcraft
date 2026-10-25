import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, renameSync, rmdirSync, statSync, unlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { initTheme, SessionManager } from '@earendil-works/pi-coding-agent';
import { stripTerminalSequences } from '@earendil-works/pi-tui';
import { AUTO_MODE_PROMPT_FILENAME, AUTO_MODE_SOURCES, DEFAULT_VERDICT_QUESTIONS, parseVerdictQuestions, type AutoModeSource } from './auto-mode.ts';
import safety from './index.ts';
import { withWorkerParent } from './session-state.ts';

async function setup(
  configText = JSON.stringify({ shell: { deny: [{ command: 'sudo', reason: 'sudo denied in test' }] } }),
  env: Record<string, string | undefined> = { PI_AUTO_MODE: '0' },
  initialSession?: SessionManager,
) {
  const directory = mkdtempSync(join(tmpdir(), 'pi-safety-index-'));
  const configPath = join(directory, 'config.jsonc');
  writeFileSync(configPath, configText);
  const promptPath = join(directory, AUTO_MODE_PROMPT_FILENAME);
  copyFileSync(new URL('../../pi-safety-auto-mode.md', import.meta.url), promptPath);
  const testEnv = { HOME: directory, PI_AUTO_MODE: undefined, OPENAI_API_KEY: undefined, TYPESAFE_AI_API_KEY: undefined, ...env, PI_SAFETY_CONFIG: configPath };
  const previousEnv = Object.fromEntries(Object.keys(testEnv).map((key) => [key, process.env[key]]));
  for (const [key, value] of Object.entries(testEnv)) {
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }

  let sessionManager = initialSession ?? SessionManager.inMemory(directory);
  const handlers = new Map<string, (...args: any[]) => any>();
  const commands = new Map<string, { handler: (args: string, ctx: any) => Promise<void> }>();
  await safety({
    on: (event: string, handler: (...args: any[]) => any) => handlers.set(event, (data: any, ctx: any) => {
      sessionManager = ctx?.sessionManager ?? sessionManager;
      return handler(data, Object.create(ctx ?? null, { sessionManager: { value: sessionManager } }));
    }),
    registerCommand: (name: string, command: { handler: (args: string, ctx: any) => Promise<void> }) =>
      commands.set(name, { handler: (args, ctx) => {
        sessionManager = ctx?.sessionManager ?? sessionManager;
        return command.handler(args, ctx);
      } }),
    appendEntry: (customType: string, data: unknown) => sessionManager.appendCustomEntry(customType, data),
  } as any);

  return {
    handlers,
    commands,
    promptPath,
    recordsPath: join(directory, '.pi', 'auto-mode-records.md'),
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

test('auto mode on: write and edit deny and ask protected paths, other paths pass', async () => {
  const { handlers, recordsPath, restore } = await setup(
    JSON.stringify({ paths: { deny: ['/protected/**'], ask: ['**/.env'] } }),
    { PI_AUTO_MODE: '1' },
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
    assert.equal(existsSync(recordsPath), false, 'protected-file approvals are not auto-mode feedback');
  } finally {
    restore();
  }
});

test('auto mode off: write and edit skip protected-path asks but retain hard denies', async (t) => {
  const { handlers, recordsPath, restore } = await setup(
    JSON.stringify({ paths: { deny: ['/protected/**'], ask: ['**/.env'] } }),
  );
  t.mock.method(globalThis, 'fetch', () => assert.fail('file edits must not call the classifier'));
  try {
    for (const hasUI of [false, true]) {
      const ctx = {
        cwd: '/project', hasUI,
        ui: { select: async () => assert.fail('auto mode off must not request file confirmation') },
      };
      for (const [toolName, input] of [
        ['write', { path: '.env', content: 'x' }],
        ['edit', { path: '.env', edits: [{ oldText: 'x', newText: 'y' }] }],
      ] as const) {
        const call = (path: string) => handlers.get('tool_call')!({
          type: 'tool_call', toolName, input: { ...input, path },
        }, ctx);
        assert.equal(await call('.env'), undefined);
        assert.equal(await call('src/index.ts'), undefined);
        const denied = await call('/protected/.env');
        assert.equal(denied.block, true);
        assert.match(denied.reason, /denied by protected path rule \/protected\/\*\*/);
      }
    }
    assert.equal(existsSync(recordsPath), false);
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

test('uses the policy beside the selected config, rereads edits, and defaults after deletion', async (t) => {
  const { handlers, promptPath, restore } = await setup('{}', { PI_AUTO_MODE: '1', OPENAI_API_KEY: 'test-key' });
  const { ctx } = autoModeContext({ hasUI: false });
  const received: any[] = [];
  t.mock.method(globalThis, 'fetch', (url: string, init: RequestInit) => {
    received.push(JSON.parse(init.body as string).questions[0]);
    return decisionFetch('openai', 'allow', 1)(url, init);
  });
  try {
    const run = () => handlers.get('tool_call')!({ type: 'tool_call', toolName: 'bash', input: { command: 'echo ok' } }, ctx);
    assert.equal(await run(), undefined);
    assert.equal(received[0].instructions, parseVerdictQuestions(readFileSync(promptPath, 'utf8')).verdict.instructions);

    writeFileSync(promptPath, '# Instructions\nCustom review instructions.\n\n# Allow\nCustom routine work.');
    assert.equal(await run(), undefined);
    assert.equal(received[1].instructions, 'Custom review instructions.');
    assert.deepEqual(received[1].choices, [
      { value: 'allow', description: 'Custom routine work.' },
      { value: 'ask', description: DEFAULT_VERDICT_QUESTIONS.verdict.criteria.ask },
      { value: 'deny', description: DEFAULT_VERDICT_QUESTIONS.verdict.criteria.deny },
    ]);

    unlinkSync(promptPath);
    assert.equal(await run(), undefined);
    assert.equal(received[2].instructions, DEFAULT_VERDICT_QUESTIONS.verdict.instructions);
    assert.equal(received.length, 3);
  } finally {
    restore();
  }
});

test('malformed policy requires approval and cannot silently execute without a UI', async (t) => {
  const { handlers, promptPath, restore } = await setup('{}', { PI_AUTO_MODE: '1', OPENAI_API_KEY: 'test-key' });
  writeFileSync(promptPath, '# Instructions\nAssess risk.\n\n# Instructions\nConflicting policy.');
  t.mock.method(globalThis, 'fetch', () => assert.fail('invalid policy must not reach the API'));
  try {
    const run = (ctx: any) => handlers.get('tool_call')!({ type: 'tool_call', toolName: 'bash', input: { command: 'echo ok' } }, ctx);
    const headless = await run(autoModeContext({ hasUI: false }).ctx);
    assert.equal(headless.block, true);
    assert.match(headless.reason, /auto-mode prompt .*duplicate section/);

    const declined = await run(autoModeContext({ hasUI: true, confirm: false }).ctx);
    assert.equal(declined.block, true);
    const accepting = autoModeContext({ hasUI: true, confirm: true });
    assert.equal(await run(accepting.ctx), undefined);
    assert.match(accepting.confirmations[0], /duplicate section/);
  } finally {
    restore();
  }
});

for (const enabled of [false, true]) {
  test(`shipped file rules: auto mode ${enabled ? 'on requires approval' : 'off skips approval'}`, async () => {
    const config = readFileSync(new URL('../../pi-safety.jsonc', import.meta.url), 'utf8');
    const { handlers, restore } = await setup(config, { PI_AUTO_MODE: enabled ? '1' : '0' });
    try {
      for (const path of [
        '/project/.pi/agent/pi-safety.jsonc',
        `/project/.pi/agent/${AUTO_MODE_PROMPT_FILENAME}`,
        '/project/.pi/agent/extensions/pi-safety/index.ts',
      ]) {
        for (const [toolName, input] of [
          ['write', { path, content: 'x' }],
          ['edit', { path, edits: [{ oldText: 'x', newText: 'y' }] }],
        ] as const) {
          const result = await handlers.get('tool_call')!({ type: 'tool_call', toolName, input },
            autoModeContext({ hasUI: false }).ctx);
          if (enabled) {
            assert.equal(result.block, true, path);
            assert.match(result.reason, /needs user confirmation/);
          } else {
            assert.equal(result, undefined, path);
          }
        }
      }
    } finally {
      restore();
    }
  });
}

for (const enabled of [false, true]) {
  test(`shipped infra rules: auto mode ${enabled ? 'on asks' : 'off denies'}`, async (t) => {
    const config = readFileSync(new URL('../../pi-safety.jsonc', import.meta.url), 'utf8');
    const { handlers, commands, recordsPath, restore } = await setup(config, {
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
        'gws gmail +send --to recipient@example.com --subject Hi --body Hi',
        'gws gmail +reply --message-id abc --body Hi', 'gws gmail users messages trash --params userId=me,id=abc',
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
      if (enabled) {
        const records = readFileSync(recordsPath, 'utf8');
        assert.equal([...records.matchAll(/^## .* — allow$/gm)].length, accepting.confirmations.length);
        assert.match(records, /"trigger": "shell-rule"/);
        assert.match(records, /"verdict": "allow"/);
        assert.match(records, /"reasonShown": "mutating or remote-execution kubectl/);
      } else {
        assert.equal(existsSync(recordsPath), false);
      }

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

  test(`${source}: /toggle-auto-mode permits missing OpenAI credentials only`, async () => {
    const otherKey = source === 'jev' ? 'OPENAI_API_KEY' : 'TYPESAFE_AI_API_KEY';
    const { commands, restore } = await setup(config, { PI_AUTO_MODE: '0', [otherKey]: 'other-key' });
    const { ctx, statuses, notifications } = autoModeContext({ hasUI: true });
    try {
      await commands.get('toggle-auto-mode')!.handler('', ctx);
      if (source === 'openai') {
        assert.equal(statuses.get('auto-mode'), 'auto-mode');
        assert.match(notifications.at(-1)!, /auto mode on/);
      } else {
        assert.ok(notifications.at(-1)?.includes(apiKeyEnv));
        assert.equal(statuses.has('auto-mode'), false);
      }
    } finally {
      restore();
    }
  });

  test(`${source}: auto mode gates Bash and toggles the footer status`, async () => {
    const { commands, handlers, recordsPath, restore } = await setup(config, { [apiKeyEnv]: 'test-key' });
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
      assert.equal(existsSync(recordsPath), false, 'automatic allow/deny and hard rules never create records');

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

      // Low confidence becomes a confirmation the user can accept.
      const accepting = autoModeContext({ hasUI: true, confirm: true });
      globalThis.fetch = decisionFetch(source, 'deny', 0.2);
      const lowConfidence = { type: 'tool_call', toolName: 'bash', input: { command: 'git push' } };
      assert.equal(await toolCall(lowConfidence, accepting.ctx), undefined);
      assert.match(accepting.confirmations.at(-1) ?? '', /below confidence floor 50%/);

      // Classifier outages fail open with a warning, with or without a UI, and are not recorded.
      globalThis.fetch = async () => new Response('overloaded', { status: 529 });
      const confirmationsBefore = accepting.confirmations.length;
      const unavailable = { type: 'tool_call', toolName: 'bash', input: { command: 'ls' } };
      assert.equal(await toolCall(unavailable, accepting.ctx), undefined);
      assert.equal(accepting.confirmations.length, confirmationsBefore);

      const headlessFailure = autoModeContext({ hasUI: false });
      const failed = await toolCall({ type: 'tool_call', toolName: 'bash', input: { command: 'ls' } }, headlessFailure.ctx);
      assert.equal(failed, undefined);
      assert.equal(headlessFailure.confirmations.length, 0);
      assert.ok(headlessFailure.notifications.at(-1)?.includes(`auto mode allowed unclassified: classifier unavailable (${source} 529`));

      // Without a UI, ask degrades to a block.
      const headless = autoModeContext({ hasUI: false });
      globalThis.fetch = decisionFetch(source, 'ask', 0.95);
      const blocked = await toolCall({ type: 'tool_call', toolName: 'bash', input: { command: 'ls' } }, headless.ctx);
      assert.match(blocked.reason, /no UI to confirm/);
      assert.equal(headless.confirmations.length, 0);

      const records = readFileSync(recordsPath, 'utf8');
      assert.deepEqual([...records.matchAll(/^## .* — (\w+)$/gm)].map((match) => match[1]), [
        'deny', 'cancelled', 'allow', 'unavailable',
      ]);
      assert.match(records, new RegExp(`"backend": "${source}"`));
      assert.ok(records.includes(`"session": "${ctx.sessionManager.getSessionId()}"`));
      assert.match(records, /"cwd": "\/project"/);
      assert.match(records, /"trigger": "low-confidence"/);
      assert.doesNotMatch(records, /classifier unavailable/);
      assert.match(records, /below confidence floor 50%/);
      assert.doesNotMatch(records, /test-key|export PATH=/);
      assert.equal(statSync(recordsPath).mode & 0o777, 0o600);

      await toggle('', ctx);
      assert.equal(statuses.get('auto-mode'), undefined);
      globalThis.fetch = async () => {
        throw new Error('classifier must not be called');
      };
      assert.equal(await toolCall({ type: 'tool_call', toolName: 'bash', input: { command: 'ls' } }, ctx), undefined);
      assert.equal(readFileSync(recordsPath, 'utf8'), records, 'auto mode off never records');
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
      JSON.stringify({ autoMode: { enabled }, paths: { ask: ['**/.env'] } }),
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
      const fileResult = await handlers.get('tool_call')!({
        type: 'tool_call', toolName: 'write', input: { path: '.env', content: 'x' },
      }, ctx);
      assert.equal(fileResult?.block ?? false, expected, 'file confirmations follow startup enablement');
    } finally {
      restore();
    }
  });
}

for (const enabled of [false, true]) {
  test(`saved auto mode ${enabled ? 'on' : 'off'} survives resume/reload without leaking to a new discussion`, async (t) => {
    const directory = mkdtempSync(join(tmpdir(), 'pi-safety-persist-'));
    const saved = SessionManager.create('/project', directory);
    saved.appendMessage({ role: 'user', content: 'Remember this discussion preference.', timestamp: 1 });
    const file = saved.getSessionFile()!;
    const config = JSON.stringify({ autoMode: { enabled: !enabled }, paths: { ask: ['**/.env'] } });
    const env = { PI_AUTO_MODE: enabled ? '0' : '1', OPENAI_API_KEY: 'test-key' };
    const initial = autoModeContext({ hasUI: true });
    initial.ctx.sessionManager = saved;
    const root = await setup(config, env, saved);
    try {
      await root.handlers.get('session_start')!({}, initial.ctx);
      await root.commands.get('toggle-auto-mode')!.handler('', initial.ctx);
      assert.equal(initial.statuses.get('auto-mode'), enabled ? 'auto-mode' : undefined);
      assert.deepEqual(saved.getEntries().filter((entry) => entry.type === 'custom').map((entry) => [entry.customType, entry.data]), [
        ['pi-safety:auto-mode', { enabled }],
      ]);
      assert.equal(saved.buildSessionContext().messages.length, 1, 'the preference is not model context');
    } finally {
      root.restore();
    }

    const resumed = SessionManager.open(file);
    // /resume opens the file; /reload reuses the manager but recreates the extension runtime.
    for (const [operation, sessionManager] of [
      ['resume', resumed], ['reload', resumed], ['new', SessionManager.inMemory('/project')],
      ['resume again', SessionManager.open(file)],
    ] as const) {
      const current = autoModeContext({ hasUI: true });
      current.ctx.sessionManager = sessionManager;
      const runtime = await setup(config, env, sessionManager);
      const requests = t.mock.method(globalThis, 'fetch', decisionFetch('openai', 'allow', 1));
      try {
        const entryCount = sessionManager.getEntries().length;
        await runtime.handlers.get('session_start')!({}, current.ctx);
        const expected = operation === 'new' ? !enabled : enabled;
        assert.equal(current.statuses.get('auto-mode'), expected ? 'auto-mode' : undefined, operation);
        assert.equal(sessionManager.getEntries().length, entryCount, 'startup does not write a toggle');
        const event = { type: 'tool_call', toolName: 'bash', input: { command: 'echo ok' } };
        assert.equal(await runtime.handlers.get('tool_call')!(event, current.ctx), undefined);
        assert.equal(requests.mock.callCount(), expected ? 1 : 0, operation);
        const fileResult = await runtime.handlers.get('tool_call')!({
          type: 'tool_call', toolName: 'edit', input: { path: '.env', edits: [{ oldText: 'x', newText: 'y' }] },
        }, current.ctx);
        assert.equal(fileResult?.block ?? false, expected, 'file confirmations follow the saved toggle');
        assert.equal(current.confirmations.length, expected ? 1 : 0);
      } finally {
        requests.mock.restore();
        runtime.restore();
      }
    }
  });
}

for (const enabled of [true, false]) {
  test(`a failed native session write keeps auto mode ${enabled ? 'on' : 'off'} after reload and resume`, async () => {
    const directory = mkdtempSync(join(tmpdir(), 'pi-safety-write-failure-'));
    const sessionManager = SessionManager.create('/project', directory);
    sessionManager.appendCustomEntry('pi-safety:auto-mode', { enabled });
    sessionManager.appendMessage({ role: 'user', content: 'A persisted discussion.', timestamp: 1 });
    const file = sessionManager.getSessionFile()!;
    const backup = `${file}.backup`;
    const current = autoModeContext({ hasUI: true });
    current.ctx.sessionManager = sessionManager;
    const env = { PI_AUTO_MODE: enabled ? '0' : '1', OPENAI_API_KEY: 'test-key' };
    const runtime = await setup('{}', env, sessionManager);
    renameSync(file, backup);
    mkdirSync(file);
    try {
      await runtime.handlers.get('session_start')!({}, current.ctx);
      // Native appendCustomEntry adds the entry in memory before this real filesystem error.
      await assert.rejects(runtime.commands.get('toggle-auto-mode')!.handler('', current.ctx), /EISDIR/);
      assert.equal(current.statuses.get('auto-mode'), enabled ? 'auto-mode' : undefined);
    } finally {
      runtime.restore();
      rmdirSync(file);
      renameSync(backup, file);
    }

    for (const manager of [sessionManager, SessionManager.open(file)]) {
      current.ctx.sessionManager = manager;
      const restored = await setup('{}', env, manager);
      try {
        await restored.handlers.get('session_start')!({}, current.ctx);
        assert.equal(current.statuses.get('auto-mode'), enabled ? 'auto-mode' : undefined);
      } finally {
        restored.restore();
      }
    }
  });
}

test('the last valid toggle is discussion-wide, including after tree navigation and reload', async () => {
  const current = autoModeContext({ hasUI: true });
  const sessionManager = current.ctx.sessionManager;
  const original = sessionManager.appendMessage({ role: 'user', content: 'Original branch', timestamp: 1 });
  const env = { OPENAI_API_KEY: 'test-key' };
  const root = await setup('{}', env, sessionManager);
  try {
    await root.handlers.get('session_start')!({}, current.ctx);
    await root.commands.get('toggle-auto-mode')!.handler('', current.ctx);
    sessionManager.branch(original);
    sessionManager.appendMessage({ role: 'user', content: 'Alternative branch', timestamp: 2 });
    assert.equal(sessionManager.getBranch().some((entry) => entry.type === 'custom'), false);
    assert.equal(current.statuses.get('auto-mode'), undefined, 'tree navigation does not undo the toggle');
  } finally {
    root.restore();
  }

  sessionManager.appendCustomEntry('another-extension', { enabled: true });
  for (const data of [null, true, {}, { enabled: 'true' }, { enabled: 1 }]) {
    sessionManager.appendCustomEntry('pi-safety:auto-mode', data);
  }
  const reloaded = await setup('{}', env, sessionManager);
  try {
    await reloaded.handlers.get('session_start')!({}, current.ctx);
    assert.equal(current.statuses.get('auto-mode'), undefined, 'only valid boolean preferences are restored');
    await reloaded.commands.get('toggle-auto-mode')!.handler('', current.ctx);
    assert.equal(current.statuses.get('auto-mode'), 'auto-mode');
  } finally {
    reloaded.restore();
  }

  const latest = await setup('{"autoMode":{"enabled":false}}', env, sessionManager);
  try {
    await latest.handlers.get('session_start')!({}, current.ctx);
    assert.equal(current.statuses.get('auto-mode'), 'auto-mode', 'the latest valid toggle wins');
  } finally {
    latest.restore();
  }
});

test('workers follow the restored parent preference and save shared toggles in the parent discussion', async () => {
  const env = { OPENAI_API_KEY: 'test-key' };
  const parent = autoModeContext({ hasUI: true });
  const child = autoModeContext({ hasUI: false });
  parent.ctx.sessionManager.appendCustomEntry('pi-safety:auto-mode', { enabled: false });
  child.ctx.sessionManager.appendCustomEntry('pi-safety:auto-mode', { enabled: true });
  const root = await setup('{}', env, parent.ctx.sessionManager);
  const worker = await setup('{}', env, child.ctx.sessionManager);
  try {
    await root.handlers.get('session_start')!({}, parent.ctx);
    await withWorkerParent(parent.ctx, async () => worker.handlers.get('session_start')!({}, child.ctx));
    assert.equal(parent.statuses.get('auto-mode'), undefined);
    assert.equal(child.statuses.get('auto-mode'), undefined, 'live parent wins over saved worker state');

    await worker.commands.get('toggle-auto-mode')!.handler('', child.ctx);
    assert.equal(parent.statuses.get('auto-mode'), 'auto-mode');
    assert.equal(child.statuses.get('auto-mode'), 'auto-mode');
    assert.deepEqual(parent.ctx.sessionManager.getEntries().filter((entry) => entry.type === 'custom').map((entry) => entry.data), [
      { enabled: false }, { enabled: true },
    ]);
    assert.equal(child.ctx.sessionManager.getEntries().length, 1, 'workers do not save a competing preference');

    await root.commands.get('toggle-auto-mode')!.handler('', parent.ctx);
    assert.equal(child.statuses.get('auto-mode'), undefined);
  } finally {
    worker.restore();
    root.restore();
  }
});

test('malformed saved preferences fall back to defaults; failed enabling does not save a toggle', async () => {
  const current = autoModeContext({ hasUI: true });
  const sessionManager = current.ctx.sessionManager;
  sessionManager.appendCustomEntry('pi-safety:auto-mode', { enabled: 'false' });
  const runtime = await setup(JSON.stringify({ autoMode: { source: 'jev' } }), {}, sessionManager);
  try {
    await runtime.handlers.get('session_start')!({}, current.ctx);
    assert.equal(current.statuses.get('auto-mode'), 'auto-mode');
    const event = { type: 'tool_call', toolName: 'bash', input: { command: 'echo ok' } };
    assert.match((await runtime.handlers.get('tool_call')!(event, current.ctx)).reason, /TYPESAFE_AI_API_KEY is not set/);
    await runtime.commands.get('toggle-auto-mode')!.handler('', current.ctx);
    const entries = sessionManager.getEntries();
    await runtime.commands.get('toggle-auto-mode')!.handler('', current.ctx);
    assert.equal(current.statuses.get('auto-mode'), undefined);
    assert.match(current.notifications.at(-1)!, /needs TYPESAFE_AI_API_KEY/);
    assert.deepEqual(sessionManager.getEntries(), entries);
  } finally {
    runtime.restore();
  }
});

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
      if (source === 'openai') assert.deepEqual(notifications, []);
      else assert.ok(notifications.at(-1)?.includes(apiKeyEnv));

      // /no-safety disables deterministic checks, not the separate auto-mode gate.
      await commands.get('no-safety')!.handler('', ctx);
      const event = { type: 'tool_call', toolName: 'bash', input: { command: 'ls' } };
      const result = await handlers.get('tool_call')!(event, ctx);
      if (source === 'openai') {
        assert.equal(result, undefined);
        assert.match(event.input.command, /\nls$/);
      } else {
        assert.equal(result.block, true);
        assert.ok(result.reason.includes(apiKeyEnv));
        assert.equal(event.input.command, 'ls');
      }
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

for (const status of [undefined, 401, 403]) {
  test(`OpenAI credentials (${status ?? 'missing'}): fail open without UI warnings and retain safeguards`, async (t) => {
    const { handlers, promptPath, recordsPath, restore } = await setup(JSON.stringify({
      shell: { deny: [
        { command: 'sudo', reason: 'sudo denied in test' },
        { command: 'kubectl', reason: 'infra needs approval', autoMode: 'ask' },
      ] },
      paths: { ask: ['**/.env'] },
    }), { PI_AUTO_MODE: '1', OPENAI_API_KEY: status ? 'bad-key' : undefined });
    const fetcher = t.mock.method(globalThis, 'fetch', async () => {
      assert.ok(status, 'missing credentials must not reach the API');
      return new Response('private server error with bad-key', { status });
    });
    const context = autoModeContext({ hasUI: false });
    const toolCall = handlers.get('tool_call')!;
    const run = (command: string, ctx = context.ctx) => toolCall({ type: 'tool_call', toolName: 'bash', input: { command } }, ctx);
    try {
      await handlers.get('session_start')!({}, context.ctx);
      assert.deepEqual(await Promise.all([run('ls'), run('pwd')]), [undefined, undefined]);
      assert.deepEqual(context.notifications, []);
      assert.equal(context.statuses.get('auto-mode'), 'auto-mode');
      assert.equal(existsSync(recordsPath), false);

      const requests = fetcher.mock.callCount();
      assert.match((await run('sudo ls')).reason, /sudo denied in test/);
      assert.equal(fetcher.mock.callCount(), requests);
      assert.match((await run('kubectl delete pod worker')).reason, /infra needs approval.*no UI/);
      const declined = autoModeContext({ hasUI: true, confirm: false });
      assert.match((await run('kubectl delete pod worker', declined.ctx)).reason, /user declined/);
      assert.equal(declined.confirmations.length, 1);
      assert.deepEqual(declined.notifications, []);
      assert.match((await toolCall({
        type: 'tool_call', toolName: 'write', input: { path: '.env', content: 'x' },
      }, context.ctx)).reason, /needs user confirmation/);

      writeFileSync(promptPath, '# Unknown\nInvalid policy.');
      assert.match((await run('ls')).reason, /auto-mode prompt .*unknown section/);

      writeFileSync(promptPath, '# Instructions\nAssess the command.');
      process.env.OPENAI_API_KEY = 'working-key';
      fetcher.mock.mockImplementation(decisionFetch('openai', 'deny', 1));
      assert.match((await run('ls')).reason, /auto mode denied/);
      assert.equal(context.statuses.get('auto-mode'), 'auto-mode');
    } finally {
      restore();
    }
  });
}

for (const initiallyMissing of [false, true]) {
  test(`OpenAI warning is process-wide across workers/reloads (initially missing: ${initiallyMissing})`, () => {
    // A fresh process tests the actual global lifetime, without resetting production warning state.
    execFileSync(process.execPath, ['--input-type=module', '-e', `
    import assert from 'node:assert/strict';
    import { mkdtempSync, writeFileSync } from 'node:fs';
    import { tmpdir } from 'node:os';
    import { join } from 'node:path';
    const directory = mkdtempSync(join(tmpdir(), 'pi-safety-warning-'));
    process.env.PI_SAFETY_CONFIG = join(directory, 'config.jsonc');
    writeFileSync(process.env.PI_SAFETY_CONFIG, '{}');
    process.env.PI_AUTO_MODE = '1';
    process.env.OPENAI_API_KEY = 'rejected';
    if (${initiallyMissing}) delete process.env.OPENAI_API_KEY;
    const { InteractiveMode, initTheme } = await import('@earendil-works/pi-coding-agent');
    const { Container, stripTerminalSequences } = await import('@earendil-works/pi-tui');
    initTheme('dark', false);
    const warnings = [];
    const chat = new Container();
    const editorText = 'unfinished user input';
    const renderer = Object.create(InteractiveMode.prototype);
    renderer.chatContainer = chat;
    renderer.ui = { requestRender() {} };
    renderer.editor = {
      getText: () => editorText,
      setText: () => assert.fail('notifications must not change editor input'),
    };
    console.warn = () => assert.fail('must not write directly into the terminal');
    const { withWorkerParent } = await import(${JSON.stringify(new URL('./session-state.ts', import.meta.url).href)});
    const url = ${JSON.stringify(new URL('./index.ts', import.meta.url).href)};
    const load = async (suffix, id, hasUI = false) => {
      const { default: safety } = await import(url + suffix);
      const handlers = new Map();
      await safety({ on: (name, handler) => handlers.set(name, handler), registerCommand() {} });
      const ctx = {
        hasUI,
        sessionManager: { getEntries: () => [], getBranch: () => [], getSessionId: () => id,
          getSessionFile: () => undefined, getHeader: () => undefined },
        ui: { setStatus() {}, notify: (message, type) => {
          assert.ok(hasUI, 'headless workers must notify through their parent');
          warnings.push({ id, message, type });
          renderer.showExtensionNotify(message, type);
        } },
      };
      await handlers.get('session_start')({}, ctx);
      return { handlers, ctx };
    };
    globalThis.fetch = async () => new Response('private error', { status: 401 });
    const run = async ({ handlers, ctx }) => assert.equal(await handlers.get('tool_call')({
      type: 'tool_call', toolName: 'bash', input: { command: 'ls' },
    }, ctx), undefined);
    const headless = await load('?headless', 'headless');
    await run(headless);
    assert.deepEqual(warnings, [], 'no UI must not consume the one-time warning');

    process.env.OPENAI_API_KEY = 'present-at-root-startup';
    const root = await load('', 'root', true);
    if (${initiallyMissing}) delete process.env.OPENAI_API_KEY;
    const worker = await withWorkerParent(root.ctx, () => load('?worker', 'worker'));
    await run(worker);
    process.env.OPENAI_API_KEY = 'rejected';
    const reloaded = await load('?reload', 'reloaded', true);
    await Promise.all([root, worker, reloaded].map(async (session) => {
      await run(session);
      await run(session);
      session.handlers.get('session_shutdown')({});
    }));
    headless.handlers.get('session_shutdown')({});
    const message = 'pi-safety: OpenAI key unavailable; auto mode is failing open.';
    assert.deepEqual(warnings, [{ id: 'root', message, type: 'warning' }]);
    const rendered = chat.render(100).map(stripTerminalSequences).join('\\n');
    assert.ok(rendered.includes('Warning: ' + message), 'warning must render in chat');
    assert.equal(renderer.editor.getText(), editorText);
    `], { encoding: 'utf8', stdio: 'pipe', cwd: new URL('..', import.meta.url) });
  });
}

test('long Bash, write, and edit approvals reach the native pager without truncation', async (t) => {
  initTheme('dark', false);
  const { handlers, recordsPath, restore } = await setup(
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
    const records = readFileSync(recordsPath, 'utf8');
    assert.equal([...records.matchAll(/^## .* — deny$/gm)].length, 1, 'only the Bash ask is recorded');
    assert.ok(records.includes(body + '\\necho BASH_REVIEW_TAIL'), 'full commands survive classifier truncation');
    assert.doesNotMatch(records, /WRITE_REVIEW_TAIL|EDIT_REVIEW_TAIL/);
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

test('Ctrl+C records cancellation for compact and long local and forwarded approvals', async (t) => {
  initTheme('dark', false);
  const root = await setup(undefined, { OPENAI_API_KEY: 'test-key' });
  const { parent, child } = linkedContexts(true, true);
  const reviewContext = {
    ...parent.ctx, mode: 'tui',
    ui: {
      ...parent.ctx.ui,
      custom: (factory: (...args: any[]) => any) => new Promise<boolean>((done) => {
        const theme = { fg: (_color: string, text: string) => text, style: (text: string) => text };
        const component = factory({ terminal: { rows: 28 }, requestRender() {} }, theme, {}, done);
        component.handleInput('\x03');
      }),
    },
  };
  await root.handlers.get('session_start')!({}, reviewContext);
  const worker = await setup(undefined, { OPENAI_API_KEY: 'test-key' });
  await withWorkerParent(reviewContext, async () => worker.handlers.get('session_start')!({}, child.ctx));
  t.mock.method(globalThis, 'fetch', decisionFetch('openai', 'ask', 1));
  try {
    for (const [runtime, ctx] of [[root, reviewContext], [worker, child.ctx]] as const) {
      for (const command of ['echo short', 'echo long\n'.repeat(30)]) {
        const event = { type: 'tool_call', toolName: 'bash', input: { command } };
        assert.equal((await runtime.handlers.get('tool_call')!(event, ctx)).block, true);
        assert.equal(event.input.command, command);
      }
    }
    const records = readFileSync(worker.recordsPath, 'utf8');
    assert.deepEqual([...records.matchAll(/^## .* — (\w+)$/gm)].map((match) => match[1]), [
      'cancelled', 'cancelled', 'cancelled', 'cancelled',
    ]);
  } finally {
    worker.restore();
    root.restore();
  }
});

test('worker classifier and protected-path asks reach the parent; hard denies never do', async (t) => {
  const config = JSON.stringify({ paths: { ask: ['**/.env'], deny: ['/protected/**'] } });
  const root = await setup(config, { OPENAI_API_KEY: 'test-key' });
  const { parent, child } = linkedContexts();
  await root.handlers.get('session_start')!({}, parent.ctx);
  const worker = await setup(config, { OPENAI_API_KEY: 'test-key' });
  await worker.handlers.get('session_start')!({}, child.ctx);
  t.mock.method(globalThis, 'fetch', decisionFetch('openai', 'ask', 1));
  try {
    const call = worker.handlers.get('tool_call')!;
    const bash = { type: 'tool_call', toolName: 'bash', input: { command: 'ls' } };
    assert.equal(await call(bash, { ...child.ctx, cwd: '/project' }), undefined);
    assert.match(parent.confirmations[0], /openai: ask 100%/);
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
    const records = readFileSync(worker.recordsPath, 'utf8');
    assert.equal([...records.matchAll(/^## .* — allow$/gm)].length, 1);
    assert.match(records, /"sessionName": "test-worker"/);
    assert.ok(records.includes(`"session": "${child.ctx.sessionManager.getSessionId()}"`));
    assert.match(records, /"trigger": "openai"/);
    assert.equal(existsSync(root.recordsPath), false, 'the forwarding parent must not duplicate the record');
  } finally {
    worker.restore();
    root.restore();
  }
});

test('enabling the parent gate reaches an already-running in-memory worker that started with PI_AUTO_MODE=0', async (t) => {
  const env = { PI_AUTO_MODE: '0', OPENAI_API_KEY: 'test-key' };
  const config = JSON.stringify({ paths: { ask: ['**/.env'] } });
  const root = await setup(config, env);
  const { parent, child } = linkedContexts(true, true);
  await root.handlers.get('session_start')!({}, parent.ctx);
  const worker = await setup(config, env);
  await withWorkerParent(parent.ctx, async () => worker.handlers.get('session_start')!({}, child.ctx));
  let requests = 0;
  t.mock.method(globalThis, 'fetch', (url: string, init: RequestInit) => {
    requests++;
    return decisionFetch('openai', 'ask', 1)(url, init);
  });
  try {
    const event = () => ({ type: 'tool_call', toolName: 'bash', input: { command: 'echo harmless' } });
    const fileEvent = { type: 'tool_call', toolName: 'write', input: { path: '.env', content: 'x' } };
    assert.equal(await worker.handlers.get('tool_call')!(event(), child.ctx), undefined);
    assert.equal(await worker.handlers.get('tool_call')!(fileEvent, child.ctx), undefined);
    assert.equal(parent.confirmations.length, 0);
    assert.equal(requests, 0);
    await root.commands.get('toggle-auto-mode')!.handler('', parent.ctx);
    assert.equal(child.statuses.get('auto-mode'), 'auto-mode');
    assert.equal(await worker.handlers.get('tool_call')!(event(), child.ctx), undefined);
    assert.equal(requests, 1);
    assert.equal(parent.confirmations.length, 1);
    assert.match(parent.confirmations[0], /Worker: test-worker/);
    assert.equal(await worker.handlers.get('tool_call')!(fileEvent, child.ctx), undefined);
    assert.equal(parent.confirmations.length, 2);
    assert.match(parent.confirmations[1], /Matches protected path rule/);
    assert.equal(requests, 1, 'protected files require confirmation, not classification');
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
      const records = readFileSync(worker.recordsPath, 'utf8');
      assert.equal([...records.matchAll(/^## .* — cancelled$/gm)].length, 1);
      assert.doesNotMatch(records, /^## .* — (allow|deny)$/m);
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

for (const [toolName, input] of [
  ['write', { path: '.env', content: 'x' }],
  ['edit', { path: '.env', edits: [{ oldText: 'x', newText: 'y' }] }],
] as const) {
  for (const kind of ['main', 'persisted worker', 'in-memory worker']) {
    test(`turning auto mode off cancels a ${kind} ${toolName} confirmation and affects later calls`, async () => {
      const config = JSON.stringify({ paths: { ask: ['**/.env'], deny: ['/protected/**'] } });
      const root = await setup(config, { OPENAI_API_KEY: 'test-key' });
      const { parent, child } = linkedContexts(true, kind === 'in-memory worker');
      let shown!: () => void;
      const showing = new Promise<void>((resolve) => { shown = resolve; });
      let dismissed = false;
      parent.ctx.ui.select = async (title: string, _choices: string[], ...options: any[]) => {
        parent.confirmations.push(title);
        shown();
        return new Promise<undefined>((resolve) => options[0].signal.addEventListener('abort', () => {
          dismissed = true;
          resolve(undefined);
        }, { once: true }));
      };
      await root.handlers.get('session_start')!({}, parent.ctx);
      const worker = await setup(config, { OPENAI_API_KEY: 'test-key' });
      await withWorkerParent(parent.ctx, async () => worker.handlers.get('session_start')!({}, child.ctx));
      const runner = kind === 'main' ? root : worker;
      const ctx = kind === 'main' ? parent.ctx : child.ctx;
      const event = { type: 'tool_call', toolName, input };
      try {
        const pending = runner.handlers.get('tool_call')!(event, ctx);
        await Promise.race([showing, pending.then((result: unknown) => {
          throw new Error(`operation settled before review: ${JSON.stringify(result)}`);
        })]);
        await root.commands.get('toggle-auto-mode')!.handler('', parent.ctx);
        assert.equal(await pending, undefined);
        assert.equal(dismissed, true);
        assert.equal(await runner.handlers.get('tool_call')!(event, ctx), undefined);
        assert.equal(parent.confirmations.length, 1, 'later calls must not prompt while off');
        const denied = await runner.handlers.get('tool_call')!({
          ...event, input: { ...input, path: '/protected/key' },
        }, ctx);
        assert.equal(denied.block, true, 'hard denies remain active while off');
        assert.equal(existsSync(root.recordsPath), false);
        assert.equal(existsSync(worker.recordsPath), false);
      } finally {
        worker.restore();
        root.restore();
      }
    });
  }

  test(`${toolName}: a mode change never revives a cancelled call after the live turn signal changes`, async () => {
    const root = await setup(JSON.stringify({ paths: { ask: ['**/.env'] } }), { OPENAI_API_KEY: 'test-key' });
    const { ctx } = autoModeContext({ hasUI: true });
    const original = new AbortController();
    let liveSignal: AbortSignal | undefined = original.signal;
    Object.defineProperty(ctx, 'signal', { get: () => liveSignal });
    let shown!: () => void;
    const showing = new Promise<void>((resolve) => { shown = resolve; });
    ctx.ui.select = async (_title: string, _choices: string[], ...options: any[]) => {
      shown();
      return new Promise<undefined>((resolve) => options[0].signal.addEventListener('abort', () => resolve(undefined), { once: true }));
    };
    try {
      const pending = root.handlers.get('tool_call')!({ type: 'tool_call', toolName, input }, ctx);
      await showing;
      original.abort();
      liveSignal = undefined;
      await root.commands.get('toggle-auto-mode')!.handler('', ctx);
      const result = await pending;
      assert.equal(result.block, true);
      assert.match(result.reason, /operation cancelled/);
    } finally {
      root.restore();
    }
  });

  test(`${toolName}: an off/on race never authorizes from a stale file confirmation`, async () => {
    const root = await setup(JSON.stringify({ paths: { ask: ['**/.env'] } }), { OPENAI_API_KEY: 'test-key' });
    const { ctx, confirmations } = autoModeContext({ hasUI: true });
    let shown!: () => void;
    const showing = new Promise<void>((resolve) => { shown = resolve; });
    let finish!: (choice: 'Allow') => void;
    ctx.ui.select = async (title: string): Promise<'Allow' | 'Deny'> => {
      confirmations.push(title);
      if (confirmations.length > 1) return 'Deny';

      shown();
      return new Promise<'Allow'>((resolve) => { finish = resolve; });
    };
    try {
      const pending = root.handlers.get('tool_call')!({ type: 'tool_call', toolName, input }, ctx);
      await showing;
      const turningOff = root.commands.get('toggle-auto-mode')!.handler('', ctx);
      const turningOn = root.commands.get('toggle-auto-mode')!.handler('', ctx);
      finish('Allow');
      await Promise.all([turningOff, turningOn]);
      const result = await pending;
      assert.equal(result.block, true);
      assert.match(result.reason, /the user declined/);
      assert.equal(confirmations.length, 2, 'turning back on requires a fresh approval');
    } finally {
      root.restore();
    }
  });
}

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

test('concurrent records preserve existing text, full fenced commands, and the classifier context', async (t) => {
  const runtime = await setup(undefined, { OPENAI_API_KEY: 'test-key' });
  const classifierInputs: string[] = [];
  t.mock.method(globalThis, 'fetch', (url: string, init: RequestInit) => {
    classifierInputs.push(JSON.parse(init.body as string).input);
    return decisionFetch('openai', 'ask', 1)(url, init);
  });
  const first = autoModeContext({ hasUI: true, confirm: true });
  const second = autoModeContext({ hasUI: true, confirm: false });
  const userMessage = `Update the issue description: ${'full context '.repeat(200)}MIDDLE_DETAILS${' full context'.repeat(200)}`;
  first.ctx.sessionManager.appendMessage({ role: 'user', content: userMessage, timestamp: 0 });
  const command = `printf '%s' 'Issue body with \`\`\`\` fences and ${'x'.repeat(2000)} COMMAND_TAIL'`;
  try {
    mkdirSync(join(process.env.HOME!, '.pi'));
    writeFileSync(runtime.recordsPath, '# Existing manually pruned backlog');
    const results = await Promise.all([
      runtime.handlers.get('tool_call')!({ type: 'tool_call', toolName: 'bash', input: { command } }, first.ctx),
      runtime.handlers.get('tool_call')!({ type: 'tool_call', toolName: 'bash', input: { command: 'echo second' } }, second.ctx),
    ]);
    assert.equal(results[0], undefined);
    assert.equal(results[1].block, true);
    const records = readFileSync(runtime.recordsPath, 'utf8');
    assert.ok(records.startsWith('# Existing manually pruned backlog\n\n## '));
    assert.deepEqual([...records.matchAll(/^## .* — (\w+)$/gm)].map((match) => match[1]), ['allow', 'deny']);
    assert.ok(records.includes(`\`\`\`\`\`bash\n${command}\n\`\`\`\`\``));
    assert.equal(classifierInputs[0], `User: ${userMessage}\nbash: ${command}`);
    assert.ok(records.includes(classifierInputs[0]), 'records preserve the exact full classifier input');
    assert.doesNotMatch(records, /…\[truncated\]…/);
    assert.doesNotMatch(records, /export PATH=/, 'record the requested command, not the injected shim');

    writeFileSync(runtime.recordsPath, '');
    await runtime.handlers.get('tool_call')!({ type: 'tool_call', toolName: 'bash', input: { command: 'echo new' } }, first.ctx);
    const fresh = readFileSync(runtime.recordsPath, 'utf8');
    assert.ok(fresh.startsWith('# Auto-mode records\n'));
    assert.equal([...fresh.matchAll(/^## /gm)].length, 1);
  } finally {
    runtime.restore();
  }
});

for (const answer of [true, false]) {
  test(`a record write failure warns without changing the ${answer ? 'Allow' : 'Deny'} answer`, async (t) => {
    const runtime = await setup(undefined, { OPENAI_API_KEY: 'test-key' });
    t.mock.method(globalThis, 'fetch', decisionFetch('openai', 'ask', 1));
    const { ctx, notifications } = autoModeContext({ hasUI: true, confirm: answer });
    try {
      mkdirSync(runtime.recordsPath, { recursive: true });
      const result = await runtime.handlers.get('tool_call')!({ type: 'tool_call', toolName: 'bash', input: { command: 'echo test' } }, ctx);
      assert.equal(result?.block ?? false, !answer);
      assert.match(notifications.at(-1) ?? '', /could not append ~\/\.pi\/auto-mode-records\.md/);
    } finally {
      runtime.restore();
    }
  });
}

test('OpenAI refusals allow with a warning but keep shell-rule asks', async (t) => {
  const config = JSON.stringify({
    shell: { deny: [{ command: 'helm', argv: { contains: ['upgrade'] }, reason: 'helm upgrade in test', autoMode: 'ask' }] },
  });
  const { handlers, recordsPath, restore } = await setup(config, { OPENAI_API_KEY: 'test-key' });
  t.mock.method(globalThis, 'fetch', async () => new Response(JSON.stringify({
    answers: [{ name: 'verdict', type: 'refusal' }],
  })));
  try {
    for (const hasUI of [true, false]) {
      const context = autoModeContext({ hasUI, confirm: true });
      const event = { type: 'tool_call', toolName: 'bash', input: { command: 'ls' } };
      assert.equal(await handlers.get('tool_call')!(event, context.ctx), undefined);
      assert.equal(context.confirmations.length, 0);
      assert.match(context.notifications.at(-1) ?? '', /allowed unclassified: classification refused \(openai/);
    }
    assert.equal(existsSync(recordsPath), false);

    const accepting = autoModeContext({ hasUI: true, confirm: true });
    const helm = { type: 'tool_call', toolName: 'bash', input: { command: 'helm upgrade app chart' } };
    assert.equal(await handlers.get('tool_call')!(helm, accepting.ctx), undefined);
    assert.match(accepting.confirmations[0], /Rule: helm upgrade in test/);
    assert.match(readFileSync(recordsPath, 'utf8'), /"trigger": "shell-rule"/);
  } finally {
    restore();
  }
});
