import { AsyncLocalStorage } from 'node:async_hooks';
import type { ExtensionContext } from '@earendil-works/pi-coding-agent';
import type { ApprovalRequest, createApprovalPrompt } from './approval.ts';

type ApprovalPrompt = ReturnType<typeof createApprovalPrompt>;

/** A changed snapshot is cancelled before another tool decision can use its old mode. */
export class AutoModeState {
  private changed = new AbortController();
  private listeners = new Set<() => void>();
  private enabled: boolean;

  constructor(enabled: boolean) {
    this.enabled = enabled;
  }

  snapshot(): { enabled: boolean; signal: AbortSignal } {
    return { enabled: this.enabled, signal: this.changed.signal };
  }

  setEnabled(enabled: boolean): void {
    if (this.enabled === enabled) return;

    this.enabled = enabled;
    const previous = this.changed;
    this.changed = new AbortController();
    previous.abort();
    for (const listener of this.listeners) listener();
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);

    return () => { this.listeners.delete(listener); };
  }
}

interface SafetySession {
  ctx: ExtensionContext;
  prompt: ApprovalPrompt;
  lifetime: AbortSignal;
  mode: AutoModeState;
  parent?: SafetySession;
  dispose: () => void;
}

interface SessionRegistry {
  byId: Map<string, SafetySession>;
  byFile: Map<string, SafetySession>;
  binding: AsyncLocalStorage<{ parent?: SafetySession }>;
}

// SDK workers share the process, but not pi.events or module instances after extension reloads.
// The runner scopes extension binding to its actual parent, even for sessions with no file.
const SAFETY_SESSIONS = Symbol.for('waxcraft:pi-safety:sessions:v2');
const WORKER_BINDING = Symbol.for('waxcraft:pi-safety:bind-worker:v1');
const shared = globalThis as typeof globalThis & {
  [SAFETY_SESSIONS]?: SessionRegistry;
  [WORKER_BINDING]?: typeof withWorkerParent;
};
const registry = shared[SAFETY_SESSIONS] ??= {
  byId: new Map(), byFile: new Map(), binding: new AsyncLocalStorage(),
};

/** Called by the tracked pi-subagents runner patch around bindExtensions/session_start. */
export function withWorkerParent<T>(parent: Pick<ExtensionContext, 'sessionManager'>, bind: () => Promise<T>): Promise<T> {
  const session = registry.byId.get(parent.sessionManager.getSessionId());

  // An explicit but unregistered parent must not fall back to historical saved ancestry.
  return registry.binding.run({ parent: session }, bind);
}
shared[WORKER_BINDING] = withWorkerParent;

function savedParent(ctx: ExtensionContext): SafetySession | undefined {
  const file = ctx.sessionManager.getHeader()?.parentSession;

  return file ? registry.byFile.get(file) : undefined;
}

/** Register from session_start, never from extension discovery. */
export function registerSafetySession(
  ctx: ExtensionContext,
  prompt: ApprovalPrompt,
  localMode: AutoModeState,
  lifetime: AbortSignal,
): { mode: AutoModeState; dispose: () => void } {
  const binding = registry.binding.getStore();
  const parent = binding ? binding.parent : savedParent(ctx);
  const mode = parent && !parent.lifetime.aborted ? parent.mode : localMode;
  if (lifetime.aborted) return { mode, dispose: () => {} };

  const id = ctx.sessionManager.getSessionId();
  const file = ctx.sessionManager.getSessionFile();
  registry.byId.get(id)?.dispose();
  if (file) registry.byFile.get(file)?.dispose();

  const stopped = new AbortController();
  const dispose = () => {
    stopped.abort();
    if (registry.byId.get(id) === session) registry.byId.delete(id);
    if (file && registry.byFile.get(file) === session) registry.byFile.delete(file);
    lifetime.removeEventListener('abort', dispose);
  };
  const session: SafetySession = {
    ctx, prompt, mode, parent, dispose,
    lifetime: AbortSignal.any([lifetime, stopped.signal]),
  };
  registry.byId.set(id, session);
  if (file) registry.byFile.set(file, session);
  lifetime.addEventListener('abort', dispose, { once: true });

  return { mode, dispose };
}

/** Undefined means there is no live ancestor UI. Cancellation and errors must never approve. */
export async function forwardApproval(
  request: ApprovalRequest,
  ctx: ExtensionContext,
  lifetime: AbortSignal,
): Promise<boolean | undefined> {
  const signals = [lifetime, ...(ctx.signal ? [ctx.signal] : [])];
  const visited = new Set<SafetySession>();
  const requester = registry.byId.get(ctx.sessionManager.getSessionId());
  if (requester) signals.push(requester.lifetime);
  let session = requester ? requester.parent : savedParent(ctx);

  while (session && !visited.has(session)) {
    visited.add(session);
    if (session.lifetime.aborted) return undefined;
    signals.push(session.lifetime);
    if (!session.ctx.hasUI) {
      session = session.parent;
      continue;
    }

    const signal = AbortSignal.any(signals);
    if (signal.aborted) return false;

    // Retain live context getters, but bind cancellation to this worker operation rather than
    // the parent's unrelated active turn. Local and worker asks use the same parent UI queue.
    const reviewContext: ExtensionContext = Object.create(session.ctx, { signal: { value: signal } });
    const forwarded = {
      ...request,
      worker: { name: ctx.sessionManager.getSessionName() ?? 'worker', cwd: ctx.cwd },
    };
    try {
      return await session.prompt(forwarded, reviewContext) === true && !signal.aborted;
    } catch {
      return undefined;
    }
  }

  return undefined;
}
