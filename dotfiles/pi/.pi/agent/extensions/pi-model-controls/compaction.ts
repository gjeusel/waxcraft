import {
  buildSessionProjection,
  convertToLlm,
  type CompactionEntry,
  type ExtensionAPI,
  type ExtensionContext,
  type SessionBeforeCompactEvent,
  type SessionEntry,
} from '@earendil-works/pi-coding-agent';
import {
  activeCheckpoint, bytes, createCheckpoint, HISTORY_BYTES, isObject, ITEM_BYTES,
  projectCheckpoint, replacementHistory, rewriteMarker, stableJson, validateItem,
  type Checkpoint, type JsonObject,
} from './checkpoint.ts';
import { isAnthropicFastModel, isOfficialCodexModel } from './fast.ts';

type Model = NonNullable<ExtensionContext['model']>;
type CodexModel = Model & { api: 'openai-codex-responses' };
type Usage = NonNullable<Extract<ReturnType<typeof buildSessionProjection>['entries'][number]['sourceEntry'],
  { type: 'compaction' }>['usage']>;

function officialCodex(model: Model | undefined): model is CodexModel {
  return isOfficialCodexModel(model);
}

function compatible(details: Checkpoint, model: Model | undefined): boolean {
  return officialCodex(model) && details.api === model.api && details.modelId === model.id &&
    details.profile === 'codex-responses-v1';
}

function routeKey(model: Model | undefined): string {
  return JSON.stringify([model?.provider, model?.api, model?.id, model?.baseUrl]);
}

function oauthRejection(value: unknown): boolean {
  if (value instanceof Error) value = value.message;
  if (typeof value === 'string') {
    try {
      value = JSON.parse(value.slice(value.indexOf('{')));
    } catch {
      return false;
    }
  }
  if (!isObject(value)) return false;
  const error = value.error ?? (isObject(value.response) ? value.response.error : value);

  return isObject(error) && error.code === 'hardened_oauth_rule_missing' &&
    error.type === 'rejected_by_hardened_oauth_boundary';
}

/** Raw Codex events precede Pi's normalization of response.done to response.completed. */
export function createCompactionCollector(onFailure?: () => void) {
  let observedBytes = 0;
  let completed = false;
  let failure: Error | undefined;
  let rejected = false;
  const items = new Map<string, JsonObject>();

  return {
    observe(event: unknown): void {
      if (failure) return;

      try {
        rejected ||= oauthRejection(event);
        if (!isObject(event) || typeof event.type !== 'string') throw new Error('Invalid compaction event');
        observedBytes += bytes(event);
        if (observedBytes > HISTORY_BYTES) throw new Error('Compaction response exceeded 8 MiB');
        if (completed) throw new Error('Compaction events followed completion');
        if (event.type === 'error' || event.type === 'response.failed' || event.type === 'response.incomplete') {
          throw new Error('Compaction stream failed or was incomplete');
        }

        const candidates: unknown[] = [];
        if (event.type === 'response.output_item.done' && isObject(event.item) && event.item.type === 'compaction') {
          candidates.push(event.item);
        }
        if (event.type === 'response.completed' || event.type === 'response.done') {
          if (!isObject(event.response) || event.response.status !== 'completed' ||
              !Array.isArray(event.response.output)) throw new Error('Invalid compaction completion');
          candidates.push(...event.response.output.filter((item) => isObject(item) && item.type === 'compaction'));
          completed = true;
        }
        for (const candidate of candidates) {
          const item = validateItem(candidate);
          items.set(stableJson(item), item);
        }
        if (items.size > 1) throw new Error('Compaction returned conflicting or multiple checkpoints');
      } catch (error) {
        // Provider instrumentation catches callback exceptions; retain failure for finish().
        failure = error instanceof Error ? error : new Error('Invalid compaction stream');
        onFailure?.();
      }
    },
    get rejected(): boolean { return rejected; },
    get failed(): boolean { return failure !== undefined; },
    finish(): JsonObject {
      if (failure) throw failure;
      if (!completed || items.size !== 1) throw new Error('Missing successful opaque compaction completion');

      return structuredClone([...items.values()][0]);
    },
  };
}

