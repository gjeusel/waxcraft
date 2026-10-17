import assert from 'node:assert/strict';
import test from 'node:test';
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import {
  buildContextEntries,
  buildSessionProjection,
  sessionEntryToContextMessages,
  type ExtensionAPI,
  type ExtensionContext,
  type SessionBeforeCompactEvent,
  type SessionEntry,
} from '@earendil-works/pi-coding-agent';
import { createCompactionCollector, registerCodexCompaction } from './compaction.ts';
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
    command: (args = '') => commands.get('codex-compact')!.handler(args, ctx),
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

test('/codex-compact immediately invokes Pi compaction without UI menus', () => {
  const h = harness();
  h.command();
  assert.equal(h.state.compactions, 1);
  h.command('settings');
  assert.equal(h.state.compactions, 1);
  h.state.model.provider = 'openai';
  h.command();
  assert.equal(h.state.compactions, 1);
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
