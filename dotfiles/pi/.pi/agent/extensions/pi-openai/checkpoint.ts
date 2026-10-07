// Checkpoint contract and replay adapted from @narumitw/pi-codex-compact 0.55.0.
// Copyright (c) 2026 Narumi. MIT; see THIRD-PARTY-LICENSE in this directory.
import { createHash, randomUUID } from 'node:crypto';
import {
  buildSessionProjection,
  sessionEntryToContextMessages,
  type CompactionEntry,
  type SessionEntry,
} from '@earendil-works/pi-coding-agent';

export type Message = ReturnType<typeof buildSessionProjection>['messages'][number];
export type JsonObject = Record<string, unknown>;
export const CHECKPOINT_KIND = 'pi-codex-remote-compaction';
export const HISTORY_BYTES = 8 * 1024 * 1024;
export const ITEM_BYTES = 2 * 1024 * 1024;

export interface Checkpoint {
  kind: typeof CHECKPOINT_KIND;
  version: 3;
  checkpointId: string;
  provider: string;
  api: string;
  profile: 'codex-responses-v1' | 'openai-responses-v1';
  modelId: string;
  protocol: 'remote-v2' | 'responses-compact' | 'context-management';
  replacementHistory: JsonObject[];
  keptMessageFingerprints: string[];
  createdAt: string;
}

