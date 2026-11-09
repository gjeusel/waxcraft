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
 * session of the worktree; `/fired` lists those of the current repository and opens one, and
 * `/fired prune` closes and removes those whose MR is merged or closed. Reviewer models come from
 * ~/.pi/agent/fire.json, read at each fire.
 */
import { spawn } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { homedir, tmpdir } from 'node:os';
import { basename, dirname, join, resolve, sep } from 'node:path';
import { setTimeout as sleep } from 'node:timers/promises';
import { fileURLToPath } from 'node:url';
import {
  getAgentDir,
  SessionManager,
  type ExtensionAPI,
  type ExtensionCommandContext,
  type SessionEntry,
  type SessionInfo,
} from '@earendil-works/pi-coding-agent';
import { Type } from 'typebox';

const REX_SESSION = 'ai-agents';
const ENTRY_TYPE = 'fire-in-worktree';
const BRIEF_TEMPLATE_PATH = fileURLToPath(new URL('brief.md', import.meta.url));
const LONG_TIMEOUT_MS = 15 * 60_000;
// The launched pi takes the session lock on start: until then, its launch is not confirmed.
const START_TIMEOUT_MS = 45_000;

export type Review = 'standard' | 'thorough' | 'none';

export interface Reviewers {
  standard: string;
  thorough: string;
}

/**
 * fire.json: the reviewer models by the agent's provider, `default` for the others, so that the
 * review runs on another provider than the agent.
 */
export interface FireConfig {
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
  const parsed: unknown = JSON.parse(readFileSync(path, 'utf8'));
  const reviewers = (parsed as { reviewers?: unknown } | null)?.reviewers;
  if (typeof reviewers !== 'object' || reviewers === null || Array.isArray(reviewers)) {
    throw new Error(`${path}: expected {"reviewers": {"<provider>" | "default": {"standard", "thorough"}}}`);
  }

  for (const [provider, models] of Object.entries(reviewers)) {
    for (const review of ['standard', 'thorough'] as const) {
      const model = (models as Record<string, unknown> | null)?.[review];
      if (typeof model !== 'string' || !/^[^/]+\/./.test(model)) {
        throw new Error(`${path}: reviewers.${provider}.${review} must be "provider/modelId"`);
      }
    }
  }

  return { reviewers: reviewers as Record<string, Reviewers> };
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

/** The user message that asked for the fire: the last one on the active branch. */
export function findRequest(branch: readonly SessionEntry[]): SessionEntry | undefined {
  for (let index = branch.length - 1; index >= 0; index -= 1) {
    const entry = branch[index];
    if (entry.type === 'message' && entry.message.role === 'user') return entry;
  }

  return undefined;
}

export function requestText(entry: SessionEntry | undefined): string {
  if (entry?.type !== 'message' || entry.message.role !== 'user') return '(not found)';

  return textOf(entry.message.content).trim();
}

/**
 * Fork the session file into a session of the worktree, resuming just before the request: the brief
 * restates it, and the launching turn's tool calls, still running, stay out. Storing it beside the
 * launching session would let `pi -c` there pick the agent's session, the most recently written.
 */
export function forkSession(parentFile: string, request: SessionEntry | undefined, entry: FireEntry, name: string): string {
  const fork = SessionManager.forkFrom(parentFile, entry.worktree);
  if (request?.parentId === null) fork.resetLeaf();
  else if (request?.parentId) fork.branch(request.parentId);

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

  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: options.cwd,
      env,
      stdio: ['ignore', 'pipe', 'pipe'],
      timeout: options.timeoutMs ?? 60_000,
      signal: options.signal,
    });
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (data: Buffer) => (stdout += data.toString()));
    child.stderr.on('data', (data: Buffer) => (stderr += data.toString()));
    child.on('error', reject);
    child.on('close', (code, signal) => resolve({ code: code ?? (signal ? 1 : 0), stdout, stderr }));
  });
}

