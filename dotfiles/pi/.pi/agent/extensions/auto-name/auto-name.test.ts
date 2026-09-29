import assert from 'node:assert/strict';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import type { ExtensionAPI, ExtensionContext, SessionEntry } from '@earendil-works/pi-coding-agent';
import type { AutocompleteProvider } from '@earendil-works/pi-tui';
import autoName, { DEFAULT_CONFIG, buildTranscript, loadConfig, normalizeTitle, shortenTitle } from './index.ts';

type AssistantMessage = Extract<Extract<SessionEntry, { type: 'message' }>['message'], { role: 'assistant' }>;

interface Reply {
  content: AssistantMessage['content'];
  stopReason: 'stop' | 'error' | 'aborted';
  errorMessage?: string;
}

interface Request {
  model: { provider: string; id: string };
  context: { systemPrompt?: string; messages: { content: { text: string }[] }[] };
  options: { reasoning?: string; signal?: AbortSignal };
}

const usage = {
  input: 0,
  output: 0,
  cacheRead: 0,
  cacheWrite: 0,
  totalTokens: 0,
  cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
};

function userEntry(text: string): SessionEntry {
  return {
    type: 'message',
    id: 'u',
    parentId: null,
    timestamp: '',
    message: { role: 'user', content: text, timestamp: 0 },
  };
}

function assistantEntry(content: AssistantMessage['content']): SessionEntry {
  return {
    type: 'message',
    id: 'a',
    parentId: null,
    timestamp: '',
    message: {
      role: 'assistant',
      content,
      api: 'openai-responses',
      provider: 'openai',
      model: 'm',
      usage,
      stopReason: 'stop',
      timestamp: 0,
    },
  };
}

function textReply(text: string): Reply {
  return {
    content: [
      { type: 'thinking', thinking: 'weighing titles' },
      { type: 'text', text },
    ],
    stopReason: 'stop',
  };
}

function deferred<T>(): { promise: Promise<T>; resolve: (value: T) => void } {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((settle) => {
    resolve = settle;
  });
  return { promise, resolve };
}

/** Let the naming request started by a turn_end handler run to completion. */
function flush(): Promise<void> {
  return new Promise((resolve) => setImmediate(resolve));
}

