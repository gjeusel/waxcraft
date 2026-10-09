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
  parentSession?: string;
}

// SDK workers share the process, but not pi.events or module instances after extension reloads.
// Native session ancestry scopes the registry: no fallback to an arbitrary available terminal.
const SAFETY_SESSIONS = Symbol.for('waxcraft:pi-safety:sessions:v1');
const shared = globalThis as typeof globalThis & { [SAFETY_SESSIONS]?: Map<string, SafetySession> };
const sessions = shared[SAFETY_SESSIONS] ??= new Map<string, SafetySession>();

/** Register from session_start, never from extension discovery. */
export function registerSafetySession(
  ctx: ExtensionContext,
  prompt: ApprovalPrompt,
  localMode: AutoModeState,
  lifetime: AbortSignal,
): { mode: AutoModeState; dispose: () => void } {
  const parentSession = ctx.sessionManager.getHeader()?.parentSession;
  const parent = parentSession ? sessions.get(parentSession) : undefined;
  const mode = parent && !parent.lifetime.aborted ? parent.mode : localMode;
  const sessionFile = ctx.sessionManager.getSessionFile();
  if (!sessionFile || lifetime.aborted) return { mode, dispose: () => {} };

  const session: SafetySession = { ctx, prompt, lifetime, mode, parentSession };
  sessions.set(sessionFile, session);
  const dispose = () => {
    if (sessions.get(sessionFile) === session) sessions.delete(sessionFile);
    lifetime.removeEventListener('abort', dispose);
  };
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
  const visited = new Set<string>();
  let parent = ctx.sessionManager.getHeader()?.parentSession;

  while (parent && !visited.has(parent)) {
    visited.add(parent);
    const session = sessions.get(parent);
    if (!session || session.lifetime.aborted) return undefined;
    signals.push(session.lifetime);
    if (!session.ctx.hasUI) {
      parent = session.parentSession;
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