function failure(command: string, args: string[], result: RunResult): Error {
  const output = (result.stderr.trim() || result.stdout.trim()).slice(-2000);

  return new Error(`\`${command} ${args.join(' ')}\` failed (exit ${result.code}):\n${output}`);
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
  if (existsSync(layout.clone)) return;

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
    throw new Error(`${branch} already has a worktree, ${existing}: jump to its agent with /fired, or remove it with \`wt -C ${clone} remove ${branch}\``);
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

/** A tab and pane named after the branch: Go to Anything finds the agent by either. Returns the pane. */
async function openRexTab(label: string, cwd: string, command: string[], sessionExists: boolean): Promise<string> {
  const options = ['-c', cwd, '--keep-open', '--json', '--', ...command];

  // `rex new` leaves the app's view alone; `window new` needs --focus=false for that.
  let block: string;
  if (sessionExists) {
    const created = JSON.parse(await runOrThrow('rex', ['window', 'new', '-s', REX_SESSION, label, '--focus=false', ...options]));
    block = created.block_ids[0];
  } else {
    const created = JSON.parse(await runOrThrow('rex', ['new', REX_SESSION, '--window', label, ...options]));
    block = created.initial_windows[0].block_ids[0];
  }
  await runOrThrow('rex', ['block', 'rename', '-s', REX_SESSION, block, label]);

  return block;
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

/**
 * Sessions of the clone's worktrees, most recently active first, without those of subagents: forks of
 * another session in the same directory.
 */
async function listFiredSessions(clone: string): Promise<SessionInfo[]> {
  const porcelain = await runOrThrow('git', ['-C', clone, 'worktree', 'list', '--porcelain']);
  const worktrees = linkedWorktrees(porcelain, clone);
  const sessions = (await Promise.all(worktrees.map((worktree) => SessionManager.list(worktree.path)))).flat();
  const own = sessions.filter((session) => !session.parentSessionPath || dirname(session.parentSessionPath) !== dirname(session.path));

  return own.sort((a, b) => b.modified.getTime() - a.modified.getTime());
}

/** The state of the project's latest MR of a branch: opened, merged, closed, or none. */
async function mrState(clone: string, projectId: number, branch: string): Promise<string> {
  const path = `projects/:fullpath/merge_requests?source_branch=${encodeURIComponent(branch)}&order_by=updated_at&sort=desc`;
  const mrs = JSON.parse(await runOrThrow('glab', ['api', path, '--output', 'json'], { cwd: clone })) as {
    state: string;
    source_project_id: number;
  }[];

  return mrs.find((mr) => mr.source_project_id === projectId)?.state ?? 'none';
}

/** Close the tab and remove the worktree of every fired agent whose MR is merged or closed. */
async function pruneFired(clone: string, ctx: ExtensionCommandContext): Promise<void> {
  const worktrees = linkedWorktrees(await runOrThrow('git', ['-C', clone, 'worktree', 'list', '--porcelain']), clone);
  const project = JSON.parse(await runOrThrow('glab', ['api', 'projects/:fullpath', '--output', 'json'], { cwd: clone })) as { id: number };
  const states = await Promise.all(
    worktrees.map(async (worktree) => ({ ...worktree, state: worktree.branch ? await mrState(clone, project.id, worktree.branch) : 'none' })),
  );
  const done = states.filter((worktree) => worktree.state === 'merged' || worktree.state === 'closed');
  if (done.length === 0) {
    ctx.ui.notify(`Nothing to prune: no fired worktree of ${basename(clone)} has a merged or closed MR`, 'info');
    return;
  }

  const list = done.map((worktree) => `${worktree.branch} (${worktree.state})`).join('\n');
  if (!(await ctx.ui.confirm(`Prune ${done.length} fired agent(s)?`, `Closes their Rex tab and removes their worktree:\n${list}`))) return;

  const { windows = [] } = (await rexSessionExists())
    ? (JSON.parse(await runOrThrow('rex', ['window', 'ls', '-s', REX_SESSION, '--json'])) as { windows?: { window_id: string; label: string }[] })
    : {};
  const failures: string[] = [];
  for (const worktree of done) {
    const tabs = windows.filter((window) => window.label === worktree.branch).map((window) => window.window_id);
    if (tabs.length > 0) await run('rex', ['window', 'close', '-s', REX_SESSION, ...tabs]);

    // wt deletes a merged branch and keeps an unmerged one, and refuses a worktree with changes.
    const removal = await run('wt', ['-C', clone, 'remove', worktree.branch!, '--yes', '--foreground'], { timeoutMs: LONG_TIMEOUT_MS });
    if (removal.code !== 0) failures.push(`${worktree.branch}: ${(removal.stderr.trim() || removal.stdout.trim()).split('\n').at(-1)}`);
  }

  const pruned = done.length - failures.length;
  ctx.ui.notify(
    [`Pruned ${pruned} fired agent(s)`, ...failures.map((line) => `kept ${line}`)].join('\n'),
    failures.length > 0 ? 'warning' : 'info',
  );
}

function isRunning(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch (error: unknown) {
    return (error as NodeJS.ErrnoException).code === 'EPERM';
  }
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

export default function (pi: ExtensionAPI) {
  // Set in a fired agent's session that this process owns.
  let lockFile: string | undefined;

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
      'fire: Once it returns, confirm in a sentence or two where the task went, and do not work on that task in this session.',
    ],
    parameters: fireSchema,
    // Calls share the clone and the Rex session, which the first call may be creating.
    executionMode: 'sequential',

    async execute(_toolCallId, params, signal, onUpdate, ctx) {
      const parentFile = ctx.sessionManager.getSessionFile();
      if (!parentFile) throw new Error('fire forks the session, and this one is not saved (--no-session)');
      if (!ctx.model) throw new Error('fire needs a current model for the new agent');
      if ((params.issue === undefined) === (params.newIssue === undefined)) throw new Error('pass exactly one of `issue` and `newIssue`');

      const review = params.review ?? 'standard';
      // Read at each fire, so that an edit applies without /reload; checked before anything is created.
      const reviewer = review === 'none' ? undefined : reviewersFor(loadConfig(join(getAgentDir(), 'fire.json')), ctx.model.provider)[review];
      const slash = reviewer?.indexOf('/') ?? -1;
      if (reviewer && !ctx.modelRegistry.find(reviewer.slice(0, slash), reviewer.slice(slash + 1))) {
        throw new Error(`fire.json: unknown reviewer model ${reviewer}`);
      }

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

      progress(`Fetching origin and creating the worktree of ${branch}…`);
      await runOrThrow('git', ['-C', layout.clone, 'fetch', '--quiet', '--prune', 'origin'], { timeoutMs: LONG_TIMEOUT_MS, signal });
      const { worktree, setupFailure } = await createWorktree(layout.clone, branch, signal);
      const model = `${ctx.model.provider}/${ctx.model.id}`;
      const request = findRequest(ctx.sessionManager.getBranch());
      let sessionFile: string | undefined;

      try {
        signal?.throwIfAborted();
        sessionFile = forkSession(parentFile, request, { worktree, clone: layout.clone, issue: opened.issue.iid, branch }, branch);

        const reviewStep = !reviewer
          ? 'The user asked for no review: skip this step.'
          : `Run a \`reviewer\` subagent with thinking \`high\` and the model \`${reviewer}\`. Give it the issue, the diff to review, and the checks already run. Fix the findings you confirm, rerun the reviewer once if the fixes are substantial, and keep each dismissed finding with its reason for the MR description.`;
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
          reviewStep,
          mergeStep,
        });

        signal?.throwIfAborted();
        progress(`Opening the Rex tab ${REX_SESSION} › ${branch}…`);
        const block = await openRexTab(branch, worktree, piCommand(sessionFile, model, pi.getThinkingLevel(), brief), sessionExists);
        await confirmStart(sessionFile, block, signal);
      } catch (error: unknown) {
        // The agent did not start: remove its worktree and session, so that a retry starts clean.
        if (sessionFile) rmSync(sessionFile, { force: true });
        await run('git', ['-C', layout.clone, 'worktree', 'remove', '--force', worktree]);
        throw error;
      }

      const lines = [
        `Fired issue #${opened.issue.iid}${opened.issue.created ? ' (created)' : ''} into ${worktree}, with ${model}; review: ${review}; auto-merge: ${params.autoMerge ? 'yes' : 'no'}.`,
        `MR: !${opened.mr.iid}${opened.mr.created ? ' (created as a draft)' : ''}, ${opened.mr.web_url}`,
        `Rex: tab "${branch}" in session ${REX_SESSION} (find it with Go to Anything).`,
        `Session: ${sessionFile}, also listed by /fired in pi from ${layout.userCheckout}.`,
        ...(setupFailure ? [`The worktree's pre-start hooks failed; the agent was told to fix the environment first:\n${setupFailure}`] : []),
      ];

      return {
        content: [{ type: 'text', text: lines.join('\n') }],
        details: { issue: opened.issue.iid, mr: opened.mr.iid, worktree, branch, sessionFile, model, review, autoMerge: params.autoMerge ?? false, setupFailure },
      };
    },
  });

  pi.registerCommand('fired', {
    description: 'Open the session of an agent fired ("fire in wt") from this repository; `/fired prune` removes those whose MR is merged or closed',
    handler: async (args, ctx) => {
      const lookup = await run('git', ['-C', ctx.cwd, 'rev-parse', '--path-format=absolute', '--git-common-dir']);
      const clone = lookup.code === 0 ? layoutFor(lookup.stdout.trim()).clone : undefined;
      if (!clone || !existsSync(clone)) {
        ctx.ui.notify('No agent has been fired from this repository', 'info');
        return;
      }

      if (args.trim() === 'prune') {
        await pruneFired(clone, ctx);
        return;
      }

      const sessions = await listFiredSessions(clone);
      if (sessions.length === 0) {
        ctx.ui.notify('No fired agent session in this repository', 'info');
        return;
      }

      const labels = sessions.map((session) => `${session.name ?? basename(session.cwd)}  ·  ${session.modified.toLocaleString()}`);
      const choice = await ctx.ui.select('Fired agents', labels);
      if (choice === undefined) return;

      await ctx.switchSession(sessions[labels.indexOf(choice)].path);
    },
  });

  pi.on('session_start', (_event, ctx) => {
    const fired = ctx.sessionManager.getBranch().some((entry) => entry.type === 'custom' && entry.customType === ENTRY_TYPE);
    const sessionFile = ctx.sessionManager.getSessionFile();
    if (!fired || !sessionFile) return;

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
  });
}
