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
 * whose MR is merged or closed. `/fire ping` adds to the conversation where the agents fired from this
 * session are at (state, MR, pipeline, last message), so that the session can pilot them. `/fire switch`
 * moves the Rex focus between a session and the agents it fired: to the pane of one of them, picked
 * in a list, or straight to the pane of the session that fired this one. `/fire self-close`, in a fired
 * agent's session, closes its own Rex pane once its MR is merged or closed; `/fire merge` first enables
 * auto-merge on that MR, then closes the pane once it merged.
 *
 * A fired agent marks its Rex tab when it settles (✓ done, ⚠ failed), and a session that fired agents
 * shows their count in its footer.
 *
 * Modules: config (fire.json), repo (clones, worktrees, trust), session (session files and their
 * records), rex (tabs and panes), gitlab (MR states), merge-watch (`/fire merge`), report (states and
 * the labels shown of them).
 */
import { existsSync, mkdtempSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, dirname, join } from 'node:path';
import { setTimeout as sleep } from 'node:timers/promises';
import { fileURLToPath } from 'node:url';
import { getAgentDir, type ExtensionAPI, type ExtensionCommandContext, type ExtensionContext } from '@earendil-works/pi-coding-agent';
import { Text } from '@earendil-works/pi-tui';
import { Type } from 'typebox';
import { loadConfig, reviewersFor, type Review } from './config.ts';
import { errorText, LONG_TIMEOUT_MS, run, runOrThrow } from './exec.ts';
import { describeMr, gitlabGet, mrStates, type Mr } from './gitlab.ts';
import { createMergeWatch, type MergeWatch } from './merge-watch.ts';
import { agentClones, createWorktree, ensureClone, isTrustedClone, listLinkedWorktrees, resolveRepo } from './repo.ts';
import { agentLabels, agentState, firedStatus, pingReport, switchLabels, SWITCH_TO_PARENT, type AgentRow, type AgentState, type PingRow } from './report.ts';
import { closeTabs, findPane, focusPane, jumpToTab, listTabs, openRexTab, paneTail, REX_SESSION, rexSessionExists, tabLabel, tabOfPane, type Pane, type Tab, type TabState } from './rex.ts';
import {
  firedEntryOfBranch,
  firedSessionsOf,
  findRequest,
  forkSession,
  lastAssistantText,
  lockFileOf,
  lockSession,
  ownFires,
  paneFileOf,
  readFireRecord,
  readPaneRecord,
  requestText,
  textOf,
  type FireDetails,
  type PaneRecord,
} from './session.ts';

export * from './config.ts';
export * from './gitlab.ts';
export * from './merge-watch.ts';
export * from './repo.ts';
export * from './report.ts';
export * from './rex.ts';
export * from './session.ts';

const STATUS_KEY = 'fire';
const WATCH_INTERVAL_MS = 15_000;
const MERGE_STATUS_KEY = 'fire-merge';
// The choices offered when `/fire merge` finds merge conflicts, the default first.
const CONFLICT_CHOICES = { fixAndMerge: 'Yes, fix them and merge', fixOnly: 'Yes, fix them only', no: 'No' } as const;
const PING_TYPE = 'fire-ping';
const BRIEF_TEMPLATE_PATH = fileURLToPath(new URL('brief.md', import.meta.url));
// The launched pi takes the session lock on start: until then, its launch is not confirmed.
const START_TIMEOUT_MS = 45_000;

/** What `glab_task.py open` prints. */
interface OpenedTask {
  issue: { iid: number; title: string; web_url: string; created: boolean };
  branch: { name: string; created: boolean; base: string };
  mr: { iid: number; web_url: string; draft: boolean; created: boolean };
}

export type FireCommand =
  | { kind: 'list' }
  | { kind: 'prune' }
  | { kind: 'ping' }
  | { kind: 'switch' }
  | { kind: 'self-close' }
  | { kind: 'merge' }
  | { kind: 'run'; task: string };

interface FiredAgent extends AgentRow {
  sessionFile: string;
  pid?: number;
  tab?: Tab;
}

/** A fired agent, as the session that fired it follows it. */
interface Watched {
  branch: string;
  sessionFile: string;
  /** Absent until first looked at: an agent found settled then is not announced. */
  state?: AgentState;
}

