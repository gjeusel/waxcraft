/**
 * fire-in-worktree — "fire in wt": hands a task to a new pi that continues this conversation in an
 * isolated git worktree, in a tab of the Rex session `ai-agents`, and carries it through
 * implementation, cross-provider review, and MR on its own (see brief.md).
 *
 * Worktrees belong to agent-only clones in ~/.pi/src/<repo>, so checkouts under ~/src never gain
 * linked worktrees. The glab skill's `glab_task.py open` first resolves or creates the issue (content
 * written by the launching model), its canonical branch, and a draft MR, in seconds; the worktree is
 * named after that branch. Worktrunk (`wt`) creates it and runs the user's pre-start hooks (env files,
 * uv venv; see dotfiles/worktrunk). The new session is a fork of the launching one, stored as a
 * session of the worktree. Reviewer models come from ~/.pi/agent/fire.json, read at each fire.
 *
 * `/fire <task>` is a shortcut for "fire in wt: <task>", and `/fire run` fires what the conversation
 * settled. `/fire` (or `/fire list`) lists the fired agents of every repository, then jumps to the Rex
 * tab of a running one or opens the session of a stopped one. `/fire prune` closes and removes those
 * whose MR is merged or closed.
 *
 * A fired agent marks its Rex tab when it settles (✓ done, ⚠ failed), and a session that fired agents
 * shows their count in its footer.
 */
