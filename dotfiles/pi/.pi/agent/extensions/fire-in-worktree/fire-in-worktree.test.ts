import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { SessionManager } from '@earendil-works/pi-coding-agent';
import {
  agentLabels,
  describeMr,
  findRequest,
  firedEntry,
  firedEntryOfBranch,
  firedStatus,
  forkSession,
  gitlabProject,
  lastAssistantText,
  layoutFor,
  linkedWorktrees,
  loadConfig,
  mergeStatus,
  originPath,
  ownFires,
  paneFileOf,
  parseFireArgs,
  parseTabLabel,
  piCommand,
  pingReport,
  readPaneRecord,
  renderBrief,
  requestText,
  reviewersFor,
  SWITCH_TO_PARENT,
  switchLabels,
  tabLabel,
  worktreeOfBranch,
} from './index.ts';

type Message = Parameters<SessionManager['appendMessage']>[0];

const user = (text: string) => ({ role: 'user', content: text, timestamp: 0 }) as unknown as Message;
const assistant = (text: string, stopReason = 'toolUse') =>
  ({
    role: 'assistant',
    content: [{ type: 'text', text }],
    api: 'anthropic-messages',
    provider: 'anthropic',
    model: 'claude-opus-5-5',
    usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } },
    stopReason,
    timestamp: 0,
  }) as unknown as Message;

/** Runs with a temporary agent directory, which holds the sessions. */
function withAgentDir(run: (dir: string) => void): void {
  const dir = mkdtempSync(join(tmpdir(), 'fire-in-worktree-'));
  const previous = process.env.PI_CODING_AGENT_DIR;
  process.env.PI_CODING_AGENT_DIR = dir;
  try {
    run(dir);
  } finally {
    if (previous === undefined) delete process.env.PI_CODING_AGENT_DIR;
    else process.env.PI_CODING_AGENT_DIR = previous;
    rmSync(dir, { recursive: true, force: true });
  }
}

/** The parent's session, as the tool sees it: the request and the assistant turn calling the tool. */
function parentSession(messages: Message[]): SessionManager {
  const session = SessionManager.create('/home/me/src/zefire');
  for (const message of messages) session.appendMessage(message);

  return session;
}

function messageTexts(session: SessionManager): string[] {
  return session.getBranch().flatMap((entry) => {
    if (entry.type !== 'message') return [];
    const { content } = entry.message as { content: string | { text?: string }[] };

    return [typeof content === 'string' ? content : content.map((block) => block.text).join('')];
  });
}

test('fire.json gives the reviewers by provider, with a default', () => {
  // The tracked configuration itself.
  const config = loadConfig(fileURLToPath(new URL('../../fire.json', import.meta.url)));

  assert.equal(config.model, 'claude-code/claude-fable-5-2');
  assert.equal(config.workerModel, 'claude-code/claude-opus-5-5');
  assert.deepEqual(reviewersFor(config, 'claude-code'), { standard: 'openai-codex/gpt-6-astra', thorough: 'openai-codex/gpt-6-astra' });
  assert.deepEqual(reviewersFor(config, 'openai-codex'), { standard: 'claude-code/claude-opus-5-5', thorough: 'claude-code/claude-fable-5-2' });
});

test('a malformed fire.json is rejected', () => {
  withAgentDir((dir) => {
    const path = join(dir, 'fire.json');
    writeFileSync(path, JSON.stringify({ reviewers: { default: { standard: 'sol' } } }));

    assert.throws(() => loadConfig(path), /reviewers\.default\.standard must be "provider\/modelId"/);
    writeFileSync(path, JSON.stringify({ workerModel: 'opus', reviewers: {} }));
    assert.throws(() => loadConfig(path), /workerModel must be "provider\/modelId"/);
    assert.throws(() => reviewersFor({ reviewers: {} }, 'anthropic'), /no reviewers for provider anthropic/);
  });
});

test('a user checkout and an agent worktree map to the same agent clone', () => {
  const expected = { clone: '/home/me/.pi/src/zefire', userCheckout: '/home/me/src/zefire' };

  assert.deepEqual(layoutFor('/home/me/src/zefire/.git', '/home/me'), expected);
  // A fired agent firing again: its worktree's common git directory is the clone's.
  assert.deepEqual(layoutFor('/home/me/.pi/src/zefire/.git', '/home/me'), expected);
});