interface Owner {
  sessionId: string;
  lifetime: AbortController;
  operation?: AbortController;
  paused: Set<string>;
  warnings: Set<string>;
}

export function registerCodexCompaction(pi: ExtensionAPI): void {
  const owners = new WeakMap<object, Owner>();
  const ownerFor = (ctx: ExtensionContext): Owner => {
    let owner = owners.get(ctx.sessionManager);
    const sessionId = ctx.sessionManager.getSessionId();
    if (!owner || owner.sessionId !== sessionId) {
      owner?.lifetime.abort();
      owner = { sessionId, lifetime: new AbortController(), paused: new Set(), warnings: new Set() };
      owners.set(ctx.sessionManager, owner);
    }

    return owner;
  };
  const cancelOperation = (ctx: ExtensionContext) => {
    const owner = owners.get(ctx.sessionManager);
    owner?.operation?.abort();
    if (owner) owner.operation = undefined;
    ctx.ui.setStatus('codex-compact', undefined);
  };
  const warnReplay = (ctx: ExtensionContext) => {
    const owner = ownerFor(ctx);
    const key = `${ctx.sessionManager.getBranch().at(-1)?.id}:${routeKey(ctx.model)}`;
    if (owner.warnings.has(key)) return;
    owner.warnings.add(key);
    ctx.ui.notify('Opaque Codex checkpoint could not replay safely; older context is unavailable on this request. Use the original model with pi-model-controls enabled.', 'warning');
  };

  pi.registerCommand('compact-server-side', {
    description: 'Compact now using OpenAI Codex server-side compaction',
    handler: async (args, ctx) => {
      if (args.trim()) {
        ctx.ui.notify('Usage: /compact-server-side', 'warning');
        return;
      }
      if (!officialCodex(ctx.model)) {
        ctx.ui.notify('/compact-server-side requires the official openai-codex Responses provider.', 'warning');
        return;
      }

      ctx.compact({ onError: () => ctx.ui.notify('Codex compaction did not complete; history preserved.', 'warning') });
    },
  });

  pi.on('session_before_compact', async (event: SessionBeforeCompactEvent, ctx) => {
    const checkpoint = activeCheckpoint(event.branchEntries);
    const model = ctx.model;
    if (!officialCodex(model)) {
      if (checkpoint.claimed) {
        ctx.ui.notify('Compaction cancelled: the opaque Codex checkpoint cannot replay on this model.', 'warning');
        return { cancel: true };
      }
      return undefined;
    }

    const owner = ownerFor(ctx);
    cancelOperation(ctx);
    const operation = new AbortController();
    owner.operation = operation;
    const key = routeKey(model);
    const leafId = event.branchEntries.at(-1)?.id;
    const signal = AbortSignal.any([event.signal, owner.lifetime.signal, operation.signal, AbortSignal.timeout(300_000)]);
    const ownsOperation = () => owners.get(ctx.sessionManager) === owner &&
      owner.operation === operation && ctx.sessionManager.getSessionId() === owner.sessionId &&
      routeKey(ctx.model) === key && ctx.sessionManager.getBranch().at(-1)?.id === leafId;
    const current = () => !signal.aborted && ownsOperation();
    const collector = createCompactionCollector(() => operation.abort());

    try {
      if (!current()) return { cancel: true };
      if (owner.paused.has(key)) {
        ctx.ui.notify('Codex compaction is paused after an OAuth operation rejection; /reload retries it. Checkpoint replay remains enabled.', 'warning');
        return { cancel: true };
      }
      if (checkpoint.claimed && (!checkpoint.entry || !checkpoint.details || !compatible(checkpoint.details, model))) {
        throw new Error('Invalid or incompatible active checkpoint');
      }

      const projection = buildSessionProjection(event.branchEntries);
      const keptIndex = projection.entries.findIndex((entry) => entry.sourceEntry.id === event.preparation.firstKeptEntryId);
      if (keptIndex < 0) throw new Error('Missing canonical compaction cut point');
      const kept = projection.entries.slice(keptIndex).flatMap((entry) => entry.messages)
        .filter((message) => message.role !== 'system');
      const conversation = projection.messages.filter((message) => message.role !== 'system');
      const messages = checkpoint.details && checkpoint.entry ?
        projectCheckpoint(conversation, checkpoint.details, checkpoint.entry.summary, event.branchEntries) : conversation;
      if (!messages) throw new Error('Checkpoint projection did not match retained context');

      const available = new Map(pi.getAllTools().map((tool) => [tool.name, tool]));
      const tools = pi.getActiveTools().flatMap((name) => {
        const tool = available.get(name);
        return tool ? [{ name: tool.name, description: tool.description, parameters: tool.parameters }] : [];
      });
      let sentInput: JsonObject[] | undefined;
      let usage: Usage | undefined;
      ctx.ui.setStatus('codex-compact', 'Codex server compaction…');

      // Registry streaming resolves and refreshes authentication, headers and credential-owned routing.
      const stream = ctx.modelRegistry.stream(model, {
        systemPrompt: ctx.getSystemPrompt(), messages: convertToLlm(messages), tools,
      }, {
        transport: 'sse', cacheRetention: 'none', signal, timeoutMs: 300_000, maxRetries: 0,
        onPayload: (payload: unknown, resolvedModel: Model) => {
          if (!officialCodex(resolvedModel) || resolvedModel.id !== model.id) {
            throw new Error('Resolved compaction route is not official Codex');
          }
          if (!current() || sentInput) throw new Error('Compaction request ownership changed or payload repeated');
          const expanded = checkpoint.details ? rewriteMarker(payload, checkpoint.details) : payload;
          if (!isObject(expanded) || !Array.isArray(expanded.input) || !expanded.input.every(isObject) ||
              expanded.input.some((item) => item.type === 'compaction_trigger')) throw new Error('Invalid Responses compaction input');
          sentInput = structuredClone(expanded.input);

          return { ...expanded, input: [...expanded.input, { type: 'compaction_trigger' }],
            tool_choice: 'none', store: false, service_tier: 'default' };
        },
        onProviderStreamEvent: (raw: unknown) => collector.observe(raw),
        fetch: async (input: Parameters<typeof fetch>[0], init?: Parameters<typeof fetch>[1]) => {
          const url = new URL(input instanceof Request ? input.url : String(input));
          if (!current() || url.origin !== 'https://chatgpt.com' || url.username || url.password ||
              url.pathname !== '/backend-api/codex/responses') throw new Error('Unsafe compaction dispatch');
          const response = await globalThis.fetch(input, { ...init, redirect: 'error' });
          if (!response.body) return response;

          // Bound wire bytes before Pi parses SSE/JSON, including rejected HTTP response bodies.
          let size = 0;
          const limit = response.ok ? HISTORY_BYTES : 64 * 1024;
          const body = response.body.pipeThrough(new TransformStream<Uint8Array, Uint8Array>({
            transform(chunk, destination) {
              size += chunk.byteLength;
              if (size > limit) throw new Error('Compaction response exceeded its byte limit');
              destination.enqueue(chunk);
            },
          }), { signal });
          const bounded = new Response(body, {
            status: response.status, statusText: response.statusText, headers: response.headers,
          });
          if (response.ok) return bounded;

          const text = await bounded.text();
          if (oauthRejection(text)) owner.paused.add(key);

          return new Response(text, {
            status: response.status, statusText: response.statusText, headers: response.headers,
          });
        },
      });
      for await (const streamed of stream) {
        if (collector.failed) throw new Error('Invalid compaction response');
        if (!current()) return { cancel: true };
        if (streamed.type === 'error') {
          if (oauthRejection(streamed.error.errorMessage)) owner.paused.add(key);
          throw new Error('Provider rejected compaction');
        }
        if (streamed.type === 'done') {
          if (streamed.message.stopReason !== 'stop') throw new Error('Provider compaction was not complete');
          usage = streamed.message.usage;
        }
      }
      if (collector.failed) throw new Error('Invalid compaction response');
      if (!current()) return { cancel: true };
      if (!sentInput || !usage) throw new Error('Missing compaction payload or usage');

      const history = replacementHistory(sentInput, collector.finish());
      const details = createCheckpoint(model, history, kept);
      return { compaction: {
        summary: `Responses compaction checkpoint ${details.checkpointId} stores older history opaquely. Full replay requires pi-model-controls and the same Codex model; without them only retained recent messages are available.`,
        firstKeptEntryId: event.preparation.firstKeptEntryId, tokensBefore: event.preparation.tokensBefore,
        usage, details,
      } };
    } catch {
      // Never send server errors/credentials to the terminal or replace opaque history with plaintext.
      if (collector.rejected) owner.paused.add(key);
      if (ownsOperation() && !event.signal.aborted && !owner.lifetime.signal.aborted) ctx.ui.notify(owner.paused.has(key) ?
        'Codex OAuth is not authorized for this compaction operation; paused until /reload. History and checkpoint replay are preserved.' :
        'Codex server compaction failed; compaction cancelled and history preserved.', 'warning');
      return { cancel: true };
    } finally {
      operation.abort();
      if (owners.get(ctx.sessionManager) === owner && owner.operation === operation) {
        owner.operation = undefined;
        ctx.ui.setStatus('codex-compact', undefined);
      }
    }
  });

  pi.on('context', (event, ctx) => {
    const checkpoint = activeCheckpoint(ctx.sessionManager.getBranch());
    if (!checkpoint.claimed) return undefined;
    if (checkpoint.details && checkpoint.entry && compatible(checkpoint.details, ctx.model)) {
      const messages = projectCheckpoint(event.messages, checkpoint.details, checkpoint.entry.summary,
        ctx.sessionManager.getBranch());
      if (messages) return { messages };
    }
    warnReplay(ctx);
    return undefined;
  });

  pi.on('before_provider_request', (event, ctx) => {
    const checkpoint = activeCheckpoint(ctx.sessionManager.getBranch());
    if (!checkpoint.claimed || !checkpoint.details || !compatible(checkpoint.details, ctx.model)) return undefined;
    try {
      return rewriteMarker(event.payload, checkpoint.details);
    } catch {
      // Pi catches hook exceptions and would dispatch unchanged; report the fallback explicitly.
      warnReplay(ctx);
      return undefined;
    }
  });

  pi.on('session_start', (_event, ctx) => {
    owners.get(ctx.sessionManager)?.lifetime.abort();
    owners.delete(ctx.sessionManager);
    ownerFor(ctx);
    ctx.ui.setStatus('codex-compact', undefined);
  });
  pi.on('model_select', (_event, ctx) => cancelOperation(ctx));
  pi.on('session_tree', (_event, ctx) => cancelOperation(ctx));
  pi.on('session_before_switch', (_event, ctx) => cancelOperation(ctx));
  pi.on('session_before_fork', (_event, ctx) => cancelOperation(ctx));
  pi.on('session_before_tree', (_event, ctx) => cancelOperation(ctx));
  pi.on('session_shutdown', (_event, ctx) => {
    ownerFor(ctx).lifetime.abort();
    cancelOperation(ctx);
  });
}