async function withConfigFile(content: string, run: (path: string) => Promise<void>): Promise<void> {
  const dir = await mkdtemp(join(tmpdir(), 'auto-name-'));
  try {
    const path = join(dir, 'auto-name.json');
    await writeFile(path, content, 'utf8');
    await run(path);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
}

interface HarnessOptions {
  configPath?: string;
  sessionName?: string;
  replies?: Promise<Reply>[];
  mode?: ExtensionContext['mode'];
}

/** Completes slash commands like the built-in provider: `/na` and `name` give `/name `. */
const slashCommandProvider: AutocompleteProvider = {
  getSuggestions: async () => null,
  applyCompletion: (_lines, cursorLine, _cursorCol, item) => ({
    lines: [`/${item.value} `],
    cursorLine,
    cursorCol: item.value.length + 2,
  }),
};

/** The extension wired to a fake session whose registry only knows the default naming model. */
function harness(options: HarnessOptions = {}) {
  type Handler = (event: unknown, ctx: ExtensionContext) => unknown;
  type InputHandler = (data: string) => { consume?: boolean } | undefined;
  const handlers = new Map<string, Handler>();
  const inputHandlers = new Set<InputHandler>();
  let autocomplete = slashCommandProvider;
  const requests: Request[] = [];
  const notes: { message: string; type?: string }[] = [];
  const state = { name: options.sessionName, tokens: 0, editorText: '' };

  const pi = {
    on(event: string, handler: Handler) {
      handlers.set(event, handler);
    },
    getSessionName: () => state.name,
    setSessionName(name: string) {
      state.name = name;
    },
  } as unknown as ExtensionAPI;

  const ctx = {
    mode: options.mode ?? 'tui',
    getContextUsage: () => ({ tokens: state.tokens, contextWindow: 272_000, percent: null }),
    sessionManager: { getBranch: () => [userEntry('Add auto-naming of long pi sessions')] },
    modelRegistry: {
      find: (provider: string, id: string) =>
        `${provider}/${id}` === DEFAULT_CONFIG.model ? { provider, id } : undefined,
      streamSimple(model: Request['model'], context: Request['context'], streamOptions: Request['options']) {
        requests.push({ model, context, options: streamOptions });
        const reply =
          options.replies?.[requests.length - 1] ?? Promise.resolve(textReply('Auto-name long pi sessions'));
        return { result: () => reply };
      },
    },
    ui: {
      notify: (message: string, type?: string) => notes.push({ message, type }),
      getEditorText: () => state.editorText,
      setEditorText(text: string) {
        state.editorText = text;
      },
      onTerminalInput(handler: InputHandler) {
        inputHandlers.add(handler);
        return () => inputHandlers.delete(handler);
      },
      addAutocompleteProvider(factory: (current: AutocompleteProvider) => AutocompleteProvider) {
        autocomplete = factory(autocomplete);
      },
    },
  } as unknown as ExtensionContext;

  autoName(pi, options.configPath ?? join(tmpdir(), 'auto-name-missing', 'auto-name.json'));

  return {
    state,
    requests,
    notes,
    async emit(event: string): Promise<void> {
      await handlers.get(event)?.({ type: event }, ctx);
      await flush();
    },
    listeners: () => inputHandlers.size,
    /** Deliver a keypress (Enter by default) with `editorText` in the editor, as the TUI would. */
    async press(editorText: string, data = '\r'): Promise<{ consume?: boolean } | undefined> {
      state.editorText = editorText;
      const [handler] = inputHandlers;
      const result = handler?.(data);
      await flush();

      return result;
    },
    /**
     * Accept the autocomplete entry `value` for `editorText` with a keypress, as the editor does
     * within the same input event: listeners first, then the completion. Returns the editor text.
     */
    async complete(editorText: string, value: string, data = '\r'): Promise<string> {
      state.editorText = editorText;
      const [handler] = inputHandlers;
      handler?.(data);
      const completion = autocomplete.applyCompletion(
        [editorText],
        0,
        editorText.length,
        { value, label: value },
        editorText,
      );
      await flush();

      return completion.lines.join('\n');
    },
  };
}

test('loadConfig uses the defaults without a file and merges a partial one', async () => {
  assert.deepEqual(loadConfig(join(tmpdir(), 'auto-name-missing', 'auto-name.json')), DEFAULT_CONFIG);

  await withConfigFile('{ "thresholdTokens": 1000 }', async (path) => {
    assert.deepEqual(loadConfig(path), { thresholdTokens: 1000, model: 'openai-codex/gpt-6-luna' });
  });
  await withConfigFile('{ "model": "vercel-ai-gateway/openai/gpt-5.6-sol" }', async (path) => {
    assert.deepEqual(loadConfig(path), { thresholdTokens: 50_000, model: 'vercel-ai-gateway/openai/gpt-5.6-sol' });
  });
});

test('loadConfig rejects invalid files', async () => {
  const cases: [string, RegExp][] = [
    ['{', /JSON/],
    ['[1000]', /expected a JSON object/],
    ['{ "threshold": 1000 }', /unknown key "threshold"/],
    ['{ "thresholdTokens": 0 }', /thresholdTokens must be a positive integer/],
    ['{ "thresholdTokens": "50k" }', /thresholdTokens must be a positive integer/],
    ['{ "model": "gpt-6-luna" }', /model must be "provider\/modelId"/],
  ];
  for (const [content, error] of cases) {
    await withConfigFile(content, async (path) => {
      assert.throws(() => loadConfig(path), error, content);
    });
  }
});

test('buildTranscript keeps user and assistant prose only', () => {
  const entries: SessionEntry[] = [
    { type: 'session_info', id: 's', parentId: null, timestamp: '', name: 'ignored' },
    userEntry('Add auto-naming\nof long sessions'),
    assistantEntry([
      { type: 'thinking', thinking: 'private reasoning' },
      { type: 'text', text: 'Reading the extension docs.' },
      { type: 'toolCall', id: 't', name: 'read', arguments: { path: 'docs/extensions.md' } },
    ]),
    {
      type: 'message',
      id: 'r',
      parentId: null,
      timestamp: '',
      message: {
        role: 'toolResult',
        toolCallId: 't',
        toolName: 'read',
        content: [{ type: 'text', text: 'file contents' }],
        isError: false,
        timestamp: 0,
      },
    },
    assistantEntry([{ type: 'toolCall', id: 't2', name: 'bash', arguments: { command: 'ls' } }]),
    {
      type: 'custom_message',
      id: 'c',
      parentId: null,
      timestamp: '',
      customType: 'x',
      content: 'injected',
      display: true,
    },
  ];

  assert.equal(
    buildTranscript(entries),
    'User: Add auto-naming\nof long sessions\n\nAssistant: Reading the extension docs.',
  );
});

test('buildTranscript truncates long messages and caps the transcript, keeping both ends', () => {
  // 2,000 characters are kept per message: the first 60% and the last 40%.
  const long = buildTranscript([userEntry(`start ${'x'.repeat(5_000)} end`)]);
  assert.match(long, /^User: start x{1194}\n\[…\]\nx{796} end$/);

  const entries = Array.from({ length: 30 }, (_, index) => userEntry(`message ${index} ${'y'.repeat(2_000)}`));
  const transcript = buildTranscript(entries);
  assert.equal(transcript.length, 40_000 + '\n[…]\n'.length);
  assert.ok(transcript.startsWith('User: message 0 '));
  assert.ok(transcript.includes('User: message 29 '));
  assert.ok(!transcript.includes('message 15 '));
});

test('normalizeTitle keeps the first line without a label, markup, or trailing punctuation', () => {
  const cases: [string, string][] = [
    ['Auto-name long pi sessions', 'Auto-name long pi sessions'],
    ['"Auto-name long pi sessions."', 'Auto-name long pi sessions'],
    ['**Title:** Fix flaky CI tests', 'Fix flaky CI tests'],
    ['title: “Port the build to C#”', 'Port the build to C#'],
    ['## Refactor auth (OAuth)', 'Refactor auth (OAuth)'],
    [
      '\n  Évaluer les contrats multi-sites  \nBecause the session is about contracts.',
      'Évaluer les contrats multi-sites',
    ],
    ['Add auto-naming to the `/name` command', 'Add auto-naming to the /name command'],
    ['Fix the flaky end-to-end CI tests -', 'Fix the flaky end-to-end CI tests'],
    ['  ', ''],
    ['"..."', ''],
  ];
  for (const [reply, title] of cases) assert.equal(normalizeTitle(reply), title, JSON.stringify(reply));
});

test('shortenTitle cuts before the last secondary part that fits, else at the limit', () => {
  const cases: [string, string][] = [
    ['Auto-name long pi sessions', 'Auto-name long pi sessions'],
    ['Move zsh plugins to Sheldon and lazy-load nvm', 'Move zsh plugins to Sheldon'],
    ['Move zinit plugins to Sheldon, lazy-load nvm', 'Move zinit plugins to Sheldon'],
    ['Add automatic session naming and /name command', 'Add automatic session naming'],
    ['Auth rework for the gateway - phase two', 'Auth rework for the gateway'],
    // No clause starts within reach, or only before the third word: cut at the limit.
    ['Document the release process of the mobile app', 'Document the release process'],
    ['Fix CI with a new runner image and caching', 'Fix CI with a new runner'],
  ];
  for (const [title, shortened] of cases) assert.equal(shortenTitle(title), shortened, title);
});

test('names an unnamed session once its context reaches the threshold', async () => {
  const run = harness();
  await run.emit('session_start');

  run.state.tokens = 49_999;
  await run.emit('turn_end');
  assert.equal(run.requests.length, 0);

  run.state.tokens = 50_000;
  await run.emit('turn_end');
  assert.equal(run.requests.length, 1);
  const [request] = run.requests;
  assert.deepEqual(request.model, { provider: 'openai-codex', id: 'gpt-6-luna' });
  assert.equal(request.options.reasoning, 'low');
  assert.match(request.context.systemPrompt ?? '', /at most 6 words/);
  assert.equal(
    request.context.messages[0].content[0].text,
    '<transcript>\nUser: Add auto-naming of long pi sessions\n</transcript>',
  );
  assert.equal(run.state.name, 'Auto-name long pi sessions');
  assert.deepEqual(run.notes, [{ message: 'Session auto-named: Auto-name long pi sessions', type: 'info' }]);

  await run.emit('turn_end');
  assert.equal(run.requests.length, 1);
});

test('uses the configured threshold', async () => {
  await withConfigFile('{ "thresholdTokens": 1000 }', async (configPath) => {
    const run = harness({ configPath });
    await run.emit('session_start');

    run.state.tokens = 1_000;
    await run.emit('turn_end');
    assert.equal(run.state.name, 'Auto-name long pi sessions');
  });
});

test('leaves an already named session alone', async () => {
  const run = harness({ sessionName: 'reviewer#1c1efc6f' });
  await run.emit('session_start');

  run.state.tokens = 80_000;
  await run.emit('turn_end');
  assert.equal(run.requests.length, 0);
  assert.equal(run.state.name, 'reviewer#1c1efc6f');
});

test('reports a failed request once instead of retrying every turn', async () => {
  const run = harness({
    replies: [
      Promise.resolve({ content: [], stopReason: 'error', errorMessage: 'No API key for provider: openai-codex' }),
    ],
  });
  await run.emit('session_start');

  run.state.tokens = 60_000;
  await run.emit('turn_end');
  await run.emit('turn_end');
  assert.equal(run.requests.length, 1);
  assert.equal(run.state.name, undefined);
  assert.deepEqual(run.notes, [
    {
      message: 'auto-name: openai-codex/gpt-6-luna request failed: No API key for provider: openai-codex',
      type: 'warning',
    },
  ]);
});

test('keeps a name the user set while the request was in flight', async () => {
  const reply = deferred<Reply>();
  const run = harness({ replies: [reply.promise] });
  await run.emit('session_start');

  run.state.tokens = 60_000;
  await run.emit('turn_end');
  run.state.name = 'my own name';
  reply.resolve(textReply('Auto-name long pi sessions'));
  await flush();

  assert.equal(run.state.name, 'my own name');
  assert.deepEqual(run.notes, []);
});

test('abandons the request when the session shuts down', async () => {
  const reply = deferred<Reply>();
  const run = harness({ replies: [reply.promise] });
  await run.emit('session_start');

  run.state.tokens = 60_000;
  await run.emit('turn_end');
  await run.emit('session_shutdown');
  assert.equal(run.requests[0].options.signal?.aborted, true);

  reply.resolve({ content: [], stopReason: 'aborted', errorMessage: 'Request was aborted' });
  await flush();
  assert.equal(run.state.name, undefined);
  assert.deepEqual(run.notes, []);
});

test('disables auto-naming when the configuration is invalid', async () => {
  await withConfigFile('{ "threshold": 1000 }', async (configPath) => {
    const run = harness({ configPath });
    await run.emit('session_start');
    assert.deepEqual(run.notes, [
      {
        message: `auto-name: invalid ${configPath} (unknown key "threshold"); auto-naming is disabled`,
        type: 'warning',
      },
    ]);

    run.state.tokens = 60_000;
    await run.emit('turn_end');
    assert.equal(run.requests.length, 0);
  });
});

test('reports an unknown naming model', async () => {
  await withConfigFile('{ "model": "openai-codex/gpt-9-nova" }', async (configPath) => {
    const run = harness({ configPath });
    await run.emit('session_start');

    run.state.tokens = 60_000;
    await run.emit('turn_end');
    assert.equal(run.requests.length, 0);
    assert.deepEqual(run.notes, [{ message: 'auto-name: model openai-codex/gpt-9-nova not found', type: 'warning' }]);
  });
});

test('bare /name names the session at any context size, replacing the current name', async () => {
  const run = harness({ sessionName: 'old name' });
  await run.emit('session_start');

  assert.deepEqual(await run.press(' /name  '), { consume: true });
  assert.equal(run.state.editorText, '');
  assert.equal(run.requests.length, 1);
  assert.equal(run.state.name, 'Auto-name long pi sessions');
  assert.deepEqual(run.notes, [
    { message: 'Naming the session with openai-codex/gpt-6-luna...', type: 'info' },
    { message: 'Session auto-named: Auto-name long pi sessions (was: old name)', type: 'info' },
  ]);
});

test('leaves /name with an argument, other keys, and other text to pi', async () => {
  const run = harness();
  await run.emit('session_start');

  assert.equal(await run.press('/name My own title'), undefined);
  assert.equal(await run.press('/name', 'x'), undefined);
  assert.equal(await run.press('/names'), undefined);
  assert.equal(await run.press('rename it /name'), undefined);
  assert.equal(run.state.editorText, 'rename it /name');
  assert.equal(run.requests.length, 0);
});

test('completing /name from the autocomplete list with Enter names the session', async () => {
  const run = harness();
  await run.emit('session_start');

  assert.equal(await run.complete('/na', 'name'), '');
  assert.equal(run.requests.length, 1);
  assert.equal(run.state.name, 'Auto-name long pi sessions');
});

test('leaves other completions, and completing /name with Tab, to the editor', async () => {
  const run = harness();
  await run.emit('session_start');

  assert.equal(await run.complete('/na', 'skill:dynamic-wallpaper'), '/skill:dynamic-wallpaper ');
  assert.equal(await run.complete('/na', 'name', '\t'), '/name ');
  assert.equal(run.requests.length, 0);
});

test('leaves the keypress to an open extension dialog', async () => {
  const run = harness();
  await run.emit('session_start');

  await run.emit('ui_prompt_start');
  assert.equal(await run.press('/name'), undefined);
  assert.equal(run.requests.length, 0);

  await run.emit('ui_prompt_end');
  assert.deepEqual(await run.press('/name'), { consume: true });
  assert.equal(run.requests.length, 1);
});

test('listens to the keyboard in interactive mode only, until shutdown', async () => {
  const rpc = harness({ mode: 'rpc' });
  await rpc.emit('session_start');
  assert.equal(rpc.listeners(), 0);

  const tui = harness();
  await tui.emit('session_start');
  assert.equal(tui.listeners(), 1);

  await tui.emit('session_shutdown');
  assert.equal(tui.listeners(), 0);
});

test('bare /name keeps a name set while its request runs', async () => {
  const reply = deferred<Reply>();
  const run = harness({ sessionName: 'old name', replies: [reply.promise] });
  await run.emit('session_start');

  await run.press('/name');
  run.state.name = 'typed meanwhile';
  reply.resolve(textReply('Auto-name long pi sessions'));
  await flush();

  assert.equal(run.state.name, 'typed meanwhile');
  assert.deepEqual(run.notes, [{ message: 'Naming the session with openai-codex/gpt-6-luna...', type: 'info' }]);
});

test('bare /name reports an invalid configuration', async () => {
  await withConfigFile('{ "threshold": 1000 }', async (configPath) => {
    const run = harness({ configPath });
    await run.emit('session_start');

    assert.deepEqual(await run.press('/name'), { consume: true });
    assert.equal(run.requests.length, 0);
    assert.deepEqual(run.notes.at(-1), {
      message: `auto-name: invalid ${configPath}; fix it and run /reload`,
      type: 'warning',
    });
  });
});

test('asks again when the title is over the word limit', async () => {
  const run = harness({
    replies: [
      Promise.resolve(textReply('Move zinit plugins to sheldon and lazy-load nvm')),
      Promise.resolve(textReply('Move zinit to sheldon, lazy-load nvm')),
    ],
  });
  await run.emit('session_start');

  await run.press('/name');
  assert.equal(run.requests.length, 2);
  assert.equal(
    run.requests[1].context.messages[0].content[0].text,
    '<transcript>\nUser: Add auto-naming of long pi sessions\n</transcript>\n\n' +
      '"Move zinit plugins to sheldon and lazy-load nvm" has 8 words, over the limit of 6. ' +
      'Drop its secondary part and reply with a title of at most 6 words.',
  );
  assert.equal(run.state.name, 'Move zinit to sheldon, lazy-load nvm');
});

test('cuts a title that is still over the word limit after asking again', async () => {
  const run = harness({
    replies: [
      Promise.resolve(textReply('Move zinit plugins to sheldon and lazy-load nvm')),
      Promise.resolve(textReply('Fix the flaky end-to-end CI tests, then deploy')),
    ],
  });
  await run.emit('session_start');

  await run.press('/name');
  assert.equal(run.requests.length, 2);
  assert.equal(run.state.name, 'Fix the flaky end-to-end CI tests');
});
