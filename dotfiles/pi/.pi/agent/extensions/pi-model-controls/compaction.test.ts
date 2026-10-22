import assert from 'node:assert/strict';
import test from 'node:test';
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import {
  buildContextEntries,
  buildSessionProjection,
  convertToLlm,
  sessionEntryToContextMessages,
  type ExtensionAPI,
  type ExtensionContext,
  type SessionBeforeCompactEvent,
  type SessionEntry,
} from '@earendil-works/pi-coding-agent';
import {
  ANTHROPIC_COMPACTION_BETA, ANTHROPIC_COMPACTION_KIND, createCompactionCollector, injectAnthropicBlock,
  parseAnthropicCheckpoint, registerAnthropicCompaction, registerCodexCompaction,
} from './compaction.ts';
import {
  CHECKPOINT_KIND, HISTORY_BYTES, ITEM_BYTES, activeCheckpoint, createCheckpoint, fingerprint,
  marker, parseCheckpoint, projectCheckpoint, replacementHistory, rewriteMarker,
  type Checkpoint, type JsonObject,
} from './checkpoint.ts';

const item = { type: 'compaction', encrypted_content: 'fixture-opaque-history' };
const usage = {
  input: 10, output: 2, cacheRead: 0, cacheWrite: 0, totalTokens: 12,
  cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
};
const model = { provider: 'openai-codex', api: 'openai-codex-responses', id: 'gpt-6.1-sol',
  baseUrl: 'https://chatgpt.com/backend-api' };

function user(id: string, parentId: string | null, text = id): SessionEntry {
  return { type: 'message', id, parentId, timestamp: '2026-01-01T00:00:00.000Z',
    message: { role: 'user', content: [{ type: 'text', text }], timestamp: 1 } };
}

function completion(type = 'response.completed', output: unknown[] = [item], status = 'completed'): unknown {
  return { type, response: { status, output } };
}

function fixtureCheckpoint(): Checkpoint {
  return createCheckpoint(model, [{ role: 'user', content: [{ type: 'input_text', text: 'old input' }] }, item], []);
}

interface Options {
  events?: unknown[];
  fail?: string;
  stopReason?: string;
  skipPayload?: boolean;
  skipDone?: boolean;
  gate?: Promise<void>;
  repeatedPayload?: boolean;
  payload?: JsonObject;
  resolvedModel?: typeof model;
}

function harness(options: Options = {}) {
  type Handler = (event: any, ctx: ExtensionContext) => any;
  const handlers = new Map<string, Handler>();
  const commands = new Map<string, { handler: Handler }>();
  const notes: string[] = [];
  const requests: { context: any; options: any; payload?: any }[] = [];
  const state = { entries: [user('a', null), user('b', 'a'), user('c', 'b')],
    model: { ...model }, sessionId: 'fixture-session', compactions: 0 };
  const statuses: (string | undefined)[] = [];
  const pi = {
    on: (name: string, handler: Handler) => handlers.set(name, handler),
    registerCommand: (name: string, command: { handler: Handler }) => commands.set(name, command),
    getAllTools: () => [{ name: 'read', description: 'Read fixture', parameters: { type: 'object' } }],
    getActiveTools: () => ['read'],
  } as unknown as ExtensionAPI;
  const ctx = {
    get model() { return state.model; },
    sessionManager: { getBranch: () => state.entries, getSessionId: () => state.sessionId },
    ui: { notify: (message: string) => notes.push(message),
      setStatus: (_key: string, status?: string) => statuses.push(status) },
    getSystemPrompt: () => 'fixture system prompt',
    compact: () => { state.compactions++; },
    modelRegistry: {
      stream: (_model: unknown, context: any, requestOptions: any) => (async function* () {
        const request = { context, options: requestOptions, payload: undefined as any };
        requests.push(request);
        const payload = options.payload ?? { model: model.id, instructions: 'fixture system prompt',
          input: context.messages.map((message: any) => ({ role: message.role,
            content: message.content.map((part: any) => ({ type: 'input_text', text: part.text })) })) };
        if (!options.skipPayload) request.payload = requestOptions.onPayload(payload, options.resolvedModel ?? state.model);
        if (options.repeatedPayload) requestOptions.onPayload(payload, state.model);
        if (options.gate) await options.gate;
        for (const event of options.events ?? [completion()]) requestOptions.onProviderStreamEvent(event, state.model);
        if (options.fail) {
          yield { type: 'error', error: { errorMessage: options.fail } };
        } else if (!options.skipDone) {
          yield { type: 'done', message: { stopReason: options.stopReason ?? 'stop', usage } };
        }
      })(),
    },
  } as unknown as ExtensionContext;
  registerCodexCompaction(pi);

  return {
    state, ctx, requests, notes, statuses,
    emit: (name: string, event: unknown = {}) => handlers.get(name)!(event, ctx),
    command: (args = '') => commands.get('compact-server-side')!.handler(args, ctx),
    compact: (firstKeptEntryId = 'b', signal = new AbortController().signal) => {
      const event = { branchEntries: [...state.entries], preparation: { firstKeptEntryId, tokensBefore: 50 },
        signal, reason: 'manual', willRetry: false } as SessionBeforeCompactEvent;
      return handlers.get('session_before_compact')!(event, ctx);
    },
  };
}