export const ANTHROPIC_COMPACTION_KIND = 'pi-anthropic-compaction';
export const ANTHROPIC_COMPACTION_BETA = 'compact-2026-09-04';

export interface AnthropicCheckpoint {
  kind: typeof ANTHROPIC_COMPACTION_KIND;
  version: 1;
  provider: string;
  api: string;
  modelId: string;
  /** Signed `compaction` block, kept exactly as Anthropic returned it. */
  block: JsonObject;
  createdAt: string;
}

function validateAnthropicBlock(value: unknown): JsonObject {
  if (!isObject(value) || value.type !== 'compaction' || typeof value.content !== 'string' ||
      !value.content.trim() || typeof value.signature !== 'string' || !value.signature ||
      bytes(value) > ITEM_BYTES) throw new Error('Invalid or oversized Anthropic compaction block');

  return structuredClone(value);
}

export function parseAnthropicCheckpoint(value: unknown): AnthropicCheckpoint | undefined {
  if (!isObject(value) || value.kind !== ANTHROPIC_COMPACTION_KIND || value.version !== 1) return undefined;
  if (typeof value.provider !== 'string' || typeof value.api !== 'string' ||
      typeof value.modelId !== 'string' || typeof value.createdAt !== 'string') return undefined;

  try {
    return {
      kind: ANTHROPIC_COMPACTION_KIND, version: 1, provider: value.provider, api: value.api,
      modelId: value.modelId, block: validateAnthropicBlock(value.block), createdAt: value.createdAt,
    };
  } catch {
    return undefined;
  }
}