import { spawn } from 'node:child_process';
import { existsSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { homedir, tmpdir } from 'node:os';
import { basename, dirname, join, resolve, sep } from 'node:path';
import { setTimeout as sleep } from 'node:timers/promises';
import { fileURLToPath } from 'node:url';
import {
  getAgentDir,
  SessionManager,
  type ExtensionAPI,
  type ExtensionCommandContext,
  type ExtensionContext,
  type SessionEntry,
  type SessionInfo,
} from '@earendil-works/pi-coding-agent';
import { Text } from '@earendil-works/pi-tui';
import { Type } from 'typebox';

const REX_SESSION = 'ai-agents';
const STATUS_KEY = 'fire';
const WATCH_INTERVAL_MS = 15_000;
const ENTRY_TYPE = 'fire-in-worktree';
const BRIEF_TEMPLATE_PATH = fileURLToPath(new URL('brief.md', import.meta.url));
const LONG_TIMEOUT_MS = 15 * 60_000;
// The launched pi takes the session lock on start: until then, its launch is not confirmed.
const START_TIMEOUT_MS = 45_000;
const MODEL_REF = /^[^/]+\/./;

export type Review = 'standard' | 'thorough' | 'none';

export interface Reviewers {
  standard: string;
  thorough: string;
}

/**
 * fire.json: the agent's default model (the launching session's when absent), the default model of
 * the subagents it delegates implementation to (no delegation when absent), and the reviewer models
 * by the agent's provider, `default` for the others, so that the review runs on another provider
 * than the agent.
 */
export interface FireConfig {
  model?: string;
  workerModel?: string;
  reviewers: Record<string, Reviewers>;
}

/** Stored in the forked session: marks it as a fired agent's session. */
export interface FireEntry {
  worktree: string;
  clone: string;
  issue: number;
  branch: string;
}

/** What `glab_task.py open` prints. */
interface OpenedTask {
  issue: { iid: number; title: string; web_url: string; created: boolean };
  branch: { name: string; created: boolean; base: string };
  mr: { iid: number; web_url: string; draft: boolean; created: boolean };
}

/** What a fired agent's Rex tab says of it: the tab's label is its branch, marked once it settles. */
export type TabState = 'working' | 'done' | 'failed';

const TAB_MARKS: Record<TabState, string> = { working: '', done: '✓ ', failed: '⚠ ' };

interface Tab {
  windowId: string;
  branch: string;
  state: TabState;
}

export type FireCommand = { kind: 'list' } | { kind: 'prune' } | { kind: 'run'; task: string };

/** A row of the `/fire` picker. `stopped`: no pi runs the session; `running`: one does, outside Rex. */
export interface AgentRow {
  state: TabState | 'running' | 'stopped';
  repo: string;
  branch: string;
  mr?: string;
  modified: Date;
}

interface FiredAgent extends AgentRow {
  session: SessionInfo;
  pid?: number;
  tab?: Tab;
}

export interface RepoLayout {
  /** Agent-only clone owning the worktrees. */
  clone: string;
  /** The user's own checkout of the repository: clone reference, never touched by agents. */
  userCheckout: string;
}

interface RunOptions {
  cwd?: string;
  timeoutMs?: number;
  signal?: AbortSignal;
}

interface RunResult {
  code: number;
  stdout: string;
  stderr: string;
  /** Set when a signal ended the command, as its timeout does. */
  killed?: string;
}

const fireSchema = Type.Object(
  {
    repo: Type.Optional(
      Type.String({
        description:
          'Repository to fire into, when it is not the current one: a short name or GitLab path from the glab skill\'s references/projects.md (e.g. "venturi"), or a checkout path.',
      }),
    ),
    issue: Type.Optional(Type.Integer({ description: 'IID of the existing GitLab issue of the task, when one is named.' })),
    newIssue: Type.Optional(
      Type.Object(
        {
          title: Type.String({ description: 'Concise imperative title, without trailing period.' }),
          description: Type.String({
            description:
              'Markdown: "## Context" (why it matters now, the observed pain), "## Requirements" (observable behavior, bullets), and "## Acceptance criteria" only when testable conditions are clear. No restated title, no mention of AI.',
          }),
          labels: Type.Array(Type.String(), {
            description:
              "Exact names of existing labels, emoji included, from the glab skill's references/team-and-labels.md: one `type::*`, at most one per scope, plus difficulty, priority, surface, or the project's `feat::*` labels when clear.",
          }),
        },
        { additionalProperties: false },
      ),
    ),
    task: Type.String({
      description:
        'Self-contained brief for the new agent: the goal, what this conversation already settled (decisions, scope, rejected options), constraints, and the validation expected. The agent inherits this conversation, so point to it rather than copying long content.',
    }),
    model: Type.Optional(
      Type.String({
        description: 'Model of the fired agent, as "provider/modelId", only when the user names one; default from fire.json (Fable).',
      }),
    ),
    workerModel: Type.Optional(
      Type.String({
        description:
          'Model of the subagents the fired agent delegates implementation to, as "provider/modelId", or "none" for no delegation; only when the user says so. Default from fire.json (Opus).',
      }),
    ),
    reviewer: Type.Optional(
      Type.String({
        description: 'Reviewer model, as "provider/modelId", only when the user names one; default from fire.json by the agent\'s provider and `review`.',
      }),
    ),
    review: Type.Optional(
      Type.Union([Type.Literal('standard'), Type.Literal('thorough'), Type.Literal('none')], {
        description:
          'Review by the other provider before publishing. "thorough" (its larger model) or "none" only when the user asks for it; default "standard".',
      }),
    ),
    autoMerge: Type.Optional(
      Type.Boolean({
        description: 'true only when the user explicitly asks for the MR to be merged or auto-merged; otherwise the MR is left ready for review.',
      }),
    ),
  },
  { additionalProperties: false },
);

/** Throws on a missing file, invalid JSON, or a malformed value. */
export function loadConfig(path: string): FireConfig {
  const parsed = JSON.parse(readFileSync(path, 'utf8')) as Record<string, unknown> | null;
  for (const key of ['model', 'workerModel'] as const) {
    const model = parsed?.[key];
    if (model !== undefined && (typeof model !== 'string' || !MODEL_REF.test(model))) {
      throw new Error(`${path}: ${key} must be "provider/modelId"`);
    }
  }

  const reviewers = parsed?.reviewers;
  if (typeof reviewers !== 'object' || reviewers === null || Array.isArray(reviewers)) {
    throw new Error(`${path}: expected {"reviewers": {"<provider>" | "default": {"standard", "thorough"}}}`);
  }

  for (const [provider, models] of Object.entries(reviewers)) {
    for (const review of ['standard', 'thorough'] as const) {
      const model = (models as Record<string, unknown> | null)?.[review];
      if (typeof model !== 'string' || !MODEL_REF.test(model)) {
        throw new Error(`${path}: reviewers.${provider}.${review} must be "provider/modelId"`);
      }
    }
  }

  return {
    model: parsed?.model as string | undefined,
    workerModel: parsed?.workerModel as string | undefined,
    reviewers: reviewers as Record<string, Reviewers>,
  };
}

export function reviewersFor(config: FireConfig, provider: string): Reviewers {
  const reviewers = config.reviewers[provider] ?? config.reviewers.default;
  if (!reviewers) throw new Error(`fire.json has no reviewers for provider ${provider}, nor a default`);

  return reviewers;
}

/**
 * From a checkout under ~/src, the clone is ~/.pi/src/<name>. From an agent clone or one of its
 * worktrees (a fired agent firing again), it is that clone. Linked worktrees resolve to their main
 * checkout through the common git directory.
 */
export function layoutFor(commonGitDir: string, home = homedir()): RepoLayout {
  const mainCheckout = dirname(commonGitDir);
  const clonesDir = join(home, '.pi', 'src');
  const name = basename(mainCheckout);

  if (mainCheckout.startsWith(clonesDir + sep)) return { clone: mainCheckout, userCheckout: join(home, 'src', name) };

  return { clone: join(clonesDir, name), userCheckout: mainCheckout };
}

/**
 * The GitLab path of a repository named by its short name or path in projects.md, whose table rows
 * read `| short name | gitlab path | ... |`. A path absent from the table is taken as is.
 */
export function gitlabProject(projectsMarkdown: string, repo: string): { name: string; path: string } | undefined {
  for (const line of projectsMarkdown.split('\n')) {
    const [name, path] = line.split('|').slice(1, 3).map((cell) => cell.trim());
    if (name && path && (repo === name || repo === path)) return { name, path };
  }
  if (/^[\w.-]+(\/[\w.-]+)+$/.test(repo)) return { name: basename(repo), path: repo };

  return undefined;
}

/** The project path of an origin URL, whatever its form: `git@host:group/repo.git` or `https://host/group/repo`. */
export function originPath(url: string): string {
  return url
    .trim()
    .replace(/\.git$/, '')
    .replace(/^[a-z+]+:\/\/[^/]+\//, '')
    .replace(/^[^/@]+@[^:]+:/, '');
}

export function tabLabel(branch: string, state: TabState): string {
  return TAB_MARKS[state] + branch;
}

export function parseTabLabel(label: string): { branch: string; state: TabState } {
  for (const state of ['done', 'failed'] as const) {
    if (label.startsWith(TAB_MARKS[state])) return { branch: label.slice(TAB_MARKS[state].length), state };
  }

  return { branch: label, state: 'working' };
}

/**
 * `list` and `prune` are subcommands, and a bare `run` fires what the conversation settled. Any other
 * text is a task, one starting with "run" included.
 */
export function parseFireArgs(args: string): FireCommand {
  const text = args.trim();
  if (text === '' || text === 'list') return { kind: 'list' };
  if (text === 'prune') return { kind: 'prune' };

  return { kind: 'run', task: text === 'run' ? '' : text };
}

/** The fire entry of a session file, when it is a fired agent's session. */
export function firedEntry(sessionText: string): FireEntry | undefined {
  for (const line of sessionText.split('\n')) {
    // Cheap filter first: the entry type also appears in the text of conversations about this extension.
    if (!line.includes(`"${ENTRY_TYPE}"`)) continue;

    try {
      const entry = JSON.parse(line) as { type?: string; customType?: string; data?: FireEntry };
      if (entry.type === 'custom' && entry.customType === ENTRY_TYPE && entry.data) return entry.data;
    } catch {
      // A line being written: not the entry, which is written before the agent starts.
    }
  }

  return undefined;
}

/** One distinct label per row: the picker returns the chosen label, not its index. */
export function agentLabels(rows: readonly AgentRow[]): string[] {
  const icons: Record<AgentRow['state'], string> = { working: '●', running: '●', done: '✓', failed: '⚠', stopped: '○' };
  const seen = new Map<string, number>();

  return rows.map((row) => {
    const parts = [`${icons[row.state]} ${row.state}`, row.repo, row.branch, row.mr && `MR ${row.mr}`, row.modified.toLocaleString()];
    const label = parts.filter(Boolean).join('  ·  ');
    const count = (seen.get(label) ?? 0) + 1;
    seen.set(label, count);

    return count === 1 ? label : `${label} (${count})`;
  });
}

export function worktreeOfBranch(porcelain: string, branch: string): string | undefined {
  for (const block of porcelain.split('\n\n')) {
    const lines = block.split('\n');
    if (lines.includes(`branch refs/heads/${branch}`)) {
      return lines.find((line) => line.startsWith('worktree '))?.slice('worktree '.length);
    }
  }

  return undefined;
}

/** Linked worktrees of a clone, with their branch (absent when detached). */
export function linkedWorktrees(porcelain: string, clone: string): { path: string; branch?: string }[] {
  return porcelain
    .split('\n\n')
    .map((block) => block.split('\n'))
    .map((lines) => ({
      path: lines.find((line) => line.startsWith('worktree '))?.slice('worktree '.length) ?? '',
      branch: lines.find((line) => line.startsWith('branch refs/heads/'))?.slice('branch refs/heads/'.length),
    }))
    .filter((worktree) => worktree.path && worktree.path !== clone);
}

export function renderBrief(template: string, values: Record<string, string>): string {
  // One pass over the template: placeholders inside the values themselves are left as written.
  return template.replace(/\{\{(\w+)\}\}/g, (placeholder, key: string) => {
    if (!Object.hasOwn(values, key)) throw new Error(`brief.md: unknown placeholder ${placeholder}`);

    return values[key];
  });
}

function textOf(content: string | readonly { type: string; text?: string }[]): string {
  if (typeof content === 'string') return content;

  return content.flatMap((block) => (block.type === 'text' && block.text ? [block.text] : [])).join('\n');
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

  return sessionFile;
}

/**
 * The launched pi runs through an interactive shell, as terminals opened by Rex lack the exports of
 * ~/.zshrc (API keys, MCP connection strings), and at a lower priority, so that agents running
 * tests leave the machine responsive.
 */
export function piCommand(sessionFile: string, model: string, thinking: string, brief: string): string[] {
  const script = 'exec nice -n 10 pi "$@"';

  return [process.env.SHELL || '/bin/zsh', '-ic', script, 'pi', '--session', sessionFile, '--model', model, '--thinking', thinking, '--', brief];
}

/**
 * Run a command with stdin closed: wt and git would otherwise wait on prompts nobody answers. The
 * parent's VIRTUAL_ENV is dropped so that uv sets up the worktree's own venv.
 */
function run(command: string, args: string[], options: RunOptions = {}): Promise<RunResult> {
  const env = { ...process.env };
  delete env.VIRTUAL_ENV;
  const timeoutMs = options.timeoutMs ?? 60_000;

  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: options.cwd,
      env,
      stdio: ['ignore', 'pipe', 'pipe'],
      timeout: timeoutMs,
      signal: options.signal,
    });
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (data: Buffer) => (stdout += data.toString()));
    child.stderr.on('data', (data: Buffer) => (stderr += data.toString()));
    child.on('error', reject);
    child.on('close', (code, signal) => {
      const killed = signal ? `${signal}, its timeout being ${timeoutMs / 1000}s` : undefined;
      resolve({ code: code ?? (signal ? 1 : 0), stdout, stderr, killed });
    });
  });
}