function publish(h: ReturnType<typeof harness>, result: any): void {
  const parentId = h.state.entries.at(-1)!.id;
  h.state.entries.push({ type: 'compaction', id: `cp-${h.state.entries.length}`, parentId,
    timestamp: '2026-01-02T00:00:00.000Z', ...result.compaction });
}

test('/compact-server-side immediately invokes Pi compaction without UI menus', () => {
  const h = harness();
  h.command();
  assert.equal(h.state.compactions, 1);
  h.command('settings');
  assert.equal(h.state.compactions, 1);
  assert.equal(h.notes.at(-1), 'Usage: /compact-server-side');
  h.state.model.provider = 'openai';
  h.command();
  assert.equal(h.state.compactions, 1);
  assert.equal(h.notes.at(-1), '/compact-server-side requires the official openai-codex Responses provider.');
});

test('Remote V2 uses native registry streaming, transforms payload, and returns canonical fingerprints', async () => {
  const h = harness();
  const result = await h.compact();
  assert.equal(result.compaction.firstKeptEntryId, 'b');
  assert.equal(result.compaction.tokensBefore, 50);
  assert.equal(result.compaction.usage, usage);
  assert.equal(result.compaction.details.kind, CHECKPOINT_KIND);
  const request = h.requests[0];
  assert.equal(request.options.transport, 'sse');
  assert.equal(request.options.cacheRetention, 'none');
  assert.equal(request.options.maxRetries, 0);
  assert.equal(request.options.apiKey, undefined);
  assert.equal(request.context.systemPrompt, 'fixture system prompt');
  assert.equal(request.context.tools[0].name, 'read');
  assert.deepEqual(request.payload.input.at(-1), { type: 'compaction_trigger' });
  assert.equal(request.payload.tool_choice, 'none');
  assert.equal(request.payload.store, false);
  assert.equal(request.payload.service_tier, 'default');
  assert.deepEqual(result.compaction.details.keptMessageFingerprints,
    buildSessionProjection(h.state.entries).messages.slice(1).map(fingerprint));
  assert.deepEqual(result.compaction.details.replacementHistory.at(-1), item);
  assert.equal(h.statuses.at(-1), undefined);
});

test('other APIs/providers stay native unless the newest compaction claims opaque history', async () => {
  const h = harness();
  h.state.model.provider = 'proxy';
  assert.equal(await h.compact(), undefined);
  assert.equal(h.requests.length, 0);
  publish(h, { compaction: { summary: 'opaque', firstKeptEntryId: 'b', tokensBefore: 1,
    details: { kind: CHECKPOINT_KIND, version: 999 } } });
  assert.deepEqual(await h.compact(), { cancel: true });
  assert.equal(h.requests.length, 0);
  publish(h, { compaction: { summary: 'native summary', firstKeptEntryId: 'b', tokensBefore: 1 } });
  assert.equal(await h.compact(), undefined);
});

test('checkpoint replay removes absorbed retained tail and preserves later messages', async () => {
  const h = harness();
  publish(h, await h.compact());
  const checkpoint = activeCheckpoint(h.state.entries);
  const parentId = h.state.entries.at(-1)!.id;
  h.state.entries.push(user('d', parentId, 'new request'));
  const projected = buildSessionProjection(h.state.entries).messages;
  const context = h.emit('context', { messages: projected });
  assert.equal(context.messages.length, 2);
  assert.equal(context.messages[0].content[0].text, marker(checkpoint.details!.checkpointId));
  assert.equal(context.messages[1].content[0].text, 'new request');
  const payload = { input: context.messages.map((message: any) => ({ role: message.role,
    content: [{ type: 'input_text', text: message.content[0].text }] })) };
  const replay = h.emit('before_provider_request', { payload });
  assert.deepEqual(replay.input.slice(0, -1), checkpoint.details!.replacementHistory);
  assert.equal(replay.input.at(-1).content[0].text, 'new request');

  const repeated = await h.compact('d');
  assert.ok(repeated.compaction);
  assert.deepEqual(h.requests[1].payload.input.slice(0, -2), checkpoint.details!.replacementHistory);
  assert.deepEqual(repeated.compaction.details.keptMessageFingerprints, [fingerprint(projected.at(-1)!)]);
});