/** The newest compaction entry, when it holds a signed block matching its plaintext summary. */
export function activeAnthropicCheckpoint(entries: readonly SessionEntry[]):
  { entry: CompactionEntry; details: AnthropicCheckpoint } | undefined {
  const entry = [...entries].reverse().find((candidate) => candidate.type === 'compaction');
  const details = entry?.type === 'compaction' ? parseAnthropicCheckpoint(entry.details) : undefined;
  if (entry?.type !== 'compaction' || !details || details.block.content !== entry.summary) return undefined;

  return { entry, details };
}

function anthropicCompatible(details: AnthropicCheckpoint, model: Model | undefined): boolean {
  return isAnthropicFastModel(model) && details.provider === model?.provider &&
    details.api === model.api && details.modelId === model.id;
}

function withCompactionBeta(payload: JsonObject): JsonObject {
  const betas = Array.isArray(payload.betas) ? payload.betas : [];

  return { ...payload, betas: [...new Set([...betas, ANTHROPIC_COMPACTION_BETA])] };
}

/**
 * Pi renders the compaction summary as the first user message; Anthropic expects the signed block
 * first instead, in place of the messages it summarizes.
 */
export function injectAnthropicBlock(payload: unknown, details: AnthropicCheckpoint, summary: string): JsonObject {
  if (!isObject(payload) || !Array.isArray(payload.messages)) throw new Error('Missing Anthropic messages');

  const rendered = convertToLlm([{ role: 'compactionSummary', summary, tokensBefore: 0, timestamp: 0 }])[0];
  const text = rendered?.role === 'user' && Array.isArray(rendered.content) &&
    rendered.content[0]?.type === 'text' ? rendered.content[0].text : undefined;
  const [first, ...rest] = payload.messages;
  const part = isObject(first) && first.role === 'user' && Array.isArray(first.content) &&
    first.content.length === 1 ? first.content[0] : undefined;
  if (!text || !isObject(part) || part.type !== 'text' || part.text !== text) {
    throw new Error('Expected the compaction summary as the first message');
  }

  const carriesBlock = (message: unknown) => isObject(message) && Array.isArray(message.content) &&
    message.content.some((block) => isObject(block) && block.type === 'compaction');
  if (rest.some(carriesBlock)) throw new Error('Request already carries a compaction block');

  // Keep Pi's cache breakpoint: on the block it caches everything up to the summary.
  const block = { ...structuredClone(details.block), ...(part.cache_control ? { cache_control: part.cache_control } : {}) };

  return withCompactionBeta({ ...payload, messages: [{ role: 'assistant', content: [block] }, ...rest] });
}

