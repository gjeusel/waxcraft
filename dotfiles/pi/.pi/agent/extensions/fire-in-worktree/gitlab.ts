import { originPath, readOrigin } from './repo.ts';
import { runOrThrow } from './exec.ts';

// GitLab's GraphQL pages hold at most 100 nodes: the branches are asked for in chunks that fit.
const BRANCHES_PER_QUERY = 30;

/** The fields of an MR that `/fire ping` and `/fire merge` read. */
export interface Mr {
  iid: number;
  web_url: string;
  state: string;
  draft: boolean;
  source_branch: string;
  source_project_id: number;
  target_project_id: number;
  target_branch: string;
  has_conflicts?: boolean;
  detailed_merge_status?: string;
  merge_when_pipeline_succeeds?: boolean;
  auto_merge_enabled?: boolean | null;
  head_pipeline?: { status: string } | null;
}

/** A REST call of GitLab's API, run in a clone for glab to resolve `:fullpath`. */
export async function gitlabGet<T>(clone: string, path: string): Promise<T> {
  return JSON.parse(await runOrThrow('glab', ['api', path, '--output', 'json'], { cwd: clone })) as T;
}

export function describeMr(mr: Pick<Mr, 'state' | 'draft' | 'has_conflicts' | 'head_pipeline'>): string {
  if (mr.state !== 'opened') return mr.state;

  const parts = [mr.draft ? 'draft' : 'ready', `pipeline ${mr.head_pipeline?.status ?? 'none'}`, mr.has_conflicts && 'conflicts'];

  return parts.filter(Boolean).join(', ');
}

/** The GraphQL query of the MRs of `branches` in a project, most recently updated first. */
export function mrStatesQuery(projectPath: string, branches: readonly string[]): string {
  // JSON strings are GraphQL strings: names are quoted and escaped alike.
  const list = branches.map((branch) => JSON.stringify(branch)).join(', ');

  return `query { project(fullPath: ${JSON.stringify(projectPath)}) { id mergeRequests(sourceBranches: [${list}], sort: UPDATED_DESC, first: 100) { nodes { sourceBranch state sourceProjectId } } } }`;
}

interface MrStatesResponse {
  data?: { project?: { id: string; mergeRequests: { nodes: { sourceBranch: string; state: string; sourceProjectId: number | null }[] } } | null };
  errors?: { message: string }[];
}

/**
 * The state of the latest MR of each branch from a GraphQL answer: opened, merged, closed, or none.
 * Only the project's own MRs count: listings also hold MRs from forks.
 */
export function parseMrStates(response: MrStatesResponse, branches: readonly string[]): Map<string, string> {
  if (response.errors?.length) throw new Error(response.errors.map((error) => error.message).join('; '));

  const project = response.data?.project;
  if (!project) throw new Error('project not found');

  const projectId = Number(project.id.split('/').at(-1));
  const states = new Map(branches.map((branch) => [branch, 'none']));
  // Most recently updated first: the first MR of a branch is its latest.
  const seen = new Set<string>();
  for (const mr of project.mergeRequests.nodes) {
    if (mr.sourceProjectId !== projectId || seen.has(mr.sourceBranch) || !states.has(mr.sourceBranch)) continue;

    seen.add(mr.sourceBranch);
    states.set(mr.sourceBranch, mr.state);
  }

  return states;
}

/** The state of the latest MR of each branch in the clone's project, in one query per 30 branches. */
export async function mrStates(clone: string, branches: readonly string[]): Promise<Map<string, string>> {
  const origin = readOrigin(clone);
  if (!origin) throw new Error(`${clone} has no origin`);

  const projectPath = originPath(origin);
  const states = new Map<string, string>();
  for (let start = 0; start < branches.length; start += BRANCHES_PER_QUERY) {
    const chunk = branches.slice(start, start + BRANCHES_PER_QUERY);
    const output = await runOrThrow('glab', ['api', 'graphql', '-f', `query=${mrStatesQuery(projectPath, chunk)}`], { cwd: clone });
    for (const [branch, state] of parseMrStates(JSON.parse(output) as MrStatesResponse, chunk)) states.set(branch, state);
  }

  return states;
}
