import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { basename, dirname, join, resolve, sep } from 'node:path';
import { failure, LONG_TIMEOUT_MS, run, runOrThrow } from './exec.ts';

// Set in an agent clone's own git config, which the repository's content cannot write, once the
// clone's origin was checked: the origin it vouches for.
const TRUSTED_ORIGIN_KEY = 'pi-fire.trustedorigin';

export interface RepoLayout {
  /** Agent-only clone owning the worktrees. */
  clone: string;
  /** The user's own checkout of the repository: clone reference, never touched by agents. */
  userCheckout: string;
}

export function clonesDir(home = homedir()): string {
  return join(home, '.pi', 'src');
}

/**
 * From a checkout under ~/src, the clone is ~/.pi/src/<name>. From an agent clone or one of its
 * worktrees (a fired agent firing again), it is that clone. Linked worktrees resolve to their main
 * checkout through the common git directory.
 */
export function layoutFor(commonGitDir: string, home = homedir()): RepoLayout {
  const mainCheckout = dirname(commonGitDir);
  const name = basename(mainCheckout);

  if (mainCheckout.startsWith(clonesDir(home) + sep)) return { clone: mainCheckout, userCheckout: join(home, 'src', name) };

  return { clone: join(clonesDir(home), name), userCheckout: mainCheckout };
}

/**
 * The GitLab path of a repository named by its short name or path in projects.md, whose table rows
 * read `| short name | gitlab path | ... |`. A path absent from the table is taken as is only within
 * a top-level group of the table's: the clone runs with the user's trust.
 */