export function createAnthropicCompactionCollector(onFailure?: () => void) {
  let block: JsonObject | undefined;
  let stopReason: string | undefined;
  let iterations: JsonObject[] = [];
  let failure: Error | undefined;

  return {
    observe(event: unknown): void {
      if (failure) return;

      try {
        if (!isObject(event) || typeof event.type !== 'string') throw new Error('Invalid compaction event');
        if (event.type === 'error') throw new Error('Compaction stream failed');

        // The block arrives whole in content_block_start; any other content means no summary.
        if (event.type === 'content_block_start') {
          if (block || !isObject(event.content_block) || event.content_block.type !== 'compaction') {
            throw new Error('Unexpected content in compaction response');
          }
          block = validateAnthropicBlock(event.content_block);
        }
        if (event.type === 'content_block_delta') throw new Error('Unexpected delta in compaction response');

        if (event.type === 'message_delta') {
          if (isObject(event.delta) && typeof event.delta.stop_reason === 'string') stopReason = event.delta.stop_reason;
          if (isObject(event.usage) && Array.isArray(event.usage.iterations)) {
            iterations = event.usage.iterations.filter(isObject);
          }
        }
      } catch (error) {
        // Provider instrumentation swallows callback exceptions; retain failure for finish().
        failure = error instanceof Error ? error : new Error('Invalid compaction stream');
        onFailure?.();
      }
    },
    get failed(): boolean { return failure !== undefined; },
    get complete(): boolean { return !failure && stopReason === 'compaction' && block !== undefined; },
    finish(): { block: JsonObject; iterations: JsonObject[] } {
      if (failure) throw failure;
      if (stopReason !== 'compaction' || !block) throw new Error(`Compaction stopped with ${stopReason ?? 'no stop reason'}`);

      return { block: structuredClone(block), iterations: structuredClone(iterations) };
    },
  };
}