test('canonical fingerprints include edits and exclude older retained compaction summaries', async () => {
  const h = harness();
  publish(h, await h.compact());
  const cpId = h.state.entries.at(-1)!.id;
  h.state.entries.push(user('d', cpId));
  const second = await h.compact('b');
  assert.ok(second.compaction);
  const details = second.compaction.details as Checkpoint;
  assert.equal(details.keptMessageFingerprints.length, 3);
  publish(h, second);
  assert.ok(h.emit('context', { messages: buildSessionProjection(h.state.entries).messages }));

  const edited = harness();
  edited.state.entries.push({ type: 'context_edit', id: 'edit', parentId: 'c', timestamp: '',
    targetId: 'b', replacement: { content: [{ type: 'text', text: 'edited input' }] } });
  const result = await edited.compact();
  const visible = buildSessionProjection(edited.state.entries).messages;
  assert.equal(result.compaction.details.keptMessageFingerprints[0], fingerprint(visible[1]));
  publish(edited, result);
  assert.ok(edited.emit('context', { messages: buildSessionProjection(edited.state.entries).messages }));
});

test('replays repeated upstream checkpoints with verified summaries suppressed by canonical projection', async () => {
  const h = harness();
  for (let round = 0; round < 3; round++) {
    const entries = buildContextEntries(h.state.entries);
    const kept = entries.slice(entries.findIndex((entry) => entry.id === 'b'))
      .flatMap(sessionEntryToContextMessages);
    publish(h, { compaction: {
      summary: `upstream checkpoint ${round}`, firstKeptEntryId: 'b', tokensBefore: 50,
      details: createCheckpoint(model, [item], kept),
    } });

    const entry = h.state.entries.at(-1)!;
    if (entry.type === 'compaction' && round === 0) {
      entry.systemMessage = { role: 'system', content: 'Historical tool declarations', timestamp: 1 };
    }
    h.state.entries.push(user(`next-${round}`, entry.id));
  }

  const checkpoint = activeCheckpoint(h.state.entries);
  const old = h.state.entries.find((entry) => entry.type === 'compaction')!;
  const suppressed = sessionEntryToContextMessages(old).map(fingerprint);
  assert.ok(suppressed.every((hash) => checkpoint.details!.keptMessageFingerprints.includes(hash)));

  const messages = buildSessionProjection(h.state.entries).messages;
  assert.ok(suppressed.every((hash) => !messages.some((message) => fingerprint(message) === hash)));
  const replay = h.emit('context', { messages });
  assert.equal(replay.messages.length, 2);
  assert.equal(replay.messages[0].content[0].text, marker(checkpoint.details!.checkpointId));
  assert.equal(replay.messages[1].content[0].text, 'next-2');

  // Missing real messages must still fail, even when historical metadata is recognizable.
  const drifted = { ...checkpoint.details!, keptMessageFingerprints: [...checkpoint.details!.keptMessageFingerprints] };
  drifted.keptMessageFingerprints[0] = '0'.repeat(64);
  assert.equal(projectCheckpoint(messages, drifted, checkpoint.entry!.summary, h.state.entries), undefined);
  assert.equal(projectCheckpoint(messages, checkpoint.details!, checkpoint.entry!.summary, []), undefined);

  const result = await h.compact('next-2');
  assert.ok(result.compaction);
  assert.deepEqual(result.compaction.details.keptMessageFingerprints, [fingerprint(messages.at(-1)!)]);
});

for (const version of [1, 2, 3]) {
  test(`legacy v${version} checkpoint details normalize and replay`, () => {
    const original = fixtureCheckpoint();
    const legacy: any = { ...original, version,
      protocol: version === 1 ? 'remote-compaction-v2' : 'responses-compact' };
    if (version < 3) delete legacy.profile;
    const parsed = parseCheckpoint(legacy)!;
    assert.equal(parsed.version, 3);
    assert.equal(parsed.profile, 'codex-responses-v1');
    assert.equal(parsed.protocol, version === 1 ? 'remote-v2' : 'responses-compact');
    const payload = { input: [{ role: 'user', content: [{ type: 'input_text', text: marker(parsed.checkpointId) }] }] };
    assert.deepEqual(rewriteMarker(payload, parsed).input, parsed.replacementHistory);
  });
}

test('legacy replacement history rejects unsafe or oversized entries preceding the checkpoint', () => {
  for (const preceding of [
    { type: 'compaction_trigger', role: 'user', content: [{ type: 'input_text', text: 'trigger' }] },
    { type: 'function_call', role: 'user', name: 'bash', content: [] }, item,
    { role: 'user', content: [{ type: 'function_call', name: 'bash' }] },
    { role: 'assistant', content: [{ type: 'input_text', text: 'assistant' }] },
    { role: 'user', content: [{ type: 'input_text', text: 'x'.repeat(ITEM_BYTES) }] },
    { role: 'user', content: [{ type: 'input_image', image_url: '', detail: 'invalid' }] },
  ]) {
    const details = fixtureCheckpoint();
    details.replacementHistory = [preceding, item];
    assert.equal(parseCheckpoint(details), undefined);
  }
});

