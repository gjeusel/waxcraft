// Subscription sign-ins for Pi's built-in providers. Mistral: adapted from
// https://github.com/5omeOtherGuy/pi-mistral-subscription (MIT, v0.2.0), without its deprecated
// `mistral-subscription` provider. It mirrors Mistral Vibe's browser sign-in, which returns a plain
// API key billed against the subscription budget (usage type "Vibe Code").
import { createHash, randomBytes } from 'node:crypto';
import { isDeepStrictEqual } from 'node:util';
import type { Api, Model, OAuthCredentials, OAuthLoginCallbacks } from '@earendil-works/pi-ai';
import type { ExtensionAPI, ExtensionContext } from '@earendil-works/pi-coding-agent';

const MISTRAL_PROVIDER_ID = 'mistral';
const MISTRAL_BASE_URL = 'https://api.mistral.ai';
const BROWSER_AUTH_BASE_URL = 'https://console.mistral.ai';
const BROWSER_AUTH_API_BASE_URL = 'https://console.mistral.ai/api';
const SIGN_IN_PATH = '/vibe/sign-in';
const API_KEY_EXPIRES_MS = 10 * 365 * 24 * 60 * 60 * 1000;
const POLL_INTERVAL_MS = 3000;

type SignInProcess = { processId: string; signInUrl: string; pollUrl: string; expiresAt: number };
type PollStatus = 'pending' | 'completed' | 'expired' | 'denied' | 'error';
const POLL_STATUSES: readonly PollStatus[] = ['pending', 'completed', 'expired', 'denied', 'error'];

// ── OAuth ─────────────────────────────────────────────────────────────────────

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

async function responseRecord(response: Response, message: string): Promise<Record<string, unknown>> {
  if (!response.ok) throw new Error(`${message} HTTP ${response.status}`);

  let payload: unknown;
  try {
    payload = await response.json();
  } catch (error) {
    throw new Error(`${message} response was malformed`, { cause: error });
  }
  if (!isRecord(payload)) throw new Error(`${message} response was malformed`);

  return payload;
}

function stringField(record: Record<string, unknown>, field: string, message: string): string {
  const value = record[field];
  if (typeof value === 'string' && value.length > 0) return value;

  throw new Error(`${message} response was missing ${field}`);
}

function optionalStringField(record: Record<string, unknown>, field: string): string | undefined {
  const value = record[field];

  return typeof value === 'string' && value.length > 0 ? value : undefined;
}

// The server picks the sign-in and poll URLs; refuse any outside Mistral's console.
function checkedUrl(value: string, baseUrl: string, message: string): string {
  const current = new URL(value);
  const base = new URL(baseUrl);
  const isUnderBase =
    current.origin === base.origin && current.pathname.startsWith(base.pathname.replace(/\/$/, ''));
  if (!isUnderBase) throw new Error(`${message} returned an unexpected URL`);

  return value;
}