function failure(command: string, args: string[], result: RunResult): Error {
  const output = (result.stderr.trim() || result.stdout.trim()).slice(-2000);
  const reason = result.killed ? `killed by ${result.killed}` : `exit ${result.code}`;

  return new Error(`\`${command} ${args.join(' ')}\` failed (${reason}):\n${output}`);
}

async function runOrThrow(command: string, args: string[], options: RunOptions = {}): Promise<string> {
  const result = await run(command, args, options);
  if (result.code !== 0) throw failure(command, args, result);

  return result.stdout.trim();
}

function glabSkillDir(pi: ExtensionAPI): string {
  const glabSkill = pi.getCommands().find((command) => command.source === 'skill' && command.name === 'skill:glab');
  if (!glabSkill) throw new Error('fire works with the glab skill, which is not loaded');

  return dirname(glabSkill.sourceInfo.path);
}

/** The clone layout and origin of the current repository, or of the one `repo` names. */
async function resolveRepo(repo: string | undefined, cwd: string, skillDir: string): Promise<RepoLayout & { originUrl: string }> {
  const candidates = repo ? [resolve(cwd, repo.replace(/^~(?=\/|$)/, homedir())), join(homedir(), 'src', repo)] : [cwd];
  const checkout = candidates.find((candidate) => existsSync(join(candidate, '.git')));
  if (checkout) {
    const commonGitDir = await runOrThrow('git', ['-C', checkout, 'rev-parse', '--path-format=absolute', '--git-common-dir']);
    const originUrl = await runOrThrow('git', ['-C', checkout, 'remote', 'get-url', 'origin']);

    return { ...layoutFor(commonGitDir), originUrl };
  }

  const project = repo ? gitlabProject(readFileSync(join(skillDir, 'references', 'projects.md'), 'utf8'), repo) : undefined;
  if (!project) throw new Error(`unknown repository "${repo}": neither a checkout nor a project of the glab skill's references/projects.md`);

  return {
    clone: join(homedir(), '.pi', 'src', project.name),
    userCheckout: join(homedir(), 'src', project.name),
    originUrl: `git@gitlab.com:${project.path}.git`,
  };
}