test('legacy context-management replay validates inert encrypted reasoning and assistant suffix', () => {
  const details = fixtureCheckpoint();
  details.protocol = 'context-management';
  details.replacementHistory = [item,
    { type: 'reasoning', encrypted_content: 'opaque-reasoning', summary: [] },
    { type: 'message', role: 'assistant', content: [{ type: 'output_text', text: 'OK' }] }];
  assert.ok(parseCheckpoint(details));
  details.replacementHistory.push({ type: 'function_call', name: 'bash' });
  assert.equal(parseCheckpoint(details), undefined);
});

test('malformed checkpoints, fingerprint drift and incompatible models never silently summarize', async () => {
  for (const mutation of ['version', 'fingerprints', 'model']) {
    const h = harness();
    const result = await h.compact();
    if (mutation === 'version') result.compaction.details.version = 999;
    if (mutation === 'fingerprints') result.compaction.details.keptMessageFingerprints = ['0'.repeat(64)];
    if (mutation === 'model') result.compaction.details.modelId = 'different-model';
    publish(h, result);
    assert.equal(h.emit('context', { messages: buildSessionProjection(h.state.entries).messages }), undefined);
    assert.match(h.notes.at(-1)!, /could not replay safely/);
    assert.deepEqual(await h.compact(), { cancel: true });
    assert.equal(h.requests.length, 1);
  }
});

for (const terminal of ['response.completed', 'response.done']) {
  test(`collector accepts ${terminal} and identical item-done/terminal copies`, () => {
    const collector = createCompactionCollector();
    collector.observe({ type: 'response.output_item.done', item });
    collector.observe(completion(terminal, [{ encrypted_content: item.encrypted_content, type: item.type }]));
    assert.deepEqual(collector.finish(), item);
  });
}

test('collector failure aborts owned work immediately instead of relying on callback exceptions', () => {
  const controller = new AbortController();
  const collector = createCompactionCollector(() => controller.abort());
  collector.observe({ type: 'response.failed' });
  assert.equal(controller.signal.aborted, true);
  assert.equal(collector.failed, true);
  assert.throws(() => collector.finish());
});

test('collector rejects missing, partial, malformed, conflicting and oversized output', () => {
  const cases: unknown[][] = [
    [], [completion('response.completed', [])], [completion('response.completed', [item], 'incomplete')],
    [{ type: 'error', error: { message: 'failed' } }], [{ type: 'response.failed' }],
    [{ type: 'response.incomplete' }], [completion('response.completed', [{ type: 'compaction', encrypted_content: '' }])],
    [completion('response.completed', [item, { ...item, encrypted_content: 'conflict' }])],
    [completion('response.completed', [{ ...item, encrypted_content: 'x'.repeat(ITEM_BYTES) }])],
    [{ type: 'response.created', padding: 'x'.repeat(HISTORY_BYTES) }],
    [completion(), { type: 'response.created' }],
  ];
  for (const events of cases) {
    const collector = createCompactionCollector();
    for (const event of events) collector.observe(event);
    assert.throws(() => collector.finish());
  }
});

test('remote failures, missing payload/usage and duplicate triggers cancel without native fallback', async () => {
  const cases: Options[] = [
    { fail: 'provider secret that must not be displayed' }, { events: [] }, { skipPayload: true },
    { skipDone: true }, { stopReason: 'length' }, { repeatedPayload: true },
    { payload: { input: [{ type: 'compaction_trigger' }] } },
    { resolvedModel: { ...model, baseUrl: 'https://proxy.example.test/codex' } },
  ];
  for (const options of cases) {
    const h = harness(options);
    assert.deepEqual(await h.compact(), { cancel: true });
    assert.ok(h.notes.some((note) => note.includes('history preserved')));
    assert.ok(!h.notes.some((note) => note.includes('provider secret')));
  }
});

test('OAuth operation rejection pauses compaction but keeps compatible replay enabled', async () => {
  const h = harness({ events: [{ type: 'error', error: {
    code: 'hardened_oauth_rule_missing', type: 'rejected_by_hardened_oauth_boundary',
  } }] });
  assert.deepEqual(await h.compact(), { cancel: true });
  assert.deepEqual(await h.compact(), { cancel: true });
  assert.equal(h.requests.length, 1);
  publish(h, { compaction: { summary: 'legacy', firstKeptEntryId: 'b', tokensBefore: 1,
    details: createCheckpoint(model, [item], buildSessionProjection(h.state.entries).messages.slice(1)) } });
  assert.ok(h.emit('context', { messages: buildSessionProjection(h.state.entries).messages }));
  h.emit('session_start');
  await h.compact();
  assert.equal(h.requests.length, 2);
});

for (const change of ['session', 'branch', 'model_select', 'session_tree', 'session_shutdown', 'abort']) {
  test(`${change} invalidates an in-flight compaction`, async () => {
    let release!: () => void;
    const gate = new Promise<void>((resolve) => { release = resolve; });
    const h = harness({ gate });
    const controller = new AbortController();
    const pending = h.compact('b', controller.signal);
    assert.equal(h.requests.length, 1);
    if (change === 'session') h.state.sessionId = 'replacement';
    else if (change === 'branch') h.state.entries.push(user('d', 'c'));
    else if (change === 'abort') controller.abort();
    else h.emit(change);
    release();
    assert.deepEqual(await pending, { cancel: true });
    assert.equal(h.requests[0].options.signal.aborted, true);
  });
}

