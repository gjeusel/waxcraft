// `/hloop`: address the review notes left in a live Hunk session.
//
// The session and its open notes are resolved here, before the model runs, so that the turn starts
// on the first note instead of spending tool calls on finding them.
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';

const EXEC_TIMEOUT_MS = 5000;

export interface HunkSession {
  sessionId: string;
  repoRoot: string;
  title?: string;
  terminal?: { locations?: { tty?: string }[] };
  files?: { path: string }[];
}

export interface HunkNote {
  noteId: string;
  /** The note this one replies to. */
  parentId?: string;
  source: string;
  filePath: string;
  oldRange?: [number, number];
  newRange?: [number, number];
  body: string;
  createdAt: string;
}

/** A top-level note with its replies, oldest first. */
export interface NoteThread {
  root: HunkNote;
  notes: HunkNote[];
}

function parseJson(text: string): any {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

/**
 * The sessions `/hloop` may mean, most likely first: the one sharing this terminal window, else
 * those reviewing this repository, else all of them. `isObvious` when no question is needed.
 */
export function chooseSessions(
  sessions: readonly HunkSession[],
  repoRoot: string | null,
  windowTtys: ReadonlySet<string>,
): { candidates: HunkSession[]; isObvious: boolean } {
  const isInWindow = (session: HunkSession) =>
    (session.terminal?.locations ?? []).some((location) => windowTtys.has(location.tty ?? ''));

  const inWindow = sessions.filter(isInWindow);
  if (inWindow.length === 1) return { candidates: inWindow, isObvious: true };

  const pool = inWindow.length > 0 ? inWindow : sessions;
  const inRepo = pool.filter((session) => session.repoRoot === repoRoot);
  if (inRepo.length > 0) return { candidates: inRepo, isObvious: inRepo.length === 1 };

  // A lone session of another repository, in another window, may not be the one meant.
  return { candidates: [...pool], isObvious: false };
}

/**
 * The threads still waiting on the agent, in review order: those whose latest note is the user's.
 * `filePaths` is the order of the files in the review.
 */
export function findOpenThreads(
  notes: readonly HunkNote[],
  filePaths: readonly string[],
): NoteThread[] {
  const noteById = new Map(notes.map((note) => [note.noteId, note]));
  const threadByRootId = new Map<string, NoteThread>();

  for (const note of notes) {
    let root = note;
    // Bounded, so that a malformed parent cycle cannot loop forever.
    for (let depth = 0; depth < notes.length; depth += 1) {
      const parent = noteById.get(root.parentId ?? '');
      if (!parent) break;
      root = parent;
    }

    const thread = threadByRootId.get(root.noteId) ?? { root, notes: [] };
    thread.notes.push(note);
    threadByRootId.set(root.noteId, thread);
  }

  const openThreads = [...threadByRootId.values()].filter((thread) => {
    thread.notes.sort((a, b) => a.createdAt.localeCompare(b.createdAt));

    return thread.notes.at(-1)?.source === 'user';
  });

  const fileIndex = (thread: NoteThread) => {
    const index = filePaths.indexOf(thread.root.filePath);

    return index < 0 ? filePaths.length : index;
  };
  const line = (thread: NoteThread) => thread.root.newRange?.[0] ?? thread.root.oldRange?.[0] ?? 0;

  return openThreads.sort((a, b) => fileIndex(a) - fileIndex(b) || line(a) - line(b));
}

export function buildPrompt(
  session: HunkSession,
  threads: readonly NoteThread[],
  extra: string,
): string {
  const id = session.sessionId;
  const notes = threads.map((thread, index) => {
    const { root } = thread;
    const [side, range] = root.newRange ? ['new', root.newRange] : ['old', root.oldRange ?? [0, 0]];
    const lines = range[0] === range[1] ? `line ${range[0]}` : `lines ${range[0]}-${range[1]}`;
    const messages = thread.notes.map((note) => {
      const body = note.body.trim().replaceAll('\n', '\n     ');

      return `   - ${note.source === 'user' ? 'me' : 'you'}: ${body}`;
    });

    const heading = `${index + 1}. \`${root.filePath}\`, ${side} ${lines}, reply to \`${root.noteId}\``;

    return [heading, ...messages].join('\n');
  });

  return `Address the review notes I left in the live Hunk session \`${id}\`, which reviews \`${session.repoRoot}\`.
The open notes are listed below, already filtered and in review order: do not list sessions or notes
again, and never launch \`hunk diff\` or \`hunk show\` yourself.

For each note, in order:
- Read the surrounding code before acting. Implement a requested change, answer a question, or
  reject a request you disagree with instead of editing.
- Reply with one command, which also moves my view to the note:
  \`hunk session comment add ${id} --reply-to <note id> --focus --summary "..."\`
  The summary is one terse sentence of at most 10 words, without \`--rationale\`, usually just
  \`done\` or \`rejected: <reason>\`.
- Anything needing more words stays out of Hunk: explain longer answers or reasoning in this
  conversation, and ask clarifying questions or confirm a rejection with \`ask_user_question\`,
  batching the questions from every note into one call rather than one per note.

Never remove or clear my notes: I decide when a thread is resolved. Make one pass over these notes,
then stop; I rerun \`/hloop\` after adding more. Run the checks proportional to the changes you
made, then summarize the notes as done, answered, or rejected, with the files you changed.

## Open notes

${notes.join('\n')}

${extra || 'Address every open note.'}`;
}

export default function (pi: ExtensionAPI) {
  const exec = (command: string, args: string[], cwd?: string) =>
    pi.exec(command, args, { timeout: EXEC_TIMEOUT_MS, cwd });

  /** The terminal devices of the other panes of this Rex window; empty outside Rex. */
  async function listWindowTtys(): Promise<Set<string>> {
    const ownBlock = process.env.REX_BLOCK;
    if (!ownBlock) return new Set();

    const inspected = await exec('rex', ['block', 'inspect', ownBlock, '--json']);
    const windowId = parseJson(inspected.stdout)?.block?.window_id;
    if (typeof windowId !== 'string') return new Set();

    const listed = await exec('rex', ['block', 'ls', '--window', windowId, '--json']);
    const blockIds: string[] = (parseJson(listed.stdout)?.blocks ?? [])
      .map((block: { block_id?: string }) => block.block_id)
      .filter((blockId: unknown) => typeof blockId === 'string' && blockId !== ownBlock);

    // Rex names a pane's foreground process, Hunk the terminal device of its session: the device of
    // that process is what joins the two.
    const processes = await Promise.all(
      blockIds.map((blockId) => exec('rex', ['block', 'call', 'process', '--block', blockId])),
    );
    const pids = processes
      .map((result) => parseJson(result.stdout)?.foreground?.pid)
      .filter((pid) => Number.isInteger(pid));
    if (pids.length === 0) return new Set();

    const devices = await exec('ps', ['-o', 'tty=', '-p', pids.join(',')]);

    const ttys = devices.stdout.split('\n').map((tty) => tty.trim());

    return new Set(ttys.filter(Boolean).map((tty) => `/dev/${tty}`));
  }

  pi.registerCommand('hloop', {
    description: 'Address my review notes in the live Hunk session, one reply per note',
    handler: async (args, ctx) => {
      const [listed, toplevel, windowTtys] = await Promise.all([
        exec('hunk', ['session', 'list', '--json']),
        exec('git', ['rev-parse', '--show-toplevel'], ctx.cwd),
        listWindowTtys().catch(() => new Set<string>()),
      ]);

      const sessions: HunkSession[] = parseJson(listed.stdout)?.sessions ?? [];
      if (sessions.length === 0) {
        ctx.ui.notify('No live Hunk session: open Hunk on the changes to review first.', 'warning');
        return;
      }

      const repoRoot = toplevel.code === 0 ? toplevel.stdout.trim() : null;
      const { candidates, isObvious } = chooseSessions(sessions, repoRoot, windowTtys);
      let session = isObvious ? candidates[0] : undefined;
      if (!session) {
        const labels = candidates.map(
          (candidate) => `${candidate.title ?? candidate.repoRoot} · ${candidate.repoRoot}`,
        );
        const choice = await ctx.ui.select('Hunk session to address', labels);
        session = candidates[labels.indexOf(choice ?? '')];
      }
      if (!session) return;

      const noteArgs = ['session', 'comment', 'list', session.sessionId, '--type', 'all', '--json'];
      const noted = await exec('hunk', noteArgs);
      const notes: HunkNote[] | undefined = parseJson(noted.stdout)?.comments;
      if (!notes) {
        const reason = noted.stderr.trim() || 'unexpected output';
        ctx.ui.notify(`Could not read the Hunk notes: ${reason}`, 'error');
        return;
      }

      const filePaths = (session.files ?? []).map((file) => file.path);
      const threads = findOpenThreads(notes, filePaths);
      if (threads.length === 0) {
        const name = session.title ?? session.repoRoot;
        ctx.ui.notify(`No open note in the Hunk session "${name}".`, 'info');
        return;
      }

      const prompt = buildPrompt(session, threads, args.trim());
      if (ctx.isIdle()) pi.sendUserMessage(prompt);
      else pi.sendUserMessage(prompt, { deliverAs: 'followUp' });
    },
  });
}