async function ensureClone(layout: RepoLayout, originUrl: string, signal: AbortSignal | undefined): Promise<void> {
  if (existsSync(layout.clone)) {
    // Clones are named after the repository alone: two projects of the same name would share one.
    const cloneOrigin = await runOrThrow('git', ['-C', layout.clone, 'remote', 'get-url', 'origin']);
    if (originPath(cloneOrigin) !== originPath(originUrl)) {
      throw new Error(`${layout.clone} is a clone of ${cloneOrigin}, not of ${originUrl}: move it away to fire into this repository`);
    }

    return;
  }

  // Objects come from the user's checkout, then --dissociate copies them: the clone stays valid
  // whatever later happens to that checkout.
  const reference = existsSync(join(layout.userCheckout, '.git')) ? ['--reference', layout.userCheckout, '--dissociate'] : [];
  await runOrThrow('git', ['clone', '--quiet', ...reference, originUrl, layout.clone], { timeoutMs: LONG_TIMEOUT_MS, signal });
}

/**
 * A worktree on the issue's branch, which exists on origin once `glab_task.py open` ran. A failing
 * pre-start hook leaves the worktree in place: the agent gets the failure to fix rather than the
 * launch being lost.
 */
async function createWorktree(
  clone: string,
  branch: string,
  signal: AbortSignal | undefined,
): Promise<{ worktree: string; setupFailure?: string }> {
  const listWorktrees = () => runOrThrow('git', ['-C', clone, 'worktree', 'list', '--porcelain']);

  const existing = worktreeOfBranch(await listWorktrees(), branch);
  if (existing) {
    throw new Error(`${branch} already has a worktree, ${existing}: jump to its agent with /fire, or remove it with \`wt -C ${clone} remove ${branch}\``);
  }

  const args = ['-C', clone, 'switch', branch, '--no-cd', '--yes'];
  const result = await run('wt', args, { timeoutMs: LONG_TIMEOUT_MS, signal });
  const worktree = worktreeOfBranch(await listWorktrees(), branch);
  if (!worktree) throw failure('wt', args, result);

  return { worktree, setupFailure: result.code === 0 ? undefined : failure('wt', args, result).message };
}

async function rexSessionExists(): Promise<boolean> {
  const { sessions } = JSON.parse(await runOrThrow('rex', ['ls', '--json'])) as { sessions: { label: string }[] };

  return sessions.some((session) => session.label === REX_SESSION);
}

/** The tabs of the Rex session of fired agents; none when that session does not exist. */
async function listTabs(): Promise<{ sessionId?: string; tabs: Tab[] }> {
  const listing = await run('rex', ['window', 'ls', '-s', REX_SESSION, '--json']);
  if (listing.code !== 0) return { tabs: [] };

  const { session_id, windows = [] } = JSON.parse(listing.stdout) as { session_id: string; windows?: { window_id: string; label: string }[] };

  return { sessionId: session_id, tabs: windows.map((window) => ({ windowId: window.window_id, ...parseTabLabel(window.label) })) };
}

/**
 * A tab and pane named after the branch: Go to Anything finds the agent by either. Returns the tab's
 * window and its pane.
 */
async function openRexTab(label: string, cwd: string, command: string[], sessionExists: boolean): Promise<{ window: string; block: string }> {
  const options = ['-c', cwd, '--keep-open', '--json', '--', ...command];

  // `rex new` leaves the app's view alone; `window new` needs --focus=false for that.
  let created: { window_id: string; block_ids: string[] };
  if (sessionExists) {
    created = JSON.parse(await runOrThrow('rex', ['window', 'new', '-s', REX_SESSION, label, '--focus=false', ...options]));
  } else {
    created = JSON.parse(await runOrThrow('rex', ['new', REX_SESSION, '--window', label, ...options])).initial_windows[0];
  }
  const tab = { window: created.window_id, block: created.block_ids[0] };
  await runOrThrow('rex', ['block', 'rename', '-s', REX_SESSION, tab.block, label]);

  return tab;
}

/**
 * Make a tab the active one of the Rex session, then show that session in the app, which the app
 * accepts only with its Remote Control setting on. Returns whether the app shows it.
 */
async function jumpToTab(sessionId: string, windowId: string): Promise<boolean> {
  await runOrThrow('rex', ['focus', '-s', REX_SESSION, windowId]);

  const listing = await run('rex', ['client', 'ls', '--json']);
  if (listing.code !== 0) return false;

  const { clients = [] } = JSON.parse(listing.stdout) as { clients?: { client_id: string; info?: { kind?: string } }[] };
  const app = clients.find((client) => client.info?.kind === 'app');
  if (!app) return false;

  const shown = await run('rex', ['-C', app.client_id, 'do', 'session.select', `session_id=${sessionId}`, `window_id=${windowId}`]);

  return shown.code === 0;
}

/** Wait for the launched pi to take the session lock; on timeout, fail with what its pane shows. */
async function confirmStart(sessionFile: string, block: string, signal: AbortSignal | undefined): Promise<void> {
  const deadline = Date.now() + START_TIMEOUT_MS;
  while (Date.now() < deadline) {
    if (existsSync(`${sessionFile}.pid`)) return;
    await sleep(500, undefined, { signal });
  }

  const screen = await run('rex', ['capture', '-s', REX_SESSION, '-b', block, '--trim']);
  const tail = screen.stdout.trim().split('\n').slice(-30).join('\n');
  throw new Error(`the agent did not start within ${START_TIMEOUT_MS / 1000}s; its pane shows:\n${tail}`);
}

function isRunning(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch (error: unknown) {
    return (error as NodeJS.ErrnoException).code === 'EPERM';
  }
}

/** The agent-only clones: every repository an agent was fired into. */
function agentClones(): string[] {
  const clonesDir = join(homedir(), '.pi', 'src');
  if (!existsSync(clonesDir)) return [];

  return readdirSync(clonesDir)
    .map((name) => join(clonesDir, name))
    .filter((clone) => existsSync(join(clone, '.git')));
}

/** The state of the latest MR of each branch in the clone's project: opened, merged, closed, or none. */
async function mrStates(clone: string, branches: string[]): Promise<Map<string, string>> {
  const project = JSON.parse(await runOrThrow('glab', ['api', 'projects/:fullpath', '--output', 'json'], { cwd: clone })) as { id: number };
  const states = await Promise.all(
    branches.map(async (branch) => {
      const path = `projects/:fullpath/merge_requests?source_branch=${encodeURIComponent(branch)}&order_by=updated_at&sort=desc`;
      const mrs = JSON.parse(await runOrThrow('glab', ['api', path, '--output', 'json'], { cwd: clone })) as {
        state: string;
        source_project_id: number;
      }[];

      return [branch, mrs.find((mr) => mr.source_project_id === project.id)?.state ?? 'none'] as const;
    }),
  );

  return new Map(states);
}