test('configured proxy routes remain native without a checkpoint', async () => {
  const h = harness();
  h.state.model.baseUrl = 'https://proxy.example.test/codex';
  assert.equal(await h.compact(), undefined);
  assert.equal(h.requests.length, 0);
});

test('checkpoint markers must occur exactly once and mismatches warn instead of guessing', async () => {
  const details = fixtureCheckpoint();
  assert.throws(() => rewriteMarker({ input: [] }, details));
  const candidate = { role: 'user', content: [{ type: 'input_text', text: marker(details.checkpointId) }] };
  assert.throws(() => rewriteMarker({ input: [candidate, candidate] }, details));
  const h = harness();
  publish(h, await h.compact());
  assert.equal(h.emit('before_provider_request', { payload: { input: [] } }), undefined);
  assert.match(h.notes.at(-1)!, /could not replay safely/);
});

test('replacement history and details stay bounded and copied', () => {
  const input = [{ role: 'user', content: [{ type: 'input_text', text: 'small' }] },
    { role: 'user', content: [{ type: 'input_text', text: 'x'.repeat(300_000) }] },
    { role: 'assistant', content: [] }];
  const history = replacementHistory(input, item);
  assert.equal(history.length, 2);
  assert.deepEqual(history.at(-1), item);
  input[0].content[0].text = 'mutated';
  assert.equal((history[0].content as JsonObject[])[0].text, 'small');
  const details = fixtureCheckpoint();
  details.replacementHistory = [{ ...item, encrypted_content: 'x'.repeat(ITEM_BYTES) }];
  assert.equal(parseCheckpoint(details), undefined);
  assert.equal(projectCheckpoint([], fixtureCheckpoint(), 'missing', []), undefined);
});

/** Resolve Pi's own AI dependency, rather than requiring a separate top-level test dependency. */
async function withNativeResponse(
  response: () => Response,
  run: (h: ReturnType<typeof harness>, dispatches: { url: string; headers: Headers; payload: any }[]) => Promise<void>,
): Promise<void> {
  const require = createRequire(import.meta.url);
  const piRequire = createRequire(import.meta.resolve('@earendil-works/pi-coding-agent'));
  const providerPath = piRequire.resolve.paths('@earendil-works/pi-ai')!
    .map((directory) => join(directory, '@earendil-works/pi-ai/dist/providers/openai-codex.js'))
    .find(existsSync);
  assert.ok(providerPath, 'Pi must provide its native AI dependency');
  const { openaiCodexProvider } = await import(pathToFileURL(providerPath).href);
  const provider = openaiCodexProvider();
  const actualModel = provider.getModels().find((candidate: any) => candidate.id === model.id);
  assert.ok(actualModel, 'The default model must exist in Pi\'s native Codex catalog');
  assert.equal(actualModel.baseUrl, model.baseUrl);
  const token = `fake.${Buffer.from(JSON.stringify({
    'https://api.openai.com/auth': { chatgpt_account_id: 'fixture-account' },
  })).toString('base64url')}.fake`;
  const dispatches: { url: string; headers: Headers; payload: any }[] = [];
  const originalFetch = globalThis.fetch;
  const h = harness();
  h.ctx.modelRegistry.stream = ((_model: unknown, context: unknown, options: any) =>
    provider.stream(actualModel, context, { ...options, apiKey: token })) as typeof h.ctx.modelRegistry.stream;

  // This replaces all network dispatch for the fixture; no credentials or hosted requests are used.
  globalThis.fetch = async (input, init) => {
    const headers = new Headers(init?.headers);
    const raw = headers.get('content-encoding') === 'zstd' ?
      require('node:zlib').zstdDecompressSync(init?.body).toString('utf8') : String(init?.body);
    dispatches.push({ url: String(input), headers, payload: JSON.parse(raw) });
    assert.equal(String(input), 'https://chatgpt.com/backend-api/codex/responses');
    assert.equal(init?.redirect, 'error');

    return response();
  };
  try {
    await run(h, dispatches);
  } finally {
    globalThis.fetch = originalFetch;
  }
}