export function gitlabProject(projectsMarkdown: string, repo: string): { name: string; path: string } | undefined {
  const groups = new Set<string>();
  for (const line of projectsMarkdown.split('\n')) {
    const [name, path] = line.split('|').slice(1, 3).map((cell) => cell.trim());
    if (!name || !path?.includes('/')) continue;

    if (repo === name || repo === path) return { name, path };
    groups.add(path.split('/')[0]);
  }

  const isPath = /^[\w.-]+(\/[\w.-]+)+$/.test(repo) && !repo.split('/').includes('..');
  if (isPath && groups.has(repo.split('/')[0])) return { name: basename(repo), path: repo };

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

/** The origin URL of a main checkout, read from its git config without spawning git. */
export function readOrigin(checkout: string): string | undefined {
  const config = join(checkout, '.git', 'config');
  if (!existsSync(config)) return undefined;

  const section = readFileSync(config, 'utf8').split(/^\s*\[/m).find((block) => /^remote\s+"origin"\]/.test(block));

  return section?.match(/^\s*url\s*=\s*(.+?)\s*$/m)?.[1];
}

/** The git checkouts directly under a directory, with their origin. */
function checkoutsIn(dir: string): { checkout: string; origin: string }[] {
  if (!existsSync(dir)) return [];

  return readdirSync(dir).flatMap((name) => {
    const checkout = join(dir, name);
    const origin = readOrigin(checkout);

    return origin ? [{ checkout, origin }] : [];
  });
}

/** The agent-only clones: every repository an agent was fired into. */
export function agentClones(): string[] {
  return checkoutsIn(clonesDir()).map(({ checkout }) => checkout);
}

function isWithin(path: string, dir: string): boolean {
  return path === dir || path.startsWith(dir + sep);
}

/**
 * The clone layout and origin of the current repository, or of the one `repo` names. Only the user's
 * own repositories qualify, as the clone runs with the trust of its checkout: the current one, a
 * checkout under ~/src or ~/.pi/src, or a project of the glab skill's references/projects.md. An
 * existing clone of the same origin is reused, whatever its name.
 */
export async function resolveRepo(repo: string | undefined, cwd: string, projectsFile: string): Promise<RepoLayout & { originUrl: string }> {
  const home = homedir();
  const userSrc = join(home, 'src');
  const reuseClone = (layout: RepoLayout, originUrl: string) => {
    const existing = checkoutsIn(clonesDir()).find(({ origin }) => originPath(origin) === originPath(originUrl));

    return { ...layout, clone: existing?.checkout ?? layout.clone, originUrl };
  };

  const candidates = repo ? [resolve(cwd, repo.replace(/^~(?=\/|$)/, home)), join(userSrc, repo)] : [cwd];
  const checkout = candidates.find((candidate) => existsSync(join(candidate, '.git')));
  if (checkout) {
    if (repo && !isWithin(checkout, userSrc) && !isWithin(checkout, clonesDir())) {
      throw new Error(`${checkout} is outside ~/src and ~/.pi/src: fire from that checkout, or name a project of the glab skill's references/projects.md`);
    }

    const commonGitDir = await runOrThrow('git', ['-C', checkout, 'rev-parse', '--path-format=absolute', '--git-common-dir']);
    const originUrl = await runOrThrow('git', ['-C', checkout, 'remote', 'get-url', 'origin']);

    return reuseClone(layoutFor(commonGitDir), originUrl);
  }

  if (!repo) throw new Error(`${cwd} is not a git checkout`);

  // A GitLab path is known when a checkout of the user's has it as origin, else through projects.md.
  const ownCheckout = checkoutsIn(userSrc).find(({ origin }) => originPath(origin) === repo);
  if (ownCheckout) return reuseClone({ clone: join(clonesDir(), basename(ownCheckout.checkout)), userCheckout: ownCheckout.checkout }, ownCheckout.origin);

  const project = gitlabProject(readFileSync(projectsFile, 'utf8'), repo);
  if (!project) {
    throw new Error(`unknown repository "${repo}": neither a checkout under ~/src, nor a project of the glab skill's references/projects.md`);
  }

  return reuseClone({ clone: join(clonesDir(), project.name), userCheckout: join(userSrc, project.name) }, `git@gitlab.com:${project.path}.git`);
}

/** Clone the repository when it is not yet, then vouch for its origin, which `isTrustedClone` checks. */
export async function ensureClone(layout: RepoLayout, originUrl: string, signal: AbortSignal | undefined): Promise<void> {
  if (existsSync(layout.clone)) {
    // Clones are named after the repository alone: two projects of the same name would share one.
    const cloneOrigin = await runOrThrow('git', ['-C', layout.clone, 'remote', 'get-url', 'origin']);
    if (originPath(cloneOrigin) !== originPath(originUrl)) {
      throw new Error(`${layout.clone} is a clone of ${cloneOrigin}, not of ${originUrl}: move it away to fire into this repository`);
    }
  } else {
    // Objects come from the user's checkout, then --dissociate copies them: the clone stays valid
    // whatever later happens to that checkout.
    const reference = existsSync(join(layout.userCheckout, '.git')) ? ['--reference', layout.userCheckout, '--dissociate'] : [];
    await runOrThrow('git', ['clone', '--quiet', ...reference, originUrl, layout.clone], { timeoutMs: LONG_TIMEOUT_MS, signal });
  }

  const origin = await runOrThrow('git', ['-C', layout.clone, 'remote', 'get-url', 'origin']);
  await runOrThrow('git', ['-C', layout.clone, 'config', '--local', TRUSTED_ORIGIN_KEY, origin]);
}

/**
 * Whether a directory belongs to an agent clone as trusted as the user's own checkouts: one whose
 * origin was vouched for when it was last fired into, or that of the user's checkout of its name.
 */
export async function isTrustedClone(cwd: string): Promise<boolean> {
  if (!isWithin(resolve(cwd), clonesDir())) return false;

  const commonGitDir = await run('git', ['-C', cwd, 'rev-parse', '--path-format=absolute', '--git-common-dir']);
  if (commonGitDir.code !== 0) return false;

  const clone = dirname(commonGitDir.stdout.trim());
  const origin = readOrigin(clone);
  if (!origin || dirname(clone) !== clonesDir()) return false;

  const vouched = await run('git', ['-C', clone, 'config', '--local', '--get', TRUSTED_ORIGIN_KEY]);
  if (vouched.code === 0 && vouched.stdout.trim() === origin) return true;

  const userOrigin = readOrigin(join(homedir(), 'src', basename(clone)));

  return userOrigin !== undefined && originPath(userOrigin) === originPath(origin);
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

export async function listLinkedWorktrees(clone: string): Promise<{ path: string; branch?: string }[]> {
  return linkedWorktrees(await runOrThrow('git', ['-C', clone, 'worktree', 'list', '--porcelain']), clone);
}

/**
 * A worktree on the issue's branch, which exists on origin once `glab_task.py open` ran. A failing
 * pre-start hook leaves the worktree in place: the agent gets the failure to fix rather than the
 * launch being lost.
 */
export async function createWorktree(
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