/**
 * The fired agents of every clone, most recently active first: the sessions of their worktrees that
 * hold a fire entry, which leaves out those of subagents and of a pi started there by hand.
 */
async function listFiredAgents(clones: string[]): Promise<{ agents: FiredAgent[]; sessionId?: string }> {
  const { sessionId, tabs } = await listTabs();

  const perClone = await Promise.all(
    clones.map(async (clone) => {
      const worktrees = linkedWorktrees(await runOrThrow('git', ['-C', clone, 'worktree', 'list', '--porcelain']), clone);
      const sessions = (await Promise.all(worktrees.map((worktree) => SessionManager.list(worktree.path)))).flat();
      const fired = sessions.flatMap((session) => {
        const entry = firedEntry(readFileSync(session.path, 'utf8'));

        return entry ? [{ session, entry }] : [];
      });
      // The picker still opens without GitLab: the MR state is then left out.
      const states = await mrStates(clone, [...new Set(fired.map(({ entry }) => entry.branch))]).catch(() => new Map<string, string>());

      return fired.map(({ session, entry }): FiredAgent => {
        const lockFile = `${session.path}.pid`;
        const owner = existsSync(lockFile) ? Number(readFileSync(lockFile, 'utf8')) : 0;
        const pid = owner && isRunning(owner) ? owner : undefined;
        const tab = pid ? tabs.find((candidate) => candidate.branch === entry.branch) : undefined;
        const state = !pid ? 'stopped' : (tab?.state ?? 'running');

        return { session, pid, tab, state, repo: basename(clone), branch: entry.branch, mr: states.get(entry.branch), modified: session.modified };
      });
    }),
  );

  return { agents: perClone.flat().sort((a, b) => b.modified.getTime() - a.modified.getTime()), sessionId };
}

/** Close the tab and remove the worktree of every fired agent whose MR is merged or closed. */
async function pruneFired(clones: string[], ctx: ExtensionCommandContext): Promise<void> {
  ctx.ui.notify(`Checking the MRs of the fired worktrees of ${clones.map((clone) => basename(clone)).join(', ')}…`, 'info');
  const perClone = await Promise.all(
    clones.map(async (clone) => {
      const worktrees = linkedWorktrees(await runOrThrow('git', ['-C', clone, 'worktree', 'list', '--porcelain']), clone);
      const branches = worktrees.flatMap((worktree) => (worktree.branch ? [worktree.branch] : []));
      const states = await mrStates(clone, branches);

      return branches.map((branch) => ({ clone, branch, state: states.get(branch) }));
    }),
  );
  const done = perClone.flat().filter((worktree) => worktree.state === 'merged' || worktree.state === 'closed');
  if (done.length === 0) {
    ctx.ui.notify('Nothing to prune: no fired worktree has a merged or closed MR', 'info');
    return;
  }

  const list = done.map((worktree) => `${basename(worktree.clone)} · ${worktree.branch} (${worktree.state})`).join('\n');
  if (!(await ctx.ui.confirm(`Prune ${done.length} fired agent(s)?`, `Closes their Rex tab and removes their worktree:\n${list}`))) return;

  ctx.ui.notify(`Removing ${done.length} worktree(s)…`, 'info');
  const { tabs } = await listTabs();
  const failures: string[] = [];
  for (const worktree of done) {
    const windows = tabs.filter((tab) => tab.branch === worktree.branch).map((tab) => tab.windowId);
    if (windows.length > 0) await run('rex', ['window', 'close', '-s', REX_SESSION, ...windows]);

    // wt deletes a merged branch and keeps an unmerged one, and refuses a worktree with changes.
    const removal = await run('wt', ['-C', worktree.clone, 'remove', worktree.branch, '--yes', '--foreground'], { timeoutMs: LONG_TIMEOUT_MS });
    if (removal.code !== 0) failures.push(`${worktree.branch}: ${(removal.stderr.trim() || removal.stdout.trim()).split('\n').at(-1)}`);
  }

  const pruned = done.length - failures.length;
  ctx.ui.notify(
    [`Pruned ${pruned} fired agent(s)`, ...failures.map((line) => `kept ${line}`)].join('\n'),
    failures.length > 0 ? 'warning' : 'info',
  );
}

/**
 * Two pi processes on one session would interleave their entries in its file. Returns the pid of
 * another live owner, or takes the lock (replacing a stale one) and returns undefined.
 */