const fireSchema = Type.Object(
  {
    repo: Type.Optional(
      Type.String({
        description:
          'Repository to fire into, when it is not the current one: a short name or GitLab path from the glab skill\'s references/projects.md (e.g. "venturi"), or the path of a checkout under ~/src.',
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

/**
 * `list`, `prune`, `ping`, `switch`, `self-close`, and `merge` are subcommands, and a bare `run` fires
 * what the conversation settled. Any other text is a task, one starting with "run" included.
 */
export function parseFireArgs(args: string): FireCommand {
  const text = args.trim();
  if (text === '' || text === 'list') return { kind: 'list' };
  if (text === 'prune') return { kind: 'prune' };
  if (text === 'ping') return { kind: 'ping' };
  if (text === 'switch') return { kind: 'switch' };
  if (text === 'self-close') return { kind: 'self-close' };
  if (text === 'merge') return { kind: 'merge' };

  return { kind: 'run', task: text === 'run' ? '' : text };
}

export function renderBrief(template: string, values: Record<string, string>): string {
  // One pass over the template: placeholders inside the values themselves are left as written.
  return template.replace(/\{\{(\w+)\}\}/g, (placeholder, key: string) => {
    if (!Object.hasOwn(values, key)) throw new Error(`brief.md: unknown placeholder ${placeholder}`);

    return values[key];
  });
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

function glabSkillDir(pi: ExtensionAPI): string {
  const glabSkill = pi.getCommands().find((command) => command.source === 'skill' && command.name === 'skill:glab');
  if (!glabSkill) throw new Error('fire works with the glab skill, which is not loaded');

  return dirname(glabSkill.sourceInfo.path);
}

/**
 * The pane where a session is open. A pi started before panes were recorded has none until it
 * reloads: a fired agent is then found by its pane's name, its branch.
 */
async function paneOfSession(sessionFile: string): Promise<Pane | undefined> {
  const record = readPaneRecord(sessionFile);
  if (record) return findPane(record.session, (block) => block.blockId === record.block);

  const fired = existsSync(sessionFile) ? readFireRecord(sessionFile) : undefined;

  return fired && findPane(REX_SESSION, (block) => block.label === fired.branch);
}

/** Wait for the launched pi to take the session lock; on timeout, fail with what its pane shows. */
async function confirmStart(sessionFile: string, block: string, signal: AbortSignal | undefined): Promise<void> {
  const deadline = Date.now() + START_TIMEOUT_MS;
  while (Date.now() < deadline) {
    if (existsSync(lockFileOf(sessionFile))) return;
    await sleep(500, undefined, { signal });
  }

  throw new Error(`the agent did not start within ${START_TIMEOUT_MS / 1000}s; its pane shows:\n${await paneTail(block)}`);
}

/** Where the agents of `fires` are at: their state, their MR on GitLab, and their last message. */
async function pingFired(fires: readonly FireDetails[]): Promise<PingRow[]> {
  const { tabs } = await listTabs();

  return Promise.all(
    fires.map(async (fire): Promise<PingRow> => {
      // The report still comes without GitLab: the MR status is then left out.
      const clone = dirname(fire.worktree).replace(/\.worktrees$/, '');
      const mrStatus = await gitlabGet<Mr>(clone, `projects/:fullpath/merge_requests/${fire.mr}`).then(describeMr, () => undefined);

      // A pruned agent has no session left.
      const hasSession = existsSync(fire.sessionFile);

      return {
        state: agentState(fire.sessionFile, fire.branch, tabs).state,
        issue: fire.issue,
        issueTitle: fire.issueTitle,
        mr: fire.mr,
        mrUrl: fire.mrUrl,
        mrStatus,
        active: hasSession ? statSync(fire.sessionFile).mtime : undefined,
        lastMessage: hasSession ? lastAssistantText(readFileSync(fire.sessionFile, 'utf8')) : undefined,
      };
    }),
  );
}

/**
 * The fired agents of every clone, most recently active first: the sessions of their worktrees that
 * have a fire record, which leaves out those of subagents and of a pi started there by hand.
 */
async function listFiredAgents(clones: string[]): Promise<{ agents: FiredAgent[]; sessionId?: string }> {
  const { sessionId, tabs } = await listTabs();

  const perClone = await Promise.all(
    clones.map(async (clone) => {
      const worktrees = await listLinkedWorktrees(clone);
      const fired = worktrees.flatMap((worktree) => firedSessionsOf(worktree.path));
      // The picker still opens without GitLab: the MR state is then left out.
      const states = await mrStates(clone, [...new Set(fired.map(({ entry }) => entry.branch))]).catch(() => new Map<string, string>());

      return fired.map(({ sessionFile, entry }): FiredAgent => {
        const { state, pid, tab } = agentState(sessionFile, entry.branch, tabs);

        return { sessionFile, pid, tab, state, repo: basename(clone), branch: entry.branch, mr: states.get(entry.branch), modified: statSync(sessionFile).mtime };
      });
    }),
  );

  return { agents: perClone.flat().sort((a, b) => b.modified.getTime() - a.modified.getTime()), sessionId };
}

/**
 * Close the tab and remove the worktree of every fired agent whose MR is merged or closed. A clone
 * whose worktrees or MRs cannot be read is skipped and told, the others pruned.
 */
async function pruneFired(clones: string[], ctx: ExtensionCommandContext): Promise<void> {
  ctx.ui.notify(`Checking the MRs of the fired worktrees of ${clones.map((clone) => basename(clone)).join(', ')}…`, 'info');
  const skipped: string[] = [];
  const perClone = await Promise.all(
    clones.map(async (clone) => {
      try {
        const branches = (await listLinkedWorktrees(clone)).flatMap((worktree) => (worktree.branch ? [worktree.branch] : []));
        const states = branches.length > 0 ? await mrStates(clone, branches) : new Map<string, string>();

        return branches.map((branch) => ({ clone, branch, state: states.get(branch) }));
      } catch (error: unknown) {
        skipped.push(`${basename(clone)}: ${errorText(error).split('\n')[0]}`);
        return [];
      }
    }),
  );
  if (skipped.length > 0) ctx.ui.notify(`Skipped, not checked:\n${skipped.join('\n')}`, 'warning');

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
    await closeTabs(tabs.filter((tab) => tab.branch === worktree.branch).map((tab) => tab.windowId));

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

export default function (pi: ExtensionAPI) {
  // Set in a fired agent's session that this process owns.
  let lockFile: string | undefined;
  // Where this pi says which Rex pane it runs in, for /fire switch.
  let paneFile: string | undefined;
  // In a fired agent's session: its branch, and the Rex tab it runs in, once looked up.
  let firedBranch: string | undefined;
  let ownWindow: string | undefined;
  // The agents fired from this session, and the timer following them while one runs.
  const watched = new Map<string, Watched>();
  let watchTimer: NodeJS.Timeout | undefined;

  // The `/fire merge` watch while it lives.
  let mergeWatch: MergeWatch | undefined;
  // Set while the agent fixes merge conflicts that the user chose to merge after: the merge runs again
  // when it settles.
  let pendingMerge = false;
  // Changes at each session shutdown: work started for a session tells whether it still runs.
  let sessionGeneration = 0;

  const stopMergeWatch = () => {
    mergeWatch?.stop();
    mergeWatch = undefined;
  };

  const stopWatching = () => {
    clearInterval(watchTimer);
    watchTimer = undefined;
  };

  /** Refresh the footer's count of fired agents, and tell when one of them settles. */
  const watch = async (ctx: ExtensionContext) => {
    const { tabs } = await listTabs();
    for (const agent of watched.values()) {
      const { state } = agentState(agent.sessionFile, agent.branch, tabs);

      const settled = state === 'done' || state === 'failed';
      if (settled && agent.state && state !== agent.state) {
        const outcome = state === 'done' ? 'is done' : 'stopped on a failure';
        ctx.ui.notify(`Fired agent ${agent.branch} ${outcome}: /fire jumps to it`, state === 'done' ? 'info' : 'warning');
      }
      agent.state = state;
    }

    const status = firedStatus([...watched.values()].flatMap((agent) => agent.state ?? []));
    ctx.ui.setStatus(STATUS_KEY, status);

    if (!status) stopWatching();
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

      const review: Review = params.review ?? 'standard';
      const reviewerRef = review === 'none' ? undefined : (params.reviewer ?? reviewersFor(config, model.split('/')[0])[review]);
      const reviewer = reviewerRef && checkModel(reviewerRef, 'reviewer');

      const skillDir = glabSkillDir(pi);
      const glabTask = join(skillDir, 'scripts', 'glab_task.py');
      const progress = (text: string) => onUpdate?.({ content: [{ type: 'text', text }], details: undefined });

      // Checked before anything is created on GitLab.
      const [sessionExists] = await Promise.all([rexSessionExists(), runOrThrow('wt', ['--version'])]);
      const layout = await resolveRepo(params.repo, ctx.cwd, join(skillDir, 'references', 'projects.md'));

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
        throw new Error(`${errorText(error)}\nObjects already created are reused: once fixed, call again with \`issue\` set to the created issue.`);
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
        if (tab) await closeTabs([tab.window]);
        if (sessionFile) for (const file of [sessionFile, `${sessionFile}.fire.json`]) rmSync(file, { force: true });
        if (worktree) await run('git', ['-C', layout.clone, 'worktree', 'remove', '--force', worktree]);
        if (signal?.aborted) throw error;

        // The issue, its branch, and its MR stay: a retry with `newIssue` would create them again.
        throw new Error(
          `${errorText(error)}\nIssue #${opened.issue.iid}, its branch, and MR !${opened.mr.iid} exist (${opened.issue.web_url}): once fixed, call again with \`issue: ${opened.issue.iid}\`, not \`newIssue\`.`,
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

  /**
   * `/fire self-close` and `/fire merge`. The merge runs again by itself once the agent fixed the
   * conflicts it was asked to, when the user chose to merge after the fix: `retried` is then set, and
   * conflicts found again stop it rather than asking a second time.
   */
  const closeOrMerge = async (kind: 'self-close' | 'merge', ctx: ExtensionContext, retried = false): Promise<void> => {
    const fired = firedEntryOfBranch(ctx.sessionManager.getBranch());
    if (!fired) {
      ctx.ui.notify(`Nothing to ${kind}: this session is not a fired agent`, 'info');
      return;
    }

    const { REX_SESSION: rexSession, REX_BLOCK: rexBlock } = process.env;
    if (!rexSession || !rexBlock) {
      ctx.ui.notify('This pi does not run in a Rex pane', 'warning');
      return;
    }

    // Ends this pi with its pane: the stale lock and pane record are told apart by their dead pid.
    const closePane = async () => {
      await runOrThrow('rex', ['block', 'close', '-s', rexSession, rexBlock]);
    };

    if (kind === 'self-close') {
      const state = (await mrStates(fired.clone, [fired.branch])).get(fired.branch);
      if (state !== 'merged' && state !== 'closed') {
        ctx.ui.notify(`The MR of ${fired.branch} is ${state}: the pane stays open`, 'info');
        return;
      }

      await closePane();
      return;
    }

    // The conflicts are reported, and their fix offered to this session's agent, the merge following
    // it by default.
    const offerConflictFix = async (mr: Mr) => {
      pendingMerge = false;
      ctx.ui.notify(`!${mr.iid} has merge conflicts with ${mr.target_branch}: it cannot merge (${mr.web_url})`, 'error');
      if (retried) {
        ctx.ui.notify(`!${mr.iid} still has conflicts after the agent's fix: the merge stops, run /fire merge once they are resolved`, 'warning');
        return;
      }

      const choice = await ctx.ui.select(`Fix the conflicts of !${mr.iid} with ${mr.target_branch}?`, Object.values(CONFLICT_CHOICES));
      if (choice === undefined || choice === CONFLICT_CHOICES.no) return;

      const mergeAfter = choice === CONFLICT_CHOICES.fixAndMerge;
      const request = [
        `MR !${mr.iid} (${mr.web_url}) has merge conflicts with \`${mr.target_branch}\`.`,
        `Fetch origin, merge \`origin/${mr.target_branch}\` into \`${fired.branch}\`, resolve the conflicts, rerun the checks, and push.`,
        mergeAfter ? 'Once your turn ends, `/fire merge` runs again by itself.' : 'Then tell me it is ready, for me to run `/fire merge` again.',
      ].join(' ');
      // A follow-up joins the running run: the agent settles only once the request is handled.
      pendingMerge = mergeAfter;
      if (ctx.isIdle()) pi.sendUserMessage(request);
      else pi.sendUserMessage(request, { deliverAs: 'followUp' });
    };

    // All in the background, the session staying usable; a new watch retires the previous one.
    stopMergeWatch();
    const glabTask = join(glabSkillDir(pi), 'scripts', 'glab_task.py');
    const watch = createMergeWatch({
      branch: fired.branch,
      gitlab: (path) => gitlabGet(fired.clone, path),
      enableAutoMerge: () => run('python3', [glabTask, 'merge', '--issue', String(fired.issue)], { cwd: fired.worktree, timeoutMs: 5 * 60_000 }),
      closePane,
      onConflicts: offerConflictFix,
      notify: (message, level) => ctx.ui.notify(message, level),
      setStatus: (text) => ctx.ui.setStatus(MERGE_STATUS_KEY, text),
      now: Date.now,
      schedule: (callback, ms) => {
        const timer = setTimeout(callback, ms);
        timer.unref();

        return () => clearTimeout(timer);
      },
    });
    mergeWatch = watch;
    void watch.step();
  };

  const subcommands = [
    { value: 'run', label: 'run', description: 'Fire the task this conversation settled' },
    { value: 'list', label: 'list', description: 'Jump to a fired agent, or open its session when it stopped' },
    { value: 'prune', label: 'prune', description: 'Close and remove the agents whose MR is merged or closed' },
    { value: 'ping', label: 'ping', description: 'Add to the conversation where the agents fired from this session are at' },
    { value: 'switch', label: 'switch', description: 'Focus the pane of an agent this session fired, or of the session that fired this one' },
    { value: 'self-close', label: 'self-close', description: "Close this fired agent's Rex pane when its MR is merged or closed" },
    { value: 'merge', label: 'merge', description: "Auto-merge this fired agent's MR, then close its Rex pane once merged" },
  ];

  pi.registerCommand('fire', {
    description: 'Fire a task in a worktree, e.g. `/fire #123, thorough review, merge it`; `/fire` lists the fired agents',
    getArgumentCompletions: (prefix) => {
      // No popup once a subcommand is typed in full: pi's Enter on an argument completion only fills
      // it in, while without a popup it submits the command.
      const typed = prefix.trim();
      if (subcommands.some((subcommand) => subcommand.value === typed)) return null;

      const matches = subcommands.filter((subcommand) => subcommand.value.startsWith(typed));

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

      if (command.kind === 'ping') {
        const fires = ownFires(ctx.sessionManager.getBranch());
        if (fires.length === 0) {
          ctx.ui.notify('This session fired no agent', 'info');
          return;
        }

        ctx.ui.notify(`Pinging ${fires.length} fired agent(s)…`, 'info');
        const report = pingReport(await pingFired(fires), new Date());
        // In the conversation, for the model to pilot from; no turn starts: the user asks next.
        pi.sendMessage({ customType: PING_TYPE, content: report, display: true }, { triggerTurn: false });

        return;
      }

      if (command.kind === 'switch') {
        const branch = ctx.sessionManager.getBranch();
        const fired = firedEntryOfBranch(branch);
        const fires = ownFires(branch);
        if (!fired && fires.length === 0) {
          ctx.ui.notify('Nowhere to switch: this session fired no agent, and no session fired it', 'info');
          return;
        }

        // Nothing to pick when the only way is up.
        let choice: string | undefined = SWITCH_TO_PARENT;
        const states = new Map([...watched.values()].map((agent) => [agent.branch, agent.state]));
        const labels = switchLabels(fires, states, fired !== undefined);
        if (fires.length > 0) choice = await ctx.ui.select('Switch to', labels);
        if (choice === undefined) return;

        const fire = choice === SWITCH_TO_PARENT ? undefined : fires[labels.indexOf(choice) - (fired ? 1 : 0)];
        const name = fire ? `#${fire.issue} ${fire.issueTitle}` : 'The session that fired this one';
        const targetSession = fire ? fire.sessionFile : ctx.sessionManager.getHeader()?.parentSession;
        const pane = targetSession && (await paneOfSession(targetSession));
        if (!pane) {
          const hint = fire ? 'it is not open in a Rex pane: /fire list opens its session' : 'it is not open in a Rex pane, or its pi needs a /reload to say where it is';
          ctx.ui.notify(`${name}: ${hint}`, 'warning');
          return;
        }

        const shown = await focusPane(pane);
        if (!shown) ctx.ui.notify(`${name} is focused in its Rex session: switch to that session. For /fire to switch itself, turn on Remote Control in Rex's settings, under Rex Server.`, 'info');

        return;
      }

      if (command.kind === 'self-close' || command.kind === 'merge') {
        await closeOrMerge(command.kind, ctx);
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
        await ctx.switchSession(agent.sessionFile);
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
    const block = process.env.REX_BLOCK;
    if (!firedBranch || !block) return;

    try {
      ownWindow ??= await tabOfPane(block);
      if (ownWindow) await run('rex', ['window', 'rename', '-s', REX_SESSION, ownWindow, tabLabel(firedBranch, state)]);
    } catch {
      // Rex is absent or restarting.
    }
  };

  // An agent clone and its worktrees are as trusted as the user's own checkouts when the clone's
  // origin is one this extension cloned from a known repository, or that of the user's checkout.
  pi.on('project_trust', async (event) => ({ trusted: (await isTrustedClone(event.cwd)) ? 'yes' : 'undecided' }));

  pi.on('agent_start', () => markTab('working'));

  pi.on('agent_settled', (event, ctx) => {
    // The run's last message tells how it ended: an aborted or failed run leaves the task unfinished.
    const messages = ctx.sessionManager.getBranch().filter((entry) => entry.type === 'message');
    const last = messages.at(-1)?.message;
    const failed = last?.role === 'assistant' && (last.stopReason === 'error' || last.stopReason === 'aborted');

    // An abort while compacting or settling leaves the last message's stop reason intact: the event
    // tells it, though the typings in use predate its `aborted` field.
    const aborted = (event as { aborted?: boolean }).aborted === true;

    if (pendingMerge) {
      pendingMerge = false;
      const generation = sessionGeneration;
      if (failed || aborted) ctx.ui.notify('The conflict fix did not finish: the merge stops, run /fire merge once it is done', 'warning');
      // Not awaited: GitLab calls would hold the other settled handlers. A reload meanwhile makes
      // `ctx` stale, its notifications throwing: the failure is then dropped with the session.
      else
        void closeOrMerge('merge', ctx, true).catch((error: unknown) => {
          if (generation === sessionGeneration) ctx.ui.notify(`/fire merge failed: ${errorText(error)}`, 'error');
        });
    }

    return markTab(failed ? 'failed' : 'done');
  });

  pi.on('session_start', (_event, ctx) => {
    const branch = ctx.sessionManager.getBranch();
    const fired = firedEntryOfBranch(branch);
    const sessionFile = ctx.sessionManager.getSessionFile();

    // The agents this session fired: their count comes back in the footer after a reload or a resume.
    for (const fire of ownFires(branch)) watched.set(fire.branch, { branch: fire.branch, sessionFile: fire.sessionFile });
    startWatching(ctx);

    // An interactive pi only: a subagent runs in its parent's pane, which is not its own to claim.
    const { REX_SESSION: rexSession, REX_BLOCK: rexBlock } = process.env;
    if (sessionFile && rexSession && rexBlock && ctx.hasUI) {
      const record: PaneRecord = { pid: process.pid, session: rexSession, block: rexBlock };
      paneFile = paneFileOf(sessionFile);
      writeFileSync(paneFile, JSON.stringify(record));
    }

    if (!fired || !sessionFile) return;

    // A subagent that inherited the conversation holds the entry too, as a fork stored beside its
    // parent: the tab is not its own to mark.
    const parentSession = ctx.sessionManager.getHeader()?.parentSession;
    const isSubagent = parentSession !== undefined && dirname(parentSession) === dirname(sessionFile);
    if (!isSubagent) firedBranch = fired.branch;

    const owner = lockSession(lockFileOf(sessionFile));
    if (owner) {
      ctx.ui.notify(`This session is already open in pi (pid ${owner}), probably in the Rex session ${REX_SESSION}: quit here and jump there.`, 'error');
      return;
    }

    lockFile = lockFileOf(sessionFile);
  });

  pi.on('session_shutdown', (_event, ctx) => {
    if (lockFile && existsSync(lockFile) && readFileSync(lockFile, 'utf8') === String(process.pid)) rmSync(lockFile);
    lockFile = undefined;
    // Another pi may have opened the session since: its record stays.
    if (paneFile && existsSync(paneFile) && readFileSync(paneFile, 'utf8').includes(`"pid":${process.pid},`)) rmSync(paneFile);
    paneFile = undefined;
    firedBranch = undefined;
    ownWindow = undefined;
    stopWatching();
    stopMergeWatch();
    ctx.ui.setStatus(MERGE_STATUS_KEY, undefined);
    pendingMerge = false;
    sessionGeneration += 1;
    watched.clear();
  });
}
