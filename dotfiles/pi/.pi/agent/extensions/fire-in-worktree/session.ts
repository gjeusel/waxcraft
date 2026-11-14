import { closeSync, existsSync, openSync, readdirSync, readFileSync, readSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { getAgentDir, SessionManager, type SessionEntry } from '@earendil-works/pi-coding-agent';

export const ENTRY_TYPE = 'fire-in-worktree';

/** Stored in the forked session: marks it as a fired agent's session. */
export interface FireEntry {
  worktree: string;
  clone: string;
  issue: number;
  branch: string;
}

/** The `fire` tool's result details. */
export interface FireDetails {
  issue: number;
  issueTitle: string;
  issueUrl: string;
  mr: number;
  mrUrl: string;
  repo: string;
  worktree: string;
  branch: string;
  sessionFile: string;
  model: string;
  review: 'standard' | 'thorough' | 'none';
  autoMerge: boolean;
  setupFailure?: string;
}

export function textOf(content: string | readonly { type: string; text?: string }[]): string {
  if (typeof content === 'string') return content;

  return content.flatMap((block) => (block.type === 'text' && block.text ? [block.text] : [])).join('\n');
}

/**
 * The directory pi stores the sessions of a working directory in, as `SessionManager` encodes it:
 * the sessions of a fired agent's worktree.
 */
export function sessionDirOf(cwd: string, agentDir = getAgentDir()): string {
  const encoded = resolve(cwd).replace(/^[/\\]/, '').replace(/[/\\:]/g, '-');

  return join(resolve(agentDir), 'sessions', `--${encoded}--`);
}

/**
 * The fire entry of a session file, when it is a fired agent's session. The last one: an agent fired
 * by a fired agent forks its conversation, hence holds its parent's entry before its own.
 */
export function firedEntry(sessionText: string): FireEntry | undefined {
  let own: FireEntry | undefined;
  for (const line of sessionText.split('\n')) {
    // Cheap filter first: the entry type also appears in the text of conversations about this extension.
    if (!line.includes(`"${ENTRY_TYPE}"`)) continue;

    try {
      const entry = JSON.parse(line) as { type?: string; customType?: string; data?: FireEntry };
      if (entry.type === 'custom' && entry.customType === ENTRY_TYPE && entry.data) own = entry.data;
    } catch {
      // A line being written: not the entry, which is written before the agent starts.
    }
  }

  return own;
}

/** The fire entry of a session's branch: the last one, for the same reason as in `firedEntry`. */
export function firedEntryOfBranch(branch: readonly SessionEntry[]): FireEntry | undefined {
  const entry = branch.filter((candidate) => candidate.type === 'custom' && candidate.customType === ENTRY_TYPE).at(-1);

  return entry?.type === 'custom' ? (entry.data as FireEntry) : undefined;
}

/** Written beside a fired agent's session, so that finding the fired agents reads no session. */
export function fireRecordOf(sessionFile: string): string {
  return `${sessionFile}.fire.json`;
}

function readHeaderLine(file: string): string {
  const fd = openSync(file, 'r');
  try {
    const buffer = Buffer.alloc(64 * 1024);
    const bytes = readSync(fd, buffer, 0, buffer.length, 0);

    return buffer.subarray(0, bytes).toString('utf8').split('\n')[0];
  } finally {
    closeSync(fd);
  }
}

/**
 * The fire entry of a session, from its fire record. A session forked before records existed gets
 * one on first sight: only a session forked from another directory can be a fired agent's, as
 * subagents and `/fork` store theirs beside their parent, and pi started by hand has no parent.
 */
export function readFireRecord(sessionFile: string): FireEntry | undefined {
  const record = fireRecordOf(sessionFile);
  if (existsSync(record)) {
    try {
      return JSON.parse(readFileSync(record, 'utf8')) as FireEntry;
    } catch {
      // A file being written.
      return undefined;
    }
  }

  let parentSession: string | undefined;
  try {
    parentSession = (JSON.parse(readHeaderLine(sessionFile)) as { parentSession?: string }).parentSession;
  } catch {
    return undefined;
  }
  if (!parentSession || dirname(parentSession) === dirname(sessionFile)) return undefined;

  const entry = firedEntry(readFileSync(sessionFile, 'utf8'));
  if (entry) writeFileSync(record, JSON.stringify(entry));

  return entry;
}

/** The fired agents' sessions of a worktree, with their entry. */
export function firedSessionsOf(worktree: string): { sessionFile: string; entry: FireEntry }[] {
  const dir = sessionDirOf(worktree);
  if (!existsSync(dir)) return [];

  return readdirSync(dir)
    .filter((name) => name.endsWith('.jsonl'))
    .flatMap((name) => {
      const sessionFile = join(dir, name);
      const entry = readFireRecord(sessionFile);

      return entry ? [{ sessionFile, entry }] : [];
    });
}

/**
 * The fires of a session's branch that are its own. In a fired agent's session, those after its fire
 * entry: the earlier ones, inherited with the conversation, are its siblings'.
 */
export function ownFires(branch: readonly SessionEntry[]): FireDetails[] {
  const forkedAt = branch.map((entry) => entry.type === 'custom' && entry.customType === ENTRY_TYPE).lastIndexOf(true);

  return branch.slice(forkedAt + 1).flatMap((entry) => {
    if (entry.type !== 'message' || entry.message.role !== 'toolResult' || entry.message.toolName !== 'fire' || entry.message.isError) return [];

    const details = entry.message.details as Partial<FireDetails> | undefined;

    return details?.branch && details.sessionFile ? [details as FireDetails] : [];
  });
}

/**
 * The text of the last assistant message an agent wrote in its session file: where it is at. In a
 * fired agent's session, only what follows its fire entry: the lines before are the conversation it
 * inherited, whose last message is the launching session's.
 */
export function lastAssistantText(sessionText: string): string | undefined {
  const lines = sessionText.split('\n');
  for (let index = lines.length - 1; index >= 0; index -= 1) {
    // Cheap filter first: session files weigh megabytes.
    const line = lines[index];
    if (!line.includes('"role":"assistant"') && !line.includes(`"${ENTRY_TYPE}"`)) continue;

    try {
      const entry = JSON.parse(line) as {
        type?: string;
        customType?: string;
        message?: { role?: string; content?: string | { type: string; text?: string }[] };
      };
      if (entry.type === 'custom' && entry.customType === ENTRY_TYPE) return undefined;

      const text = entry.type === 'message' && entry.message?.role === 'assistant' ? textOf(entry.message.content ?? '').trim() : '';
      if (text) return text;
    } catch {
      // A line being written.
    }
  }

  return undefined;
}

/**
 * The user messages of the run that asked for the fire, in order: the request, then what the user
 * steered into the run. The run starts after the last assistant message that ended a turn, one that
 * stopped for another reason than calling tools.
 */
export function findRequest(branch: readonly SessionEntry[]): SessionEntry[] {
  const request: SessionEntry[] = [];
  for (let index = branch.length - 1; index >= 0; index -= 1) {
    const entry = branch[index];
    if (entry.type !== 'message') continue;

    if (entry.message.role === 'user') request.unshift(entry);
    const endedTurn = entry.message.role === 'assistant' && entry.message.stopReason !== 'toolUse';
    if (endedTurn && request.length > 0) break;
  }

  return request;
}

export function requestText(request: readonly SessionEntry[]): string {
  const texts = request.flatMap((entry) => (entry.type === 'message' && entry.message.role === 'user' ? [textOf(entry.message.content).trim()] : []));

  return texts.join('\n\n') || '(not found)';
}

/**
 * Fork the session file into a session of the worktree, resuming just before the request: the brief
 * restates it, and the launching turn's tool calls, still running, stay out. Storing it beside the
 * launching session would let `pi -c` there pick the agent's session, the most recently written.
 */
export function forkSession(parentFile: string, request: readonly SessionEntry[], entry: FireEntry, name: string): string {
  const fork = SessionManager.forkFrom(parentFile, entry.worktree);
  const first = request.at(0);
  if (first?.parentId === null) fork.resetLeaf();
  else if (first?.parentId) fork.branch(first.parentId);

  fork.appendCustomEntry(ENTRY_TYPE, entry);
  fork.appendSessionInfo(name);

  const sessionFile = fork.getSessionFile();
  if (!sessionFile) throw new Error('the forked session was not saved');

  writeFileSync(fireRecordOf(sessionFile), JSON.stringify(entry));

  return sessionFile;
}

export function isRunning(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch (error: unknown) {
    return (error as NodeJS.ErrnoException).code === 'EPERM';
  }
}

export function lockFileOf(sessionFile: string): string {
  return `${sessionFile}.pid`;
}

/** The pid of the live pi holding a session's lock, if any. */
export function lockOwner(sessionFile: string, isAlive: (pid: number) => boolean = isRunning): number | undefined {
  const lockFile = lockFileOf(sessionFile);
  const owner = existsSync(lockFile) ? Number(readFileSync(lockFile, 'utf8')) : 0;

  return owner > 0 && isAlive(owner) ? owner : undefined;
}

/**
 * Two pi processes on one session would interleave their entries in its file. Returns the pid of
 * another live owner, or takes the lock (replacing a stale one) and returns undefined.
 */
export function lockSession(lockFile: string): number | undefined {
  try {
    writeFileSync(lockFile, String(process.pid), { flag: 'wx' });
    return undefined;
  } catch (error: unknown) {
    if ((error as NodeJS.ErrnoException).code !== 'EEXIST') throw error;
  }

  const owner = Number(readFileSync(lockFile, 'utf8'));
  if (owner && owner !== process.pid && isRunning(owner)) return owner;

  writeFileSync(lockFile, String(process.pid));
  return undefined;
}

/** Where a pi running in Rex says it is: written beside its session, which `/fire switch` reads. */
export interface PaneRecord {
  pid: number;
  session: string;
  block: string;
}

export function paneFileOf(sessionFile: string): string {
  return `${sessionFile}.pane`;
}

/** The pane record of a session, unless the pi that wrote it is gone: its pane may hold something else. */
export function readPaneRecord(sessionFile: string, isAlive: (pid: number) => boolean = isRunning): PaneRecord | undefined {
  const paneFile = paneFileOf(sessionFile);
  if (!existsSync(paneFile)) return undefined;

  try {
    const record = JSON.parse(readFileSync(paneFile, 'utf8')) as Partial<PaneRecord>;
    const isComplete = typeof record.pid === 'number' && typeof record.session === 'string' && typeof record.block === 'string';

    return isComplete && isAlive(record.pid as number) ? (record as PaneRecord) : undefined;
  } catch {
    // A file being written.
    return undefined;
  }
}