/** Top-level usage of a compaction response is zero; the summarization call is in iterations. */
function iterationUsage(model: Model, iterations: JsonObject[]): Usage {
  const sum = (key: string) => iterations.reduce((total, iteration) =>
    total + (typeof iteration[key] === 'number' ? iteration[key] : 0), 0);
  const input = sum('input_tokens');
  const output = sum('output_tokens');
  const cacheRead = sum('cache_read_input_tokens');
  const cacheWrite = sum('cache_creation_input_tokens');
  const cost = {
    input: input * model.cost.input / 1e6,
    output: output * model.cost.output / 1e6,
    cacheRead: cacheRead * model.cost.cacheRead / 1e6,
    cacheWrite: cacheWrite * model.cost.cacheWrite / 1e6,
  };

  return {
    input, output, cacheRead, cacheWrite, totalTokens: input + output + cacheRead + cacheWrite,
    cost: { ...cost, total: cost.input + cost.output + cost.cacheRead + cost.cacheWrite },
  };
}

/**
 * Anthropic on-demand compaction (`compact-2026-09-04`) for the official Messages endpoint. The
 * messages before Pi's cut point are summarized server-side; the kept tail follows the signed
 * block verbatim. The summary is also stored as Pi's plaintext summary, so other models, or a
 * failed injection, degrade to an ordinary Pi compaction. Failures fall back to Pi compaction.
 */