test('finds the worktree of a branch in `git worktree list --porcelain`', () => {
  const porcelain = [
    'worktree /home/me/.pi/src/zefire\nHEAD abc\nbranch refs/heads/master',
    'worktree /home/me/.pi/src/zefire.worktrees/12-fix\nHEAD def\nbranch refs/heads/12-fix',
    'worktree /home/me/.pi/src/zefire.worktrees/scratch\nHEAD 123\ndetached',
  ].join('\n\n');

  assert.equal(worktreeOfBranch(porcelain, '12-fix'), '/home/me/.pi/src/zefire.worktrees/12-fix');
  assert.equal(worktreeOfBranch(porcelain, '12-fi'), undefined);
});

test('a repository is named by its short name or GitLab path in projects.md', () => {
  const projects = [
    '| Short name | GitLab path | Default branch |',
    '| ---------- | ----------- | -------------- |',
    '| venturi    | renewex/scripts/venturi | master |',
  ].join('\n');

  assert.deepEqual(gitlabProject(projects, 'venturi'), { name: 'venturi', path: 'renewex/scripts/venturi' });
  assert.deepEqual(gitlabProject(projects, 'renewex/scripts/venturi'), { name: 'venturi', path: 'renewex/scripts/venturi' });
  // Absent from the table, a GitLab path is taken as is.
  assert.deepEqual(gitlabProject(projects, 'renewex/template/python-rnxcookie'), {
    name: 'python-rnxcookie',
    path: 'renewex/template/python-rnxcookie',
  });
  assert.equal(gitlabProject(projects, 'nope'), undefined);
});

test('lists the linked worktrees of a clone with their branch', () => {
  const porcelain = [
    'worktree /c\nHEAD abc\nbranch refs/heads/master',
    'worktree /c.worktrees/12-fix\nHEAD def\nbranch refs/heads/12-fix',
    'worktree /c.worktrees/scratch\nHEAD 123\ndetached',
  ].join('\n\n');

  assert.deepEqual(linkedWorktrees(porcelain, '/c'), [
    { path: '/c.worktrees/12-fix', branch: '12-fix' },
    { path: '/c.worktrees/scratch', branch: undefined },
  ]);
});