for (const terminal of ['response.completed', 'response.done']) {
  test(`real native adapter validates ${terminal}, authentication and maintenance dispatch`, async () => {
    await withNativeResponse(() => new Response(`data: ${JSON.stringify({ type: terminal, response: {
      id: 'resp_fixture', status: 'completed', output: [item],
      usage: { input_tokens: 10, output_tokens: 2, total_tokens: 12 },
    } })}\n\n`, { headers: { 'content-type': 'text/event-stream' } }), async (h, dispatches) => {
      const result = await h.compact();
      assert.ok(result.compaction);
      assert.deepEqual(result.compaction.details.replacementHistory.at(-1), item);
      assert.equal(result.compaction.usage.totalTokens, 12);
      assert.equal(dispatches.length, 1);
      assert.equal(dispatches[0].headers.get('chatgpt-account-id'), 'fixture-account');
      assert.deepEqual(dispatches[0].payload.input.at(-1), { type: 'compaction_trigger' });
      assert.equal(dispatches[0].payload.tool_choice, 'none');
      assert.equal(dispatches[0].payload.store, false);
      assert.equal(dispatches[0].payload.service_tier, 'default');
    });
  });
}

test('real native HTTP OAuth denial pauses the route before provider formatting strips its code', async () => {
  await withNativeResponse(() => Response.json({ error: {
    code: 'hardened_oauth_rule_missing', type: 'rejected_by_hardened_oauth_boundary',
    message: 'Fixture credential not authorized',
  } }, { status: 403 }), async (h, dispatches) => {
    assert.deepEqual(await h.compact(), { cancel: true });
    assert.deepEqual(await h.compact(), { cancel: true });
    assert.equal(dispatches.length, 1);
    assert.ok(h.notes.some((note) => note.includes('paused')));
  });
});

test('real native transport rejects oversized SSE before parsing or publishing', async () => {
  await withNativeResponse(() => new Response(new Uint8Array(HISTORY_BYTES + 1), {
    headers: { 'content-type': 'text/event-stream' },
  }), async (h, dispatches) => {
    assert.deepEqual(await h.compact(), { cancel: true });
    assert.equal(dispatches.length, 1);
    assert.ok(h.notes.some((note) => note.includes('history preserved')));
  });
});

const anthropicModelId = 'claude-opus-5-5';
const signedBlock = { type: 'compaction', content: 'Summary: the user greeted Claude.', signature: 'EuYBfixture' };

function assistant(id: string, parentId: string, text: string): SessionEntry {
  return { type: 'message', id, parentId, timestamp: '2026-01-01T00:00:00.000Z', message: {
    role: 'assistant', content: [{ type: 'text', text }], api: 'anthropic-messages', provider: 'anthropic',
    model: anthropicModelId, usage, stopReason: 'stop', timestamp: 1,
  } } as SessionEntry;
}

function sse(events: JsonObject[]): Response {
  return new Response(events.map((event) => `event: ${event.type}\ndata: ${JSON.stringify(event)}\n\n`).join(''),
    { headers: { 'content-type': 'text/event-stream' } });
}

function compactionResponse(stopReason = 'compaction', blocks: JsonObject[] = [signedBlock]): Response {
  const start = { type: 'message_start', message: { id: 'msg_fixture', type: 'message', role: 'assistant',
    model: anthropicModelId, content: [], stop_reason: null, usage: { input_tokens: 0, output_tokens: 0 } } };
  const content = blocks.flatMap((block, index) => [
    { type: 'content_block_start', index, content_block: block }, { type: 'content_block_stop', index },
  ]);
  const delta = { type: 'message_delta', delta: { stop_reason: stopReason }, usage: { input_tokens: 0, output_tokens: 0,
    iterations: [{ type: 'compaction', input_tokens: 1000, output_tokens: 200, cache_read_input_tokens: 4000 }] } };

  return sse([start, ...content, delta, { type: 'message_stop' }]);
}

function replyResponse(): Response {
  return sse([
    { type: 'message_start', message: { id: 'msg_reply', type: 'message', role: 'assistant', model: anthropicModelId,
      content: [], stop_reason: null, usage: { input_tokens: 5, output_tokens: 0 } } },
    { type: 'content_block_start', index: 0, content_block: { type: 'text', text: '' } },
    { type: 'content_block_delta', index: 0, delta: { type: 'text_delta', text: 'OK' } },
    { type: 'content_block_stop', index: 0 },
    { type: 'message_delta', delta: { stop_reason: 'end_turn' }, usage: { output_tokens: 1 } },
    { type: 'message_stop' },
  ]);
}

/** Drives Pi's real Anthropic adapter against a fixture fetch; no hosted request is made. */
async function withAnthropic(
  responses: (() => Response)[],
  run: (h: Awaited<ReturnType<typeof anthropicHarness>>) => Promise<void>,
): Promise<void> {
  const originalFetch = globalThis.fetch;
  const h = await anthropicHarness();
  globalThis.fetch = async (input, init) => {
    const request = input instanceof Request ? input : new Request(String(input), init);
    h.dispatches.push({ url: request.url, headers: request.headers, payload: JSON.parse(await request.text()) });
    const next = responses.shift();
    assert.ok(next, 'Unexpected extra request');

    return next();
  };
  try {
    await run(h);
  } finally {
    globalThis.fetch = originalFetch;
  }
}

