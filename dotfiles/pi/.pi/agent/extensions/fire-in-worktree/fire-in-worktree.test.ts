import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { SessionManager } from '@earendil-works/pi-coding-agent';
import {
  agentLabels,
  findRequest,
  firedEntry,
  forkSession,
  gitlabProject,
  layoutFor,
  linkedWorktrees,
  loadConfig,
  originPath,
  parseFireArgs,
  parseTabLabel,
  piCommand,
  renderBrief,
  requestText,
  reviewersFor,
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

  assert.deepEqual(reviewersFor(config, 'claude-code'), { standard: 'openai-codex/gpt-6.1-sol', thorough: 'openai-codex/gpt-6-astra' });
  assert.deepEqual(reviewersFor(config, 'openai-codex'), { standard: 'claude-code/claude-opus-5-5', thorough: 'claude-code/claude-fable-5-2' });
});

test('a malformed fire.json is rejected', () => {
  withAgentDir((dir) => {
    const path = join(dir, 'fire.json');
    writeFileSync(path, JSON.stringify({ reviewers: { default: { standard: 'sol' } } }));

    assert.throws(() => loadConfig(path), /reviewers\.default\.standard must be "provider\/modelId"/);
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
  const keys = ['request', 'task', 'worktree', 'clone', 'userCheckout', 'issue', 'issueIid', 'mr', 'branch', 'glabTask', 'setup', 'reviewStep', 'mergeStep'];
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
  assert.deepEqual(parseFireArgs('run'), { kind: 'run', task: '' });
  // A task starting with a subcommand's word keeps it.
  assert.deepEqual(parseFireArgs('run the migration on staging'), { kind: 'run', task: 'run the migration on staging' });
  assert.deepEqual(parseFireArgs('prune the dead code'), { kind: 'run', task: 'prune the dead code' });
  assert.deepEqual(parseFireArgs('#123, thorough review'), { kind: 'run', task: '#123, thorough review' });
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