test('brief.md uses only the values the tool provides, and values are not expanded again', () => {
  const template = readFileSync(new URL('brief.md', import.meta.url), 'utf8');
  const keys = ['request', 'task', 'worktree', 'clone', 'userCheckout', 'issue', 'issueIid', 'mr', 'branch', 'glabTask', 'setup', 'workersStep', 'reviewStep', 'mergeStep'];
  const values = Object.fromEntries(keys.map((key) => [key, `<${key} {{task}}>`]));

  const brief = renderBrief(template, values);
  assert.match(brief, /<request \{\{task\}\}>/);
  assert.doesNotMatch(brief.replaceAll('{{task}}', ''), /\{\{/);
  assert.throws(() => renderBrief('{{missing}}', values), /unknown placeholder \{\{missing\}\}/);
});

test('the fork is a session of the worktree and resumes before the request', () => {
  withAgentDir((dir) => {
    const parent = parentSession([user('discuss the plan'), assistant('plan ready', 'stop'), user('fire in wt'), assistant('calling the tool')]);
    const request = findRequest(parent.getBranch());
    assert.equal(requestText(request), 'fire in wt');

    const entry = { worktree: '/home/me/.pi/src/zefire.worktrees/12-fix', clone: '/home/me/.pi/src/zefire', issue: 12, branch: '12-fix' };
    const sessionFile = forkSession(parent.getSessionFile()!, request, entry, '12-fix');

    assert.equal(dirname(sessionFile), join(dir, 'sessions', '--home-me-.pi-src-zefire.worktrees-12-fix--'));
    const fork = SessionManager.open(sessionFile);
    assert.equal(fork.getCwd(), entry.worktree);
    assert.equal(fork.getHeader()?.parentSession, parent.getSessionFile());
    assert.equal(fork.getSessionName(), '12-fix');
    assert.deepEqual(messageTexts(fork), ['discuss the plan', 'plan ready']);
    assert.deepEqual(
      fork.getBranch().flatMap((candidate) => (candidate.type === 'custom' ? [candidate.data] : [])),
      [entry],
    );
  });
});

test('a fork requested by the first message starts empty', () => {
  withAgentDir(() => {
    const parent = parentSession([user('fire in wt: fix it'), assistant('calling the tool')]);
    const entry = { worktree: '/w', clone: '/c', issue: 12, branch: '12-fix' };
    const sessionFile = forkSession(parent.getSessionFile()!, findRequest(parent.getBranch()), entry, '12-fix');

    assert.deepEqual(messageTexts(SessionManager.open(sessionFile)), []);
  });
});

test('an agent fired by a fired agent is known by its own entry, not the inherited one', () => {
  withAgentDir(() => {
    const parent = parentSession([user('fire in wt: fix it'), assistant('calling the tool')]);
    const parentEntry = { worktree: '/w/12-fix', clone: '/c', issue: 12, branch: '12-fix' };
    const firedFile = forkSession(parent.getSessionFile()!, findRequest(parent.getBranch()), parentEntry, '12-fix');

    // The fired agent works, then fires in turn: the fork of its conversation holds both entries.
    const fired = SessionManager.open(firedFile);
    for (const message of [user('fix it'), assistant('fixed', 'stop'), user('fire in wt: the follow-up'), assistant('calling the tool')]) {
      fired.appendMessage(message);
    }
    const ownEntry = { worktree: '/w/13-follow-up', clone: '/c', issue: 13, branch: '13-follow-up' };
    const sessionFile = forkSession(firedFile, findRequest(fired.getBranch()), ownEntry, '13-follow-up');

    const fork = SessionManager.open(sessionFile);
    assert.deepEqual(
      fork.getBranch().flatMap((candidate) => (candidate.type === 'custom' ? [candidate.data] : [])),
      [parentEntry, ownEntry],
    );
    assert.deepEqual(firedEntryOfBranch(fork.getBranch()), ownEntry);
    assert.deepEqual(firedEntry(readFileSync(sessionFile, 'utf8')), ownEntry);
    assert.equal(firedEntryOfBranch(parent.getBranch()), undefined);
  });
});

const fireResult = (branch: string, isError = false) =>
  ({
    role: 'toolResult',
    toolCallId: branch,
    toolName: 'fire',
    content: [{ type: 'text', text: 'Fired' }],
    details: isError ? undefined : { branch, sessionFile: `/sessions/${branch}.jsonl` },
    isError,
    timestamp: 0,
  }) as unknown as Message;

test("a session's own fires leave out those inherited from the session that fired it", () => {
  withAgentDir(() => {
    const parent = parentSession([user('fire two agents'), assistant('firing'), fireResult('1-sibling'), user('fire in wt: fix it'), assistant('calling the tool')]);
    assert.deepEqual(
      ownFires(parent.getBranch()).map((fire) => fire.branch),
      ['1-sibling'],
    );

    const entry = { worktree: '/w/2-fix', clone: '/c', issue: 2, branch: '2-fix' };
    const fired = SessionManager.open(forkSession(parent.getSessionFile()!, findRequest(parent.getBranch()), entry, '2-fix'));
    assert.deepEqual(ownFires(fired.getBranch()), []);

    for (const message of [user('fire the follow-ups'), assistant('firing'), fireResult('3-failed', true), fireResult('4-follow-up')]) fired.appendMessage(message);
    assert.deepEqual(
      ownFires(fired.getBranch()).map((fire) => fire.branch),
      ['4-follow-up'],
    );
  });
});

test('the last message of an agent is its last assistant text', () => {
  withAgentDir(() => {
    const session = parentSession([user('fix it'), assistant('The MR is ready.\n\nChecks pass.', 'stop'), user('thanks')]);
    // A turn that only calls tools says nothing.
    session.appendMessage({ ...assistant(''), content: [{ type: 'toolCall', id: '1', name: 'bash', arguments: {} }] } as unknown as Message);

    assert.equal(lastAssistantText(readFileSync(session.getSessionFile()!, 'utf8')), 'The MR is ready.\n\nChecks pass.');
    assert.equal(lastAssistantText('{"type":"message","message":{"role":"user","content":"hi"}}\n{"role":"assistant"'), undefined);

    // A fired agent inherits the conversation: what was said before its fire entry is not its own.
    session.appendMessage(user('fire in wt'));
    session.appendMessage(assistant('calling the tool'));
    const entry = { worktree: '/w/12-fix', clone: '/c', issue: 12, branch: '12-fix' };
    const firedFile = forkSession(session.getSessionFile()!, findRequest(session.getBranch()), entry, '12-fix');
    assert.equal(lastAssistantText(readFileSync(firedFile, 'utf8')), undefined);

    SessionManager.open(firedFile).appendMessage(assistant('Reading the router.'));
    assert.equal(lastAssistantText(readFileSync(firedFile, 'utf8')), 'Reading the router.');
  });
});

test('the ping report tells the state, the MR and the last message of each agent', () => {
  assert.equal(describeMr({ state: 'merged', draft: false }), 'merged');
  assert.equal(describeMr({ state: 'opened', draft: true, head_pipeline: null }), 'draft, pipeline none');
  assert.equal(describeMr({ state: 'opened', draft: false, has_conflicts: true, head_pipeline: { status: 'failed' } }), 'ready, pipeline failed, conflicts');

  const now = new Date('2026-01-02T12:00:00Z');
  const report = pingReport(
    [
      {
        state: 'done',
        issue: 12,
        issueTitle: 'Fix the filter',
        mr: 34,
        mrUrl: 'https://gitlab.com/g/p/-/merge_requests/34',
        mrStatus: 'ready, pipeline success',
        active: new Date('2026-01-02T09:00:00Z'),
        lastMessage: 'The MR is ready.\nChecks pass.\n\n## Details\n\nThey follow.',
      },
      { state: 'working', issue: 13, issueTitle: 'Clean up', mr: 35, mrUrl: 'https://gitlab.com/g/p/-/merge_requests/35', active: new Date('2026-01-02T11:58:00Z'), lastMessage: 'x'.repeat(500) },
      { state: 'stopped', issue: 14, issueTitle: 'Pruned', mr: 36, mrUrl: 'https://gitlab.com/g/p/-/merge_requests/36', mrStatus: 'merged' },
    ],
    now,
  );

  assert.deepEqual(report.split('\n'), [
    'Fired agents of this session: 1 working, 1 done, 1 stopped.',
    '',
    '- ✓ done · #12 Fix the filter · [!34](https://gitlab.com/g/p/-/merge_requests/34) ready, pipeline success · 3 h ago',
    '  > The MR is ready. Checks pass.',
    '- ● working · #13 Clean up · [!35](https://gitlab.com/g/p/-/merge_requests/35) · 2 min ago',
    `  > ${'x'.repeat(400)}…`,
    '- ○ stopped · #14 Pruned · [!36](https://gitlab.com/g/p/-/merge_requests/36) merged',
  ]);
});

test('the brief is the last argument, after the end of options', () => {
  const command = piCommand('/s.jsonl', 'anthropic/claude-opus-5-5', 'high', '--looks like an option');

  assert.deepEqual(command.slice(-8), ['--session', '/s.jsonl', '--model', 'anthropic/claude-opus-5-5', '--thinking', 'high', '--', '--looks like an option']);
  assert.match(command[2], /exec nice -n 10 pi "\$@"$/);
});

test('the request includes what the user steered into the run', () => {
  withAgentDir(() => {
    const parent = parentSession([
      user('discuss the plan'),
      assistant('plan ready', 'stop'),
      user('fire in wt: fix it'),
      assistant('reading the labels'),
      user('and merge it'),
      assistant('calling the tool'),
    ]);
    const request = findRequest(parent.getBranch());
    assert.equal(requestText(request), 'fire in wt: fix it\n\nand merge it');

    const entry = { worktree: '/w', clone: '/c', issue: 12, branch: '12-fix' };
    const sessionFile = forkSession(parent.getSessionFile()!, request, entry, '12-fix');
    assert.deepEqual(messageTexts(SessionManager.open(sessionFile)), ['discuss the plan', 'plan ready']);
    assert.deepEqual(firedEntry(readFileSync(sessionFile, 'utf8')), entry);
    // A session only talking about the extension is not a fired agent's.
    assert.equal(firedEntry(readFileSync(parent.getSessionFile()!, 'utf8')), undefined);
    assert.equal(firedEntry('{"type":"message","text":"the \\"fire-in-worktree\\" entry"}\n{"type":"cus'), undefined);
  });
});

test('/fire takes any text but its subcommands as a task', () => {
  assert.deepEqual(parseFireArgs(''), { kind: 'list' });
  assert.deepEqual(parseFireArgs(' list '), { kind: 'list' });
  assert.deepEqual(parseFireArgs('prune'), { kind: 'prune' });
  assert.deepEqual(parseFireArgs('ping'), { kind: 'ping' });
  assert.deepEqual(parseFireArgs('switch'), { kind: 'switch' });
  assert.deepEqual(parseFireArgs('self-close'), { kind: 'self-close' });
  assert.deepEqual(parseFireArgs('merge'), { kind: 'merge' });
  assert.deepEqual(parseFireArgs('run'), { kind: 'run', task: '' });
  // A task starting with a subcommand's word keeps it.
  assert.deepEqual(parseFireArgs('run the migration on staging'), { kind: 'run', task: 'run the migration on staging' });
  assert.deepEqual(parseFireArgs('prune the dead code'), { kind: 'run', task: 'prune the dead code' });
  assert.deepEqual(parseFireArgs('#123, thorough review'), { kind: 'run', task: '#123, thorough review' });
});

test('the switch picker lists the fired agents, after the parent when there is one', () => {
  const fire = (issue: number, issueTitle: string) => ({ issue, issueTitle, mr: issue + 100, branch: `${issue}-x` }) as unknown as Parameters<typeof switchLabels>[0][number];
  const fires = [fire(12, 'Fix the filter'), fire(13, 'Clean up')];
  const states = new Map([['12-x', 'done' as const]]);

  assert.deepEqual(switchLabels(fires, states, false), ['✓ #12 Fix the filter · !112', '#13 Clean up · !113']);
  assert.deepEqual(switchLabels(fires, states, true), [SWITCH_TO_PARENT, '✓ #12 Fix the filter · !112', '#13 Clean up · !113']);
  assert.deepEqual(switchLabels([], states, true), [SWITCH_TO_PARENT]);
});

test('a pane record is trusted only while the pi that wrote it runs', () => {
  const dir = mkdtempSync(join(tmpdir(), 'fire-pane-'));
  try {
    const sessionFile = join(dir, 'session.jsonl');
    assert.equal(readPaneRecord(sessionFile), undefined);

    const record = { pid: 4242, session: 'session:1', block: 'block:2' };
    writeFileSync(paneFileOf(sessionFile), JSON.stringify(record));
    assert.deepEqual(
      readPaneRecord(sessionFile, (pid) => pid === 4242),
      record,
    );
    assert.equal(
      readPaneRecord(sessionFile, () => false),
      undefined,
    );

    writeFileSync(paneFileOf(sessionFile), '{"pid":4242');
    assert.equal(
      readPaneRecord(sessionFile, () => true),
      undefined,
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("a tab's label carries its agent's state", () => {
  assert.equal(tabLabel('12-fix', 'working'), '12-fix');
  for (const state of ['working', 'done', 'failed'] as const) {
    assert.deepEqual(parseTabLabel(tabLabel('12-fix', state)), { branch: '12-fix', state });
  }
});

test('the picker gives each agent a distinct label', () => {
  const modified = new Date(2026, 0, 2, 3, 4);
  const row = { state: 'stopped', repo: 'zefire', branch: '12-fix', modified } as const;
  const labels = agentLabels([{ ...row, state: 'working', mr: 'opened' }, row, row]);

  assert.equal(labels[0], `● working  ·  zefire  ·  12-fix  ·  MR opened  ·  ${modified.toLocaleString()}`);
  assert.equal(labels[1], `○ stopped  ·  zefire  ·  12-fix  ·  ${modified.toLocaleString()}`);
  assert.equal(labels[2], `${labels[1]} (2)`);
});

test('an origin is compared by its project path, whatever the URL form', () => {
  for (const url of ['git@gitlab.com:renewex/zefire.git', 'https://gitlab.com/renewex/zefire', 'ssh://git@gitlab.com/renewex/zefire.git\n']) {
    assert.equal(originPath(url), 'renewex/zefire');
  }
});

test('the footer counts fired agents by state icon, without the stopped ones', () => {
  assert.equal(firedStatus(['working', 'done', 'running', 'working', 'done', 'stopped']), 'fire ●2 ◐1 ✓2');
  assert.equal(firedStatus(['done', 'failed']), 'fire ✓1 ⚠1');
  assert.equal(firedStatus(['stopped']), undefined);
  assert.equal(firedStatus([]), undefined);
});

test('the footer tells the step of /fire merge, with the MR and the minutes once known', () => {
  assert.equal(mergeStatus(undefined, 'checking the MR', 2_000), 'merge checking the MR');
  assert.equal(mergeStatus(12, 'enabling auto-merge, GitLab checking (approvals_syncing)', 59_000), 'merge !12 enabling auto-merge, GitLab checking (approvals_syncing)');
  assert.equal(mergeStatus(12, 'auto-merge on, pipeline running', 4.5 * 60_000), 'merge !12 auto-merge on, pipeline running · 4m');
});
