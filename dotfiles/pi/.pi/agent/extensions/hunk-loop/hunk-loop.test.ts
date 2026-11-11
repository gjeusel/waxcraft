import assert from 'node:assert/strict';
import test from 'node:test';
import { buildPrompt, chooseSessions, findOpenThreads, type HunkNote, type HunkSession } from './index.ts';

function session(sessionId: string, repoRoot: string, tty: string): HunkSession {
  return { sessionId, repoRoot, title: sessionId, terminal: { locations: [{ tty }] } };
}

function note(noteId: string, source: string, createdAt: string, fields: Partial<HunkNote> = {}): HunkNote {
  return { noteId, source, createdAt, filePath: 'a.py', newRange: [1, 1], body: noteId, ...fields };
}

test('chooseSessions prefers the session of this window, then of this repository', () => {
  const here = session('here', '/repo', '/dev/ttys001');
  const sibling = session('sibling', '/other', '/dev/ttys002');
  const elsewhere = session('elsewhere', '/repo', '/dev/ttys003');
  const ids = (sessions: HunkSession[], repoRoot: string | null, ttys: string[]) => {
    const { candidates, isObvious } = chooseSessions(sessions, repoRoot, new Set(ttys));

    return [candidates.map((candidate) => candidate.sessionId), isObvious];
  };

  // The window wins over the repository.
  assert.deepEqual(ids([here, sibling, elsewhere], '/repo', ['/dev/ttys002']), [['sibling'], true]);
  // Two sessions in the window: the repository decides between them.
  assert.deepEqual(ids([here, sibling], '/repo', ['/dev/ttys001', '/dev/ttys002']), [['here'], true]);
  // None in the window: the repository decides, or leaves a choice.
  assert.deepEqual(ids([sibling, elsewhere], '/repo', []), [['elsewhere'], true]);
  assert.deepEqual(ids([here, sibling, elsewhere], '/repo', []), [['here', 'elsewhere'], false]);
  // A lone session of another repository is offered, never assumed.
  assert.deepEqual(ids([sibling], '/repo', []), [['sibling'], false]);
  assert.deepEqual(ids([sibling], null, []), [['sibling'], false]);
});

test('findOpenThreads keeps the threads whose latest note is the user\'s', () => {
  const notes = [
    note('unanswered', 'user', '2026-01-01T10:00:00Z'),
    note('answered', 'user', '2026-01-01T10:01:00Z'),
    note('answer', 'agent', '2026-01-01T10:02:00Z', { parentId: 'answered' }),
    note('reopened', 'user', '2026-01-01T10:03:00Z'),
    note('first-answer', 'agent', '2026-01-01T10:04:00Z', { parentId: 'reopened' }),
    // A reply to the agent's reply still belongs to the thread of its root.
    note('pushback', 'user', '2026-01-01T10:05:00Z', { parentId: 'first-answer' }),
    note('agent-only', 'agent', '2026-01-01T10:06:00Z'),
  ];

  const threads = findOpenThreads(notes, ['a.py']);

  assert.deepEqual(
    threads.map((thread) => [thread.root.noteId, thread.notes.map((threadNote) => threadNote.noteId)]),
    [
      ['unanswered', ['unanswered']],
      ['reopened', ['reopened', 'first-answer', 'pushback']],
    ],
  );
});

test('findOpenThreads orders threads by review file order, then line', () => {
  const notes = [
    note('b-late', 'user', '2026-01-01T10:00:00Z', { filePath: 'b.py', newRange: [90, 92] }),
    note('unknown-file', 'user', '2026-01-01T10:01:00Z', { filePath: 'gone.py' }),
    note('a-old-side', 'user', '2026-01-01T10:02:00Z', { newRange: undefined, oldRange: [40, 40] }),
    note('b-early', 'user', '2026-01-01T10:03:00Z', { filePath: 'b.py', newRange: [3, 3] }),
    note('a-early', 'user', '2026-01-01T10:04:00Z', { newRange: [7, 7] }),
  ];

  const order = findOpenThreads(notes, ['b.py', 'a.py']).map((thread) => thread.root.noteId);

  assert.deepEqual(order, ['b-early', 'b-late', 'a-early', 'a-old-side', 'unknown-file']);
});

test('buildPrompt lists each thread with where it is and what to reply to', () => {
  const notes = [
    note('user:1', 'user', '2026-01-01T10:00:00Z', { body: 'rename this\nto something clearer' }),
    note('mcp:1', 'agent', '2026-01-01T10:01:00Z', { parentId: 'user:1', body: 'done' }),
    note('user:2', 'user', '2026-01-01T10:02:00Z', { parentId: 'user:1', body: 'no, use display_name' }),
    note('user:3', 'user', '2026-01-01T10:03:00Z', { newRange: undefined, oldRange: [40, 44], body: 'why?' }),
  ];
  const threads = findOpenThreads(notes, ['a.py']);

  const prompt = buildPrompt(session('abc-123', '/repo', '/dev/ttys001'), threads, '');

  assert.ok(prompt.includes('live Hunk session `abc-123`, which reviews `/repo`'));
  assert.ok(prompt.includes('hunk session comment add abc-123 --reply-to <note id> --focus --summary'));
  assert.ok(
    prompt.includes(`## Open notes

1. \`a.py\`, new line 1, reply to \`user:1\`
   - me: rename this
     to something clearer
   - you: done
   - me: no, use display_name
2. \`a.py\`, old lines 40-44, reply to \`user:3\`
   - me: why?

Address every open note.`),
  );
  assert.ok(buildPrompt(session('s', '/repo', ''), threads, 'only a.py').endsWith('\n\nonly a.py'));
});