export function registerAnthropicCompaction(pi: ExtensionAPI): void {
  const paused = new Set<string>();
  const warned = new Set<string>();

  pi.on('session_before_compact', async (event: SessionBeforeCompactEvent, ctx) => {
    const model = ctx.model;
    if (!isAnthropicFastModel(model) || !model || event.signal.aborted) return undefined;

    // Opaque Codex checkpoints are owned (and cancelled) by the Codex handler.
    const key = routeKey(model);
    if (activeCheckpoint(event.branchEntries).claimed || paused.has(key)) return undefined;

    // `instructions` would replace Anthropic's summarization prompt instead of focusing it.
    if (event.customInstructions?.trim()) return undefined;

    const projection = buildSessionProjection(event.branchEntries);
    const keptIndex = projection.entries.findIndex((entry) => entry.sourceEntry.id === event.preparation.firstKeptEntryId);
    const summarized = projection.entries.slice(0, Math.max(keptIndex, 0)).flatMap((entry) => entry.messages)
      .filter((message) => message.role !== 'system');
    const last = summarized.at(-1);
    const openToolCall = last?.role === 'assistant' && last.content.some((part) => part.type === 'toolCall');
    const nothingNew = !summarized.some((message) => message.role !== 'compactionSummary');
    if (keptIndex < 0 || nothingNew || openToolCall) return undefined;

    const previous = activeAnthropicCheckpoint(event.branchEntries);
    const replay = previous && anthropicCompatible(previous.details, model) ? previous : undefined;
    const leafId = event.branchEntries.at(-1)?.id;
    const operation = new AbortController();
    const signal = AbortSignal.any([event.signal, operation.signal, AbortSignal.timeout(300_000)]);
    const collector = createAnthropicCompactionCollector(() => operation.abort());
    const available = new Map(pi.getAllTools().map((tool) => [tool.name, tool]));
    const tools = pi.getActiveTools().flatMap((name) => {
      const tool = available.get(name);
      return tool ? [{ name: tool.name, description: tool.description, parameters: tool.parameters }] : [];
    });
    const thinking = pi.getThinkingLevel();
    ctx.ui.setStatus('anthropic-compact', 'Anthropic server compaction…');

    try {
      // Same system prompt, tools, thinking and session as the conversation, so the summarized
      // prefix can hit the prompt cache and kept thinking stays bound to the same request shape.
      const stream = ctx.modelRegistry.streamSimple(model, {
        systemPrompt: ctx.getSystemPrompt(), messages: convertToLlm(summarized), tools,
      }, {
        reasoning: thinking === 'off' ? undefined : thinking, sessionId: ctx.sessionManager.getSessionId(),
        signal, timeoutMs: 300_000, maxRetries: 0,
        onPayload: (payload: unknown, resolvedModel: Model) => {
          if (!isAnthropicFastModel(resolvedModel) || resolvedModel.id !== model.id || !isObject(payload)) {
            throw new Error('Resolved compaction route is not the official Anthropic endpoint');
          }
          const request = replay ? injectAnthropicBlock(payload, replay.details, replay.entry.summary) :
            withCompactionBeta(payload);

          return { ...request, compaction: { type: 'summarize' } };
        },
        onProviderStreamEvent: (raw: unknown) => collector.observe(raw),
        fetch: async (input: Parameters<typeof fetch>[0], init?: Parameters<typeof fetch>[1]) => {
          const url = new URL(input instanceof Request ? input.url : String(input));
          if (url.origin !== 'https://api.anthropic.com' || url.pathname !== '/v1/messages') {
            throw new Error('Unsafe compaction dispatch');
          }
          const response = await globalThis.fetch(input, { ...init, redirect: 'error' });
          // Unsupported models, betas or credentials are not transient: stop asking until /reload.
          if ([400, 401, 403, 404].includes(response.status)) paused.add(key);

          return response;
        },
      });

      let usage: Usage | undefined;
      for await (const streamed of stream) {
        if (collector.failed) throw new Error('Invalid compaction response');
        if (streamed.type === 'done') usage = streamed.message.usage;
        // Pi does not know the `compaction` stop reason and ends the stream with an error after it.
        if (streamed.type === 'error' && !collector.complete) throw new Error('Provider rejected compaction');
      }

      const { block, iterations } = collector.finish();
      const unchanged = ctx.sessionManager.getBranch().at(-1)?.id === leafId && routeKey(ctx.model) === key;
      if (event.signal.aborted || !unchanged) return { cancel: true };

      const details: AnthropicCheckpoint = {
        kind: ANTHROPIC_COMPACTION_KIND, version: 1, provider: model.provider, api: model.api,
        modelId: model.id, block, createdAt: new Date().toISOString(),
      };

      return { compaction: {
        summary: block.content as string, firstKeptEntryId: event.preparation.firstKeptEntryId,
        tokensBefore: event.preparation.tokensBefore,
        usage: iterations.length > 0 || !usage ? iterationUsage(model, iterations) : usage, details,
      } };
    } catch {
      if (event.signal.aborted) return { cancel: true };

      // Never echo server errors (they can include request details); Pi's summarizer takes over.
      ctx.ui.notify(paused.has(key) ?
        'Anthropic rejected server compaction for this model; using Pi compaction until /reload.' :
        'Anthropic server compaction failed; using Pi compaction.', 'warning');
      return undefined;
    } finally {
      operation.abort();
      ctx.ui.setStatus('anthropic-compact', undefined);
    }
  });

  pi.on('before_provider_request', (event, ctx) => {
    const model = ctx.model;
    if (!isAnthropicFastModel(model) || !isObject(event.payload) || event.payload.model !== model?.id) return undefined;

    const active = activeAnthropicCheckpoint(ctx.sessionManager.getBranch());
    if (!active || !anthropicCompatible(active.details, model)) return undefined;

    try {
      return injectAnthropicBlock(event.payload, active.details, active.entry.summary);
    } catch {
      // The plaintext summary still reaches Claude; only the signed block is lost.
      if (!warned.has(active.entry.id)) {
        warned.add(active.entry.id);
        ctx.ui.notify('Anthropic compaction block could not be attached; sending its summary as plain text.', 'warning');
      }
      return undefined;
    }
  });
}