async function createSignInProcess(codeChallenge: string): Promise<SignInProcess> {
  const message = 'Failed to start Mistral browser sign-in';
  const response = await fetch(`${BROWSER_AUTH_API_BASE_URL}${SIGN_IN_PATH}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ code_challenge: codeChallenge, code_challenge_method: 'S256' }),
  });
  const payload = await responseRecord(response, message);

  const expiresAt = Date.parse(stringField(payload, 'expires_at', message));
  if (!Number.isFinite(expiresAt)) throw new Error(`${message} response had an invalid expires_at`);

  return {
    processId: stringField(payload, 'process_id', message),
    signInUrl: checkedUrl(stringField(payload, 'sign_in_url', message), BROWSER_AUTH_BASE_URL, message),
    pollUrl: checkedUrl(stringField(payload, 'poll_url', message), BROWSER_AUTH_API_BASE_URL, message),
    expiresAt,
  };
}

async function waitForExchangeToken(attempt: SignInProcess, callbacks: OAuthLoginCallbacks): Promise<string> {
  const message = 'Mistral browser sign-in status could not be retrieved';

  while (Date.now() < attempt.expiresAt) {
    if (callbacks.signal?.aborted) throw new Error('Mistral browser sign-in was cancelled');

    const response = await fetch(attempt.pollUrl);
    if (response.status === 410) throw new Error('Mistral browser sign-in expired');

    const payload = await responseRecord(response, message);
    const status = payload.status as PollStatus;
    if (!POLL_STATUSES.includes(status)) throw new Error('Mistral browser sign-in returned an unknown state');

    switch (status) {
      case 'pending': {
        const delay = Math.min(POLL_INTERVAL_MS, Math.max(0, attempt.expiresAt - Date.now()));
        await new Promise((resolve) => setTimeout(resolve, delay));
        break;
      }
      case 'completed': {
        const exchangeToken = optionalStringField(payload, 'exchange_token');
        if (exchangeToken) return exchangeToken;
        throw new Error('Mistral browser sign-in completed without an exchange token');
      }
      case 'expired':
        throw new Error('Mistral browser sign-in expired');
      case 'denied':
        throw new Error('Mistral browser sign-in was denied');
      case 'error':
        throw new Error(optionalStringField(payload, 'message') ?? 'Mistral browser sign-in failed');
    }
  }

  throw new Error('Mistral browser sign-in timed out');
}

async function exchangeForApiKey(processId: string, exchangeToken: string, codeVerifier: string): Promise<string> {
  const message = 'Failed to exchange Mistral browser sign-in for an API key';
  const response = await fetch(`${BROWSER_AUTH_API_BASE_URL}${SIGN_IN_PATH}/${processId}/exchange`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ exchange_token: exchangeToken, code_verifier: codeVerifier }),
  });
  const payload = await responseRecord(response, message);

  return stringField(payload, 'api_key', message);
}

// The sign-in yields a long-lived API key, so "refresh" only pushes the expiry forward.
const mistralOAuth = {
  name: 'Mistral subscription (Mistral AI Studio)',
  isSubscription: true,

  async login(callbacks: OAuthLoginCallbacks): Promise<OAuthCredentials> {
    const codeVerifier = randomBytes(64).toString('base64url');
    const codeChallenge = createHash('sha256').update(codeVerifier, 'ascii').digest('base64url');
    const attempt = await createSignInProcess(codeChallenge);

    callbacks.onAuth({
      url: attempt.signInUrl,
      instructions: 'Sign in with your Mistral Pro or higher account, then return to Pi.',
    });
    callbacks.onProgress?.('Waiting for Mistral browser sign-in...');
    const exchangeToken = await waitForExchangeToken(attempt, callbacks);

    callbacks.onProgress?.('Completing Mistral browser sign-in...');
    const apiKey = await exchangeForApiKey(attempt.processId, exchangeToken, codeVerifier);

    return { access: apiKey, refresh: 'mistral-browser-sign-in', expires: Date.now() + API_KEY_EXPIRES_MS };
  },

  async refreshToken(credentials: OAuthCredentials): Promise<OAuthCredentials> {
    return { ...credentials, expires: Date.now() + API_KEY_EXPIRES_MS };
  },

  getApiKey(credentials: OAuthCredentials): string {
    return credentials.access;
  },
};

// ── Model overlay (applied by Pi only while the sign-in is active) ────────────

// In Pi's catalog, but a subscription key cannot call them: Mistral answers "Invalid model", or 403
// for the Labs model (checked upstream 2026-10-31).
const UNAVAILABLE_MODELS = new Set([
  'devstral-medium-2507',
  'devstral-small-2505',
  'devstral-small-2507',
  'labs-leanstral-1-5-1',
  'mistral-large-2411',
  'mistral-large-4-0-8',
  'mistral-nemo',
  'pixtral-large-latest',
  // Floating alias of `mistral-large-4` (checked 2026-11-18); hidden so only the clear name is offered.
  'mistral-large-latest',
]);

// Maps Pi thinking levels to Mistral's `reasoning_effort`; null levels are rejected by the API.
const LARGE_4_THINKING_LEVEL_MAP = {
  off: null, minimal: null, low: 'low', medium: 'medium', high: 'high', xhigh: null, max: null,
} as const;
const GLM_5_3_THINKING_LEVEL_MAP = {
  off: null, minimal: null, low: 'low', medium: null, high: 'high', xhigh: null, max: 'max',
} as const;
const GLM_5_2_THINKING_LEVEL_MAP = {
  off: 'none', minimal: 'minimal', low: 'low', medium: 'medium', high: 'high', xhigh: 'xhigh', max: 'max',
} as const;
const DEEPSEEK_THINKING_LEVEL_MAP = {
  off: 'none', minimal: null, low: 'low', medium: null, high: 'high', xhigh: 'xhigh', max: 'max',
} as const;

// Stops a runaway turn: Large 4 once spent 32,768 tokens on one empty tool call.
const LARGE_4_MAX_TOKENS = 32_768;

const ZERO_COST = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 };

// Pi's bundled catalog can lack these until its online catalog arrives, which print mode never
// fetches. Pi's own entry wins as soon as it has one.
const FALLBACK_MODELS = [
  {
    id: 'mistral-large-4',
    name: 'Mistral Large 4',
    contextWindow: 1_048_576,
    maxTokens: LARGE_4_MAX_TOKENS,
    input: ['text', 'image'],
    thinkingLevelMap: LARGE_4_THINKING_LEVEL_MAP,
  },
  {
    id: 'zai-glm-5-3',
    name: 'GLM 5.3',
    contextWindow: 1_048_576,
    maxTokens: 128_000,
    input: ['text'],
    thinkingLevelMap: GLM_5_3_THINKING_LEVEL_MAP,
  },
  {
    id: 'zai-glm-5-3-flash',
    name: 'GLM 5.3 Flash',
    contextWindow: 1_048_576,
    maxTokens: 128_000,
    input: ['text', 'image'],
    thinkingLevelMap: GLM_5_3_THINKING_LEVEL_MAP,
  },
] as const;

function adjustedModel(model: Model<Api>): Model<Api> {
  switch (model.id) {
    // Mistral Large 4 ("Le Chonk") rejects reasoning_effort none (checked 2026-11-18).
    case 'mistral-large-4':
      return {
        ...model,
        reasoning: true,
        input: ['text', 'image'],
        contextWindow: Math.max(model.contextWindow, 1_048_576),
        maxTokens: Math.min(model.maxTokens, LARGE_4_MAX_TOKENS),
        thinkingLevelMap: LARGE_4_THINKING_LEVEL_MAP,
      };
    case 'glm-5-2':
    case 'zai-glm-5-2':
      return { ...model, thinkingLevelMap: GLM_5_2_THINKING_LEVEL_MAP };
    case 'deepseek-v4-1-flash-1017':
      return { ...model, input: ['text', 'image'], thinkingLevelMap: DEEPSEEK_THINKING_LEVEL_MAP };
    default:
      return model;
  }
}

export function subscriptionModels(models: Model<Api>[]): Model<Api>[] {
  const available = models.filter((model) => !UNAVAILABLE_MODELS.has(model.id));
  const knownIds = new Set(available.map((model) => model.id));
  const baseUrl = available[0]?.baseUrl ?? MISTRAL_BASE_URL;
  const missing = FALLBACK_MODELS.filter((model) => !knownIds.has(model.id)).map(
    (model) =>
      ({
        ...model,
        input: [...model.input],
        api: 'mistral-conversations',
        provider: MISTRAL_PROVIDER_ID,
        baseUrl,
        reasoning: true,
        cost: { ...ZERO_COST },
      }) as Model<Api>,
  );

  return [...available, ...missing].map(adjustedModel);
}

// ── Extension ─────────────────────────────────────────────────────────────────

function usesMistralSignIn(
  model: ExtensionContext['model'],
  ctx: ExtensionContext,
): model is NonNullable<ExtensionContext['model']> {
  return model?.provider === MISTRAL_PROVIDER_ID && ctx.modelRegistry.isUsingOAuth(model);
}

// Pi can hand a session the model without the overlay: after /reload, and from its selectors while
// a catalog refresh runs. That object would otherwise stay for the whole session.
async function selectAdjustedModel(pi: ExtensionAPI, ctx: ExtensionContext, model: ExtensionContext['model']) {
  if (!usesMistralSignIn(model, ctx)) return;

  const adjusted = ctx.modelRegistry.find(MISTRAL_PROVIDER_ID, model.id);
  if (!adjusted || isDeepStrictEqual(adjusted, model)) return;

  // A model switch re-derives the thinking level from settings, so carry the current one over.
  const level = pi.getThinkingLevel();
  await pi.setModel(adjusted);
  pi.setThinkingLevel(level);
}

export default function piExtraSubs(pi: ExtensionAPI) {
  pi.registerProvider(MISTRAL_PROVIDER_ID, { oauth: { ...mistralOAuth, modifyModels: subscriptionModels } });

  pi.on('session_start', async (event, ctx) => {
    if (event.reason !== 'reload' || !usesMistralSignIn(ctx.model, ctx)) return;

    await ctx.modelRegistry.refresh({ allowNetwork: false });
    await selectAdjustedModel(pi, ctx, ctx.model);
  });

  pi.on('model_select', async (event, ctx) => {
    await selectAdjustedModel(pi, ctx, event.model);
  });
}