async function anthropicHarness() {
  const piRequire = createRequire(import.meta.resolve('@earendil-works/pi-coding-agent'));
  const providerPath = piRequire.resolve.paths('@earendil-works/pi-ai')!
    .map((directory) => join(directory, '@earendil-works/pi-ai/dist/providers/anthropic.js'))
    .find(existsSync);
  assert.ok(providerPath, 'Pi must provide its native AI dependency');
  const { anthropicProvider } = await import(pathToFileURL(providerPath).href);
  // Pi's model runtime folds the system prompt and tools into the transcript before providers run.
  const { normalizeContext } = await import(pathToFileURL(join(providerPath, '../../utils/transcript.js')).href);
  const provider = anthropicProvider();
  const actualModel = provider.getModels().find((candidate: any) => candidate.id === anthropicModelId);
  assert.ok(actualModel, 'The fixture model must exist in Pi\'s native Anthropic catalog');

  type Handler = (event: any, ctx: ExtensionContext) => any;
  const handlers = new Map<string, Handler[]>();
  const notes: string[] = [];
  const dispatches: { url: string; headers: Headers; payload: any }[] = [];
  const state = {
    entries: [user('a', null, 'hello'), assistant('b', 'a', 'hi'), user('c', 'b', 'next question')],
    model: { ...actualModel },
  };
  const pi = {
    on: (name: string, handler: Handler) => handlers.set(name, [...(handlers.get(name) ?? []), handler]),
    registerCommand: () => {},
    getAllTools: () => [{ name: 'read', description: 'Read fixture', parameters: { type: 'object', properties: {} } }],
    getActiveTools: () => ['read'],
    getThinkingLevel: () => 'high',
  } as unknown as ExtensionAPI;
  const ctx = {
    get model() { return state.model; },
    sessionManager: { getBranch: () => state.entries, getSessionId: () => 'fixture-session' },
    ui: { notify: (message: string) => notes.push(message), setStatus: () => {} },
    getSystemPrompt: () => 'fixture system prompt',
    modelRegistry: {
      streamSimple: (model: unknown, context: unknown, options: any) =>
        provider.streamSimple(model, normalizeContext(context), { ...options, apiKey: 'sk-ant-api03-fixture' }),
    },
  } as unknown as ExtensionContext;
  registerCodexCompaction(pi);
  registerAnthropicCompaction(pi);

  const emit = async (name: string, event: any) => {
    let result;
    for (const handler of handlers.get(name) ?? []) {
      const value = await handler(event, ctx);
      if (value !== undefined) result = value;
      if (name === 'before_provider_request' && value !== undefined) event = { ...event, payload: value };
      if (value?.cancel) break;
    }
    return result;
  };

  return {
    state, notes, dispatches, emit,
    compact: (firstKeptEntryId = 'c', customInstructions?: string) => emit('session_before_compact', {
      branchEntries: [...state.entries], customInstructions, signal: new AbortController().signal,
      preparation: { firstKeptEntryId, tokensBefore: 50 }, reason: 'manual', willRetry: false,
    }),
    /** Sends the projected context like the agent loop: through the real adapter and the hook. */
    reply: async () => {
      const messages = buildSessionProjection(state.entries).messages.filter((message) => message.role !== 'system');
      const stream = provider.streamSimple(state.model, normalizeContext({
        systemPrompt: 'fixture system prompt', messages: convertToLlm(messages),
      }), { apiKey: 'sk-ant-api03-fixture', onPayload: (payload: unknown) =>
        emit('before_provider_request', { type: 'before_provider_request', payload }) });
      for await (const event of stream) if (event.type === 'error') throw new Error(event.error.errorMessage);
    },
  };
}

test('Anthropic compaction summarizes the messages before the cut with the signed-block beta', async () => {
  await withAnthropic([() => compactionResponse()], async (h) => {
    const result = await h.compact();
    assert.ok(result.compaction);
    assert.equal(result.compaction.summary, signedBlock.content);
    assert.equal(result.compaction.firstKeptEntryId, 'c');
    assert.deepEqual(result.compaction.details.block, signedBlock);
    assert.equal(result.compaction.details.kind, ANTHROPIC_COMPACTION_KIND);
    assert.equal(result.compaction.usage.input, 1000);
    assert.equal(result.compaction.usage.cacheRead, 4000);
    assert.ok(result.compaction.usage.cost.total > 0);

    const [dispatch] = h.dispatches;
    assert.equal(new URL(dispatch.url).pathname, '/v1/messages');
    assert.ok(dispatch.headers.get('anthropic-beta')!.split(',').includes(ANTHROPIC_COMPACTION_BETA));
    assert.deepEqual(dispatch.payload.compaction, { type: 'summarize' });
    assert.equal(dispatch.payload.system[0].text, 'fixture system prompt');
    assert.equal(dispatch.payload.tools[0].name, 'read');
    const conversation = dispatch.payload.messages.filter((message: any) => message.role !== 'system');
    assert.deepEqual(conversation.map((message: any) => message.role), ['user', 'assistant']);
  });
});