export function isObject(value: unknown): value is JsonObject {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

export function bytes(value: unknown): number {
  return Buffer.byteLength(JSON.stringify(value), 'utf8');
}

export function validateItem(value: unknown): JsonObject {
  if (!isObject(value) || value.type !== 'compaction' ||
      typeof value.encrypted_content !== 'string' || !value.encrypted_content ||
      (value.status !== undefined && value.status !== 'completed') || bytes(value) > ITEM_BYTES) {
    throw new Error('Invalid or oversized opaque compaction item');
  }

  return structuredClone(value);
}

function stableValue(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(stableValue);
  if (!isObject(value)) return value;

  return Object.fromEntries(Object.entries(value).sort(([a], [b]) => a.localeCompare(b))
    .map(([key, child]) => [key, stableValue(child)]));
}

export function stableJson(value: unknown): string {
  return JSON.stringify(stableValue(value));
}

export function fingerprint(message: Message): string {
  return createHash('sha256').update(stableJson(message)).digest('hex');
}

export function marker(id: string): string {
  return [
    `[PI_CODEX_REMOTE_CHECKPOINT:${id}] Opaque checkpoint injection failed.`,
    'Do not infer missing history; tell the user to re-enable pi-openai with the same Codex model.',
  ].join(' ');
}

function validateHistory(history: JsonObject[], protocol: Checkpoint['protocol']): void {
  if (history.length === 0 || bytes(history) > HISTORY_BYTES) throw new Error('Invalid checkpoint history');
  if (protocol !== 'context-management') {
    validateItem(history.at(-1));
    for (const message of history.slice(0, -1)) {
      if (message.role !== 'user' || (message.type !== undefined && message.type !== 'message') ||
          bytes(message) > ITEM_BYTES || !Array.isArray(message.content) || !message.content.length ||
          !message.content.every((part) => {
            if (!isObject(part)) return false;
            if (part.type === 'input_text') return typeof part.text === 'string';
            if (part.type !== 'input_image') return false;
            const detail = part.detail;
            const validDetail = detail === undefined || detail === null ||
              ['auto', 'low', 'high', 'original'].includes(String(detail));
            const validReferences = (part.file_id == null || typeof part.file_id === 'string') &&
              (part.image_url == null || typeof part.image_url === 'string');

            return validDetail && validReferences &&
              ((typeof part.image_url === 'string' && part.image_url.length > 0) ||
               (typeof part.file_id === 'string' && part.file_id.length > 0));
          })) throw new Error('Unsafe retained checkpoint input');
    }
    return;
  }

  // Older context-management checkpoints contain inert completed output after the checkpoint.
  validateItem(history[0]);
  for (const item of history.slice(1)) {
    if (bytes(item) > ITEM_BYTES || (item.status !== undefined && item.status !== 'completed')) {
      throw new Error('Invalid maintenance output');
    }
    if (item.type === 'reasoning') {
      if (typeof item.encrypted_content !== 'string' || !item.encrypted_content ||
          !Array.isArray(item.summary) || !item.summary.every((part) =>
            isObject(part) && part.type === 'summary_text' && typeof part.text === 'string')) {
        throw new Error('Invalid encrypted maintenance reasoning');
      }
    } else if (item.type !== 'message' || item.role !== 'assistant' ||
        !Array.isArray(item.content) || !item.content.every((part) => isObject(part) &&
          ((part.type === 'output_text' && typeof part.text === 'string') ||
           (part.type === 'refusal' && typeof part.refusal === 'string')))) {
      throw new Error('Unsafe maintenance output');
    }
  }
}

export function parseCheckpoint(value: unknown): Checkpoint | undefined {
  if (!isObject(value)) return undefined;

  try {
    const v1 = value.version === 1 && value.api === 'openai-codex-responses' &&
      value.protocol === 'remote-compaction-v2';
    const v2 = value.version === 2 &&
      ['openai-codex-responses', 'openai-responses', 'azure-openai-responses'].includes(String(value.api)) &&
      ['remote-v2', 'responses-compact'].includes(String(value.protocol));
    const v3 = value.version === 3 && typeof value.api === 'string' &&
      value.api.length > 0 && value.api.length <= 256 &&
      ['codex-responses-v1', 'openai-responses-v1'].includes(String(value.profile)) &&
      ['remote-v2', 'responses-compact', 'context-management'].includes(String(value.protocol));
    const profile = value.api === 'openai-codex-responses' ? 'codex-responses-v1' :
      value.api === 'openai-responses' || value.api === 'azure-openai-responses' ?
        'openai-responses-v1' : value.profile;
    const protocol = v1 ? 'remote-v2' : value.protocol;
    const boundedString = (field: unknown, min: number, max: number): field is string =>
      typeof field === 'string' && field.length >= min && field.length <= max;

    if (value.kind !== CHECKPOINT_KIND || (!v1 && !v2 && !v3) ||
        !boundedString(value.checkpointId, 8, 128) || !boundedString(value.provider, 1, 256) ||
        !boundedString(value.modelId, 1, 512) || !boundedString(value.createdAt, 0, 64) ||
        (profile !== 'codex-responses-v1' && profile !== 'openai-responses-v1') ||
        (v3 && value.profile !== profile) ||
        !Array.isArray(value.replacementHistory) || !value.replacementHistory.every(isObject) ||
        !Array.isArray(value.keptMessageFingerprints) || value.keptMessageFingerprints.length > 100_000 ||
        !value.keptMessageFingerprints.every((hash) => typeof hash === 'string' && /^[a-f0-9]{64}$/.test(hash)) ||
        bytes(value) > 10 * 1024 * 1024) return undefined;

    validateHistory(value.replacementHistory, protocol as Checkpoint['protocol']);

    return {
      kind: CHECKPOINT_KIND, version: 3, checkpointId: value.checkpointId, provider: value.provider,
      api: value.api as string, profile, modelId: value.modelId,
      protocol: protocol as Checkpoint['protocol'],
      replacementHistory: structuredClone(value.replacementHistory),
      keptMessageFingerprints: [...value.keptMessageFingerprints], createdAt: value.createdAt,
    };
  } catch {
    return undefined;
  }
}

export function activeCheckpoint(entries: readonly SessionEntry[]): {
  claimed: boolean;
  entry?: CompactionEntry;
  details?: Checkpoint;
} {
  let entry: CompactionEntry | undefined;
  for (let index = entries.length - 1; index >= 0; index--) {
    const candidate = entries[index];
    if (candidate.type === 'compaction') {
      entry = candidate;
      break;
    }
  }
  if (!entry) return { claimed: false };

  return {
    claimed: isObject(entry.details) && entry.details.kind === CHECKPOINT_KIND,
    entry,
    details: parseCheckpoint(entry.details),
  };
}

export function projectCheckpoint(
  messages: readonly Message[], details: Checkpoint, summary: string, branchEntries: SessionEntry[],
): Message[] | undefined {
  const index = messages.findIndex((message) => message.role === 'compactionSummary' && message.summary === summary);
  if (index < 0) return undefined;

  // Upstream fingerprints could include historical summaries (and their system messages) that
  // Pi's canonical projection now suppresses. Skip only metadata verified in this branch.
  const suppressedFingerprints = new Set(buildSessionProjection(branchEntries).entries
    .filter((entry) => entry.sourceEntry.type === 'compaction' && entry.messages.length === 0)
    .flatMap((entry) => sessionEntryToContextMessages(entry.sourceEntry))
    .map(fingerprint));
  const timestamp = messages[index].timestamp;
  const olderSummary = (message: Message) => message.role === 'compactionSummary' &&
    Number.isFinite(timestamp) && Number.isFinite(message.timestamp) && message.timestamp < timestamp;
  let end = index + 1;
  for (const hash of details.keptMessageFingerprints) {
    while (end < messages.length && olderSummary(messages[end]) && fingerprint(messages[end]) !== hash) end++;
    if (end < messages.length && fingerprint(messages[end]) === hash) {
      end++;
      continue;
    }

    if (!suppressedFingerprints.has(hash)) return undefined;
  }
  while (end < messages.length && olderSummary(messages[end])) end++;

  return [...messages.slice(0, index), {
    role: 'user', content: [{ type: 'text', text: marker(details.checkpointId) }], timestamp,
  }, ...messages.slice(end)];
}

export function rewriteMarker(payload: unknown, details: Checkpoint): JsonObject {
  if (!isObject(payload) || !Array.isArray(payload.input)) throw new Error('Missing Responses input');
  const text = marker(details.checkpointId);
  const matches = payload.input.flatMap((item, index) => isObject(item) && item.role === 'user' &&
    Array.isArray(item.content) && item.content.length === 1 && isObject(item.content[0]) &&
    item.content[0].type === 'input_text' && item.content[0].text === text ? [index] : []);
  if (matches.length !== 1) throw new Error('Expected exactly one checkpoint marker');

  const index = matches[0];
  return { ...payload, input: [
    ...payload.input.slice(0, index), ...structuredClone(details.replacementHistory),
    ...payload.input.slice(index + 1),
  ] };
}

export function replacementHistory(input: JsonObject[], item: JsonObject): JsonObject[] {
  const opaque = validateItem(item);
  let remainingBytes = HISTORY_BYTES - bytes(opaque);
  let remainingChars = 64_000 * 4;
  const retained: JsonObject[] = [];

  // Preserve newest fitting user inputs; the opaque item holds the server's compressed history.
  for (let index = input.length - 1; index >= 0; index--) {
    const candidate = input[index];
    if (candidate.role !== 'user' || !Array.isArray(candidate.content)) continue;
    const media = candidate.content.some((part) => isObject(part) && part.type === 'input_image');
    const chars = candidate.content.reduce((sum, part) => sum +
      (isObject(part) && part.type === 'input_text' && typeof part.text === 'string' ? part.text.length : 0), 0);
    if ((media && bytes(candidate) > ITEM_BYTES) || bytes(candidate) > remainingBytes || chars > remainingChars) continue;

    retained.push(structuredClone(candidate));
    remainingBytes -= bytes(candidate);
    remainingChars -= chars;
  }

  return [...retained.reverse(), opaque];
}

export function createCheckpoint(model: { provider: string; api: string; id: string },
  history: JsonObject[], kept: Message[]): Checkpoint {
  const details: Checkpoint = {
    kind: CHECKPOINT_KIND, version: 3, checkpointId: randomUUID(), provider: model.provider,
    api: model.api, profile: 'codex-responses-v1', modelId: model.id, protocol: 'remote-v2',
    replacementHistory: history, keptMessageFingerprints: kept.map(fingerprint), createdAt: new Date().toISOString(),
  };
  if (!parseCheckpoint(details)) throw new Error('Invalid generated checkpoint');

  return details;
}