function lockSession(lockFile: string): number | undefined {
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

/** The Rex tab holding this process's pane, when it is a tab of the fired agents' session. */
async function ownTab(): Promise<string | undefined> {
  const block = process.env.REX_BLOCK;
  if (!block) return undefined;

  const listing = await run('rex', ['window', 'ls', '-s', REX_SESSION, '--json']);
  if (listing.code !== 0) return undefined;

  const { windows = [] } = JSON.parse(listing.stdout) as {
    windows?: { window_id: string; layers: { blocks: { block_id: string }[] }[] }[];
  };

  return windows.find((window) => window.layers.some((layer) => layer.blocks.some((candidate) => candidate.block_id === block)))?.window_id;
}

/** A fired agent, as the session that fired it follows it. */
interface Watched {
  branch: string;
  sessionFile: string;
  /** Absent until first looked at: an agent found settled then is not announced. */
  state?: FiredAgent['state'];
}

/** The `fire` tool's result details. */
interface FireDetails {
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
  review: Review;
  autoMerge: boolean;
  setupFailure?: string;
}

export default function (pi: ExtensionAPI) {
  // Set in a fired agent's session that this process owns.
  let lockFile: string | undefined;
  // In a fired agent's session: its branch, and the Rex tab it runs in, once looked up.
  let firedBranch: string | undefined;
  let ownWindow: string | undefined;
  // The agents fired from this session, and the timer following them while one runs.
  const watched = new Map<string, Watched>();
  let watchTimer: NodeJS.Timeout | undefined;

  const stopWatching = () => {
    clearInterval(watchTimer);
    watchTimer = undefined;
  };

  /** Refresh the footer's count of fired agents, and tell when one of them settles. */
  const watch = async (ctx: ExtensionContext) => {
    const { tabs } = await listTabs();
    for (const agent of watched.values()) {
      const lock = `${agent.sessionFile}.pid`;
      const owner = existsSync(lock) ? Number(readFileSync(lock, 'utf8')) : 0;
      const alive = owner > 0 && isRunning(owner);
      const state = alive ? (tabs.find((tab) => tab.branch === agent.branch)?.state ?? 'running') : 'stopped';

      const settled = state === 'done' || state === 'failed';
      if (settled && agent.state && state !== agent.state) {
        const outcome = state === 'done' ? 'is done' : 'stopped on a failure';
        ctx.ui.notify(`Fired agent ${agent.branch} ${outcome}: /fire jumps to it`, state === 'done' ? 'info' : 'warning');
      }
      agent.state = state;
    }

    const counts = (['working', 'running', 'done', 'failed'] as const)
      .map((state) => ({ state, count: [...watched.values()].filter((agent) => agent.state === state).length }))
      .filter(({ count }) => count > 0)
      .map(({ state, count }) => `${count} ${state}`);
    ctx.ui.setStatus(STATUS_KEY, counts.length > 0 ? `fired: ${counts.join(', ')}` : undefined);

    if (counts.length === 0) stopWatching();
  };

  const startWatching = (ctx: ExtensionContext) => {
    if (watchTimer || watched.size === 0 || !ctx.hasUI) return;

    // A failing poll (Rex restarting) is retried at the next tick.
    const tick = () => void watch(ctx).catch(() => undefined);
    watchTimer = setInterval(tick, WATCH_INTERVAL_MS);
    watchTimer.unref();
    tick();
  };

  pi.registerTool({
    name: 'fire',
    label: 'fire',
    description:
      'Hand a task off to a new pi agent ("fire in wt"): it continues this conversation in an isolated git worktree of an agent-only clone (~/.pi/src/<repo>) and a tab of the Rex session "ai-agents", then runs implementation, cross-provider review, and MR on its own.',
    promptSnippet: 'Hand a task off to an autonomous agent in its own worktree ("fire in wt").',
    promptGuidelines: [
      'fire: Call it when the user says "fire in wt" or "fire in worktree", or otherwise asks to hand a task off to a worktree agent; one call per task. Never create the clone, worktree, or Rex tab yourself for this.',
      'fire: Pass `issue` when the user names one. Otherwise write `newIssue` yourself from this conversation, without a subagent; read the glab skill\'s references/team-and-labels.md first unless you already know its labels. The tool creates the issue, its branch, and a draft MR, assigned to the user, in seconds; an invalid label fails fast with the existing ones.',
      'fire: The agent inherits this conversation up to the user\'s request. Write `task` as a self-contained brief of the goal and what was settled. Set `review` and `autoMerge` only from what the user says.',
      'fire: By default the agent runs on Fable, delegates implementation to Opus subagents, and has its work reviewed by GPT Astra (fire.json). Set `model`, `workerModel` (or "none"), or `reviewer` only when the user asks for other models; their request overrides these defaults.',
      'fire: Once it returns, confirm in a sentence or two where the task went, and do not work on that task in this session.',
    ],
    parameters: fireSchema,
    // Calls share the clone and the Rex session, which the first call may be creating.
    executionMode: 'sequential',

    async execute(_toolCallId, params, signal, onUpdate, ctx) {
      const parentFile = ctx.sessionManager.getSessionFile();
      if (!parentFile) throw new Error('fire forks the session, and this one is not saved (--no-session)');
      if ((params.issue === undefined) === (params.newIssue === undefined)) throw new Error('pass exactly one of `issue` and `newIssue`');

      // Read at each fire, so that an edit applies without /reload. The models the user names override
      // its defaults; all are checked before anything is created.
      const config = loadConfig(join(getAgentDir(), 'fire.json'));
      const checkModel = (ref: string, role: string) => {
        const slash = ref.indexOf('/');
        if (slash < 1 || !ctx.modelRegistry.find(ref.slice(0, slash), ref.slice(slash + 1))) throw new Error(`unknown ${role} model ${ref}`);

        return ref;
      };

      const currentModel = ctx.model && `${ctx.model.provider}/${ctx.model.id}`;
      const modelRef = params.model ?? config.model ?? currentModel;
      if (!modelRef) throw new Error('fire needs a model for the new agent: none in fire.json, nor a current one');
      const model = checkModel(modelRef, 'agent');

      const workerRef = params.workerModel ?? config.workerModel;
      const workerModel = workerRef && workerRef !== 'none' ? checkModel(workerRef, 'worker') : undefined;

      const review = params.review ?? 'standard';
      const reviewerRef = review === 'none' ? undefined : (params.reviewer ?? reviewersFor(config, model.split('/')[0])[review]);
      const reviewer = reviewerRef && checkModel(reviewerRef, 'reviewer');

      const skillDir = glabSkillDir(pi);
      const glabTask = join(skillDir, 'scripts', 'glab_task.py');
      const progress = (text: string) => onUpdate?.({ content: [{ type: 'text', text }], details: undefined });

      // Checked before anything is created on GitLab.
      const [sessionExists] = await Promise.all([rexSessionExists(), runOrThrow('wt', ['--version'])]);
      const layout = await resolveRepo(params.repo, ctx.cwd, skillDir);

      if (!existsSync(layout.clone)) progress(`Cloning ${layout.originUrl} into ${layout.clone} (first fire in this repository)…`);
      await ensureClone(layout, layout.originUrl, signal);

      progress(params.newIssue ? 'Creating the issue, its branch, and a draft MR…' : `Opening the branch and MR of issue #${params.issue}…`);
      const issueDir = mkdtempSync(join(tmpdir(), 'fire-'));
      const issueFile = join(issueDir, 'issue.json');
      let opened: OpenedTask;
      try {
        if (params.newIssue) writeFileSync(issueFile, JSON.stringify(params.newIssue));
        const source = params.newIssue ? ['--new-issue', issueFile] : ['--issue', String(params.issue)];
        const output = await runOrThrow('python3', [glabTask, 'open', ...source], { cwd: layout.clone, timeoutMs: 5 * 60_000, signal });
        opened = JSON.parse(output) as OpenedTask;
      } catch (error: unknown) {
        const reason = error instanceof Error ? error.message : String(error);
        throw new Error(`${reason}\nObjects already created are reused: once fixed, call again with \`issue\` set to the created issue.`);
      } finally {
        rmSync(issueDir, { recursive: true, force: true });
      }
      const branch = opened.branch.name;

      const request = findRequest(ctx.sessionManager.getBranch());
      let worktree: string | undefined;
      let setupFailure: string | undefined;
      let sessionFile: string | undefined;
      let tab: { window: string; block: string } | undefined;

      try {
        progress(`Fetching origin and creating the worktree of ${branch}…`);
        await runOrThrow('git', ['-C', layout.clone, 'fetch', '--quiet', '--prune', 'origin'], { timeoutMs: LONG_TIMEOUT_MS, signal });
        ({ worktree, setupFailure } = await createWorktree(layout.clone, branch, signal));

        signal?.throwIfAborted();
        sessionFile = forkSession(parentFile, request, { worktree, clone: layout.clone, issue: opened.issue.iid, branch }, branch);

        const reviewStep = !reviewer
          ? 'The user asked for no review: skip this step.'
          : `Run a \`reviewer\` subagent with thinking \`high\` and the model \`${reviewer}\`. Give it the issue, the diff to review, and the checks already run. Fix the findings you confirm, rerun the reviewer once if the fixes are substantial, and keep each dismissed finding with its reason for the MR description.`;
        const workersStep = !workerModel
          ? 'Implement the change yourself.'
          : `Orchestrate rather than write the code yourself: plan the change, then delegate its implementation, in scoped and self-contained parts, to \`general-purpose\` subagents with the model \`${workerModel}\`, authorized to edit. Keep your own context for planning, integration, and verification, and check their actual changes.`;
        const mergeStep = params.autoMerge
          ? `The user asked for the MR to be merged: once it is published ready, run \`python3 ${glabTask} merge --issue ${opened.issue.iid}\`, which enables auto-merge when a pipeline runs on the pushed commit.`
          : 'Do not merge the MR, nor enable auto-merge.';
        const brief = renderBrief(readFileSync(BRIEF_TEMPLATE_PATH, 'utf8'), {
          request: requestText(request),
          task: params.task.trim(),
          worktree,
          clone: layout.clone,
          userCheckout: layout.userCheckout,
          issue: `#${opened.issue.iid} "${opened.issue.title}", ${opened.issue.web_url}`,
          issueIid: String(opened.issue.iid),
          mr: `!${opened.mr.iid}, ${opened.mr.draft ? 'draft' : 'ready'}, ${opened.mr.web_url}`,
          branch: `\`${branch}\`, the issue's canonical branch, tracking \`origin/${branch}\`.`,
          glabTask,
          setup: setupFailure
            ? `the worktree's pre-start hooks (env files, venv) failed. Fix the environment before anything else:\n\n  \`\`\`text\n${setupFailure.replace(/^/gm, '  ')}\n  \`\`\``
            : "the worktree's pre-start hooks (env files, venv) succeeded.",
          workersStep,
          reviewStep,
          mergeStep,
        });

        signal?.throwIfAborted();
        progress(`Opening the Rex tab ${REX_SESSION} › ${branch}…`);
        tab = await openRexTab(branch, worktree, piCommand(sessionFile, model, pi.getThinkingLevel(), brief), sessionExists);
        await confirmStart(sessionFile, tab.block, signal);
      } catch (error: unknown) {
        // The agent did not start: close its tab first, so that a slow pi cannot start in the worktree
        // being removed, then remove its session and worktree, so that a retry starts clean.
        if (tab) await run('rex', ['window', 'close', '-s', REX_SESSION, tab.window]);
        if (sessionFile) rmSync(sessionFile, { force: true });
        if (worktree) await run('git', ['-C', layout.clone, 'worktree', 'remove', '--force', worktree]);
        if (signal?.aborted) throw error;

        // The issue, its branch, and its MR stay: a retry with `newIssue` would create them again.
        const reason = error instanceof Error ? error.message : String(error);
        throw new Error(
          `${reason}\nIssue #${opened.issue.iid}, its branch, and MR !${opened.mr.iid} exist (${opened.issue.web_url}): once fixed, call again with \`issue: ${opened.issue.iid}\`, not \`newIssue\`.`,
        );
      }

      watched.set(branch, { branch, sessionFile, state: 'working' });
      startWatching(ctx);

      const lines = [
        `Fired issue #${opened.issue.iid}${opened.issue.created ? ' (created)' : ''} into ${worktree}, with ${model}; workers: ${workerModel ?? 'none'}; review: ${reviewer ?? 'none'}; auto-merge: ${params.autoMerge ? 'yes' : 'no'}.`,
        `Issue: ${opened.issue.web_url}`,
        `MR: !${opened.mr.iid}${opened.mr.created ? ' (created as a draft)' : ''}, ${opened.mr.web_url}`,
        `Rex: tab "${branch}" in session ${REX_SESSION} (find it with Go to Anything, or /fire).`,
        `Session: ${sessionFile}`,
        ...(setupFailure ? [`The worktree's pre-start hooks failed; the agent was told to fix the environment first:\n${setupFailure}`] : []),
      ];
      const details: FireDetails = {
        issue: opened.issue.iid,
        issueTitle: opened.issue.title,
        issueUrl: opened.issue.web_url,
        mr: opened.mr.iid,
        mrUrl: opened.mr.web_url,
        repo: basename(layout.clone),
        worktree,
        branch,
        sessionFile,
        model,
        review,
        autoMerge: params.autoMerge ?? false,
        setupFailure,
      };

      return { content: [{ type: 'text', text: lines.join('\n') }], details };
    },

    renderResult(result, { expanded }, theme) {
      const text = textOf(result.content);
      const details = result.details as FireDetails | undefined;
      // A failure or a progress update: no details yet.
      if (!details?.mrUrl) return new Text(text, 0, 0);

      const options = [`review ${details.review}`, details.autoMerge && 'auto-merge', details.setupFailure && 'setup failed'].filter(Boolean).join(', ');
      const summary = [
        `${theme.fg(details.setupFailure ? 'warning' : 'success', '✓')} fired ${theme.fg('accent', `${details.repo} #${details.issue}`)} ${details.issueTitle} ${theme.fg('dim', `(${options})`)}`,
        `  ${theme.fg('muted', 'MR')} ${details.mrUrl}`,
      ].join('\n');

      return new Text(expanded ? `${summary}\n\n${text}` : summary, 0, 0);
    },
  });

  const subcommands = [
    { value: 'run', label: 'run', description: 'Fire the task this conversation settled' },
    { value: 'list', label: 'list', description: 'Jump to a fired agent, or open its session when it stopped' },
    { value: 'prune', label: 'prune', description: 'Close and remove the agents whose MR is merged or closed' },
  ];

  pi.registerCommand('fire', {
    description: 'Fire a task in a worktree, e.g. `/fire #123, thorough review, merge it`; `/fire` lists the fired agents',
    getArgumentCompletions: (prefix) => {
      const matches = subcommands.filter((subcommand) => subcommand.value.startsWith(prefix.trim()));

      return matches.length > 0 ? matches : null;
    },
    handler: async (args, ctx) => {
      const command = parseFireArgs(args);
      if (command.kind === 'run') {
        // The model calls the tool as for a typed "fire in wt" request.
        const request = command.task ? `fire in wt: ${command.task}` : 'fire in wt';
        if (ctx.isIdle()) pi.sendUserMessage(request);
        else pi.sendUserMessage(request, { deliverAs: 'followUp' });

        return;
      }

      const clones = agentClones();
      if (clones.length === 0) {
        ctx.ui.notify('No agent has been fired yet', 'info');
        return;
      }

      if (command.kind === 'prune') {
        await pruneFired(clones, ctx);
        return;
      }

      const { agents, sessionId } = await listFiredAgents(clones);
      if (agents.length === 0) {
        ctx.ui.notify('No fired agent session', 'info');
        return;
      }

      const labels = agentLabels(agents);
      const choice = await ctx.ui.select('Fired agents', labels);
      if (choice === undefined) return;

      const agent = agents[labels.indexOf(choice)];
      if (!agent.pid) {
        await ctx.switchSession(agent.session.path);
        return;
      }

      // A running agent owns its session: go to its tab rather than open the session a second time.
      if (!agent.tab || !sessionId) {
        ctx.ui.notify(`${agent.branch} runs in pi (pid ${agent.pid}), outside the Rex session ${REX_SESSION}: quit it to open its session here`, 'warning');
        return;
      }

      const shown = await jumpToTab(sessionId, agent.tab.windowId);
      if (!shown) {
        ctx.ui.notify(
          `${agent.branch} is now the active tab of the Rex session ${REX_SESSION}: switch to that session. For /fire to switch itself, turn on Remote Control in Rex's settings, under Rex Server.`,
          'info',
        );
      }
    },
  });

  /** Mark this fired agent's Rex tab with its state. The mark is a courtesy: failing to set it is ignored. */
  const markTab = async (state: TabState) => {
    if (!firedBranch) return;

    try {
      ownWindow ??= await ownTab();
      if (ownWindow) await run('rex', ['window', 'rename', '-s', REX_SESSION, ownWindow, tabLabel(firedBranch, state)]);
    } catch {
      // Rex is absent or restarting.
    }
  };

  pi.on('agent_start', () => markTab('working'));

  pi.on('agent_settled', (_event, ctx) => {
    // The run's last message tells how it ended: an aborted or failed run leaves the task unfinished.
    const messages = ctx.sessionManager.getBranch().filter((entry) => entry.type === 'message');
    const last = messages.at(-1)?.message;
    const failed = last?.role === 'assistant' && (last.stopReason === 'error' || last.stopReason === 'aborted');

    return markTab(failed ? 'failed' : 'done');
  });

  pi.on('session_start', (_event, ctx) => {
    const branch = ctx.sessionManager.getBranch();
    const fired = branch.find((entry) => entry.type === 'custom' && entry.customType === ENTRY_TYPE);
    const sessionFile = ctx.sessionManager.getSessionFile();

    if (fired?.type !== 'custom' || !sessionFile) {
      // The agents this session fired: their count comes back in the footer after a reload or a resume.
      // A fired agent's session is left out, as its conversation holds the fires of its siblings.
      for (const entry of branch) {
        if (entry.type !== 'message' || entry.message.role !== 'toolResult' || entry.message.toolName !== 'fire' || entry.message.isError) continue;

        const details = entry.message.details as Partial<FireDetails> | undefined;
        if (details?.branch && details.sessionFile) watched.set(details.branch, { branch: details.branch, sessionFile: details.sessionFile });
      }
      startWatching(ctx);

      return;
    }

    // A subagent that inherited the conversation holds the entry too, as a fork stored beside its
    // parent: the tab is not its own to mark.
    const parentSession = ctx.sessionManager.getHeader()?.parentSession;
    const isSubagent = parentSession !== undefined && dirname(parentSession) === dirname(sessionFile);
    if (!isSubagent) firedBranch = (fired.data as FireEntry).branch;

    const owner = lockSession(`${sessionFile}.pid`);
    if (owner) {
      ctx.ui.notify(`This session is already open in pi (pid ${owner}), probably in the Rex session ${REX_SESSION}: quit here and jump there.`, 'error');
      return;
    }

    lockFile = `${sessionFile}.pid`;
  });

  pi.on('session_shutdown', () => {
    if (lockFile && existsSync(lockFile) && readFileSync(lockFile, 'utf8') === String(process.pid)) rmSync(lockFile);
    lockFile = undefined;
    firedBranch = undefined;
    ownWindow = undefined;
    stopWatching();
    watched.clear();
  });
}