test('Anthropic replay swaps the plaintext summary for the signed block, and compacts it again', async () => {
  await withAnthropic([() => compactionResponse(), replyResponse, () => compactionResponse()], async (h) => {
    publish(h as any, await h.compact());
    const compactionId = h.state.entries.at(-1)!.id;
    h.state.entries.push(assistant('d', compactionId, 'answer'), user('e', 'd', 'follow-up'));

    await h.reply();
    const replay = h.dispatches[1];
    assert.deepEqual(replay.payload.messages[0], { role: 'assistant', content: [signedBlock] });
    assert.equal(replay.payload.messages[1].content[0].text, 'next question');
    assert.ok(replay.headers.get('anthropic-beta')!.split(',').includes(ANTHROPIC_COMPACTION_BETA));
    assert.equal(JSON.stringify(replay.payload).includes('<summary>'), false);

    const second = await h.compact('e');
    assert.ok(second.compaction);
    const resent = h.dispatches[2].payload.messages;
    assert.deepEqual(resent[0], { role: 'assistant', content: [signedBlock] });
    assert.deepEqual(resent.filter((message: any) => message.role !== 'system').map((message: any) => message.role),
      ['assistant', 'user', 'assistant']);
  });
});

test('Anthropic replay stays plaintext on another model or without a valid signed block', async () => {
  await withAnthropic([() => compactionResponse(), replyResponse, replyResponse], async (h) => {
    const result = await h.compact();
    publish(h as any, result);
    h.state.model = { ...h.state.model, id: 'claude-sonnet-5-5' };
    await h.reply();
    assert.match(JSON.stringify(h.dispatches[1].payload.messages[0]), /<summary>/);

    h.state.model = { ...h.state.model, id: anthropicModelId };
    result.compaction.details.block.signature = '';
    await h.reply();
    assert.match(JSON.stringify(h.dispatches[2].payload.messages[0]), /<summary>/);
  });
});

test('Anthropic failures fall back to Pi compaction, and rejections pause the route', async () => {
  const cases: [string, (() => Response)[], number][] = [
    ['no summary', [() => compactionResponse('max_tokens', [])], 2],
    ['unexpected content', [() => compactionResponse('end_turn', [{ type: 'text', text: 'hi' }])], 2],
    ['rejected', [() => Response.json({ type: 'error', error: { type: 'invalid_request_error',
      message: 'secret detail' } }, { status: 400 })], 1],
  ];
  for (const [label, responses, expectedDispatches] of cases) {
    await withAnthropic([...responses, () => compactionResponse('max_tokens', [])], async (h) => {
      assert.equal(await h.compact(), undefined, label);
      assert.equal(await h.compact(), undefined, label);
      assert.equal(h.dispatches.length, expectedDispatches, label);
      assert.ok(h.notes.every((note) => !note.includes('secret')), label);
      assert.match(h.notes[0], /using Pi compaction/, label);
    });
  }
});

test('Anthropic compaction defers to Pi for focus instructions, proxies and unsummarizable cuts', async () => {
  await withAnthropic([], async (h) => {
    assert.equal(await h.compact('c', 'focus on the API'), undefined);
    assert.equal(await h.compact('a'), undefined);
    assert.equal(await h.compact('missing'), undefined);
    h.state.model = { ...h.state.model, baseUrl: 'https://proxy.example.test' };
    assert.equal(await h.compact(), undefined);
    assert.equal(h.dispatches.length, 0);
  });
});

test('Anthropic compaction block injection requires the summary first and a single block', () => {
  const details = parseAnthropicCheckpoint({ kind: ANTHROPIC_COMPACTION_KIND, version: 1, provider: 'anthropic',
    api: 'anthropic-messages', modelId: anthropicModelId, block: signedBlock, createdAt: '' })!;
  const summary = convertToLlm([{ role: 'compactionSummary', summary: signedBlock.content, tokensBefore: 0, timestamp: 0 }])[0];
  const first = { role: 'user', content: [{ ...(summary.content as unknown as JsonObject[])[0], cache_control: { type: 'ephemeral' } }] };
  const injected = injectAnthropicBlock({ messages: [first, { role: 'user', content: 'next' }], betas: ['x'] },
    details, signedBlock.content);
  assert.deepEqual(injected.messages, [{ role: 'assistant', content: [{ ...signedBlock,
    cache_control: { type: 'ephemeral' } }] }, { role: 'user', content: 'next' }]);
  assert.deepEqual(injected.betas, ['x', ANTHROPIC_COMPACTION_BETA]);
  assert.throws(() => injectAnthropicBlock({ messages: [{ role: 'user', content: 'next' }, first] }, details, signedBlock.content));
  assert.throws(() => injectAnthropicBlock({ messages: [first, { role: 'assistant', content: [signedBlock] }] },
    details, signedBlock.content));
  assert.equal(parseAnthropicCheckpoint({ ...details, block: { ...signedBlock, signature: '' } }), undefined);
});
