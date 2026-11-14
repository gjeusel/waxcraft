import { errorText } from './exec.ts';
import type { Mr } from './gitlab.ts';

export const MERGE_POLL_MS = 15_000;
// While auto-merge is not enabled yet: GitLab usually settles whether an MR can merge within seconds.
export const ENABLE_RETRY_MS = 5_000;
export const UNSETTLED_WAIT_MS = 5 * 60_000;
export const MERGE_WAIT_MS = 60 * 60_000;
// GitLab's `detailed_merge_status` while it has not yet computed whether an MR can merge.
const UNSETTLED_MERGE_STATUSES = new Set(['unchecked', 'checking', 'preparing', 'approvals_syncing']);
// Failed GitLab calls while following the MR before telling it: a minute's worth.
const FOLLOW_FAILURES_TOLD = 4;

type Level = 'info' | 'warning' | 'error';

/** What `/fire merge` does outside itself: given, so that its steps run in tests without GitLab or Rex. */
export interface MergeWatchIo {
  branch: string;
  /** A GitLab REST call; throws on a failed call or malformed output. */
  gitlab<T>(path: string): Promise<T>;
  /** The glab skill's merge: checks the MR is ready and pushed, then enables auto-merge. */
  enableAutoMerge(): Promise<{ code: number; stdout: string; stderr: string }>;
  closePane(): Promise<void>;
  /** Called once the watch stopped on merge conflicts. */
  onConflicts(mr: Mr): Promise<void>;
  notify(message: string, level: Level): void;
  setStatus(text: string | undefined): void;
  now(): number;
  /** Run `callback` after `ms`; returns what cancels it. */
  schedule(callback: () => void, ms: number): () => void;
}

export interface MergeWatch {
  /** One step: enable auto-merge, or follow the MR once it is enabled. Schedules the next one. */
  step(): Promise<void>;
  /** Retire the watch: a step still awaiting GitLab then does nothing, nor closes a pane. */
  stop(): void;
}

/** The footer status of `/fire merge` while its watch lives: `merge !12 auto-merge on, pipeline running · 4m`. */
export function mergeStatus(iid: number | undefined, step: string, elapsedMs: number): string {
  const minutes = Math.floor(elapsedMs / 60_000);

  return ['merge', iid !== undefined && `!${iid}`, step, minutes > 0 && `· ${minutes}m`].filter(Boolean).join(' ');
}

const hasConflicts = (mr: Mr) => mr.has_conflicts === true || mr.detailed_merge_status === 'conflict';

/**
 * Enable auto-merge on a fired agent's MR, retried while GitLab still checks whether the MR can merge,
 * then follow the MR until it merged and close the agent's pane. GitLab accepts auto-merge on a
 * conflicting MR, which then never merges: conflicts stop the watch and go to `onConflicts`.
 */
export function createMergeWatch(io: MergeWatchIo): MergeWatch {
  const started = io.now();
  let stopped = false;
  let cancelNext: (() => void) | undefined;
  let projectId: number | undefined;
  let iid: number | undefined;
  let mrUrl = '';
  let enabled = false;
  let toldUnsettled = false;
  let failures = 0;
  let closeFailed = false;

  const stop = () => {
    stopped = true;
    cancelNext?.();
    cancelNext = undefined;
    io.setStatus(undefined);
  };

  const stopWith = (message: string, level: Level) => {
    stop();
    io.notify(message, level);
  };

  const showStatus = (text: string) => io.setStatus(mergeStatus(iid, text, io.now() - started));

  const stopOnConflicts = async (mr: Mr) => {
    stop();
    await io.onConflicts(mr);
  };

  // The project's own open MR of the branch, as `glab_task.py` resolves it: listings also hold MRs
  // from forks. Once found, the MR is fetched by its iid.
  const fetchMr = async (): Promise<Mr | undefined> => {
    if (iid !== undefined) return io.gitlab<Mr>(`projects/:fullpath/merge_requests/${iid}`);

    projectId ??= (await io.gitlab<{ id: number }>('projects/:fullpath')).id;
    const path = `projects/:fullpath/merge_requests?source_branch=${encodeURIComponent(io.branch)}&state=opened`;
    const own = (await io.gitlab<Mr[]>(path)).filter(
      (mr) => mr.source_branch === io.branch && mr.source_project_id === projectId && mr.target_project_id === projectId,
    );
    if (own.length > 1) throw new Error(`several open MRs of ${io.branch}: ${own.map((mr) => `!${mr.iid}`).join(', ')}`);

    iid = own[0]?.iid;

    return own[0];
  };

  const enable = async () => {
    let opened: Mr | undefined;
    try {
      opened = await fetchMr();
    } catch (error: unknown) {
      if (!stopped) stopWith(`Cannot check the MR of ${io.branch}: ${errorText(error)}`, 'error');
      return;
    }
    if (stopped) return;

    if (opened?.state === 'opened' && hasConflicts(opened)) {
      await stopOnConflicts(opened);
      return;
    }

    // Unknown is not clear: auto-merge is asked for anyway, and asked again if GitLab refuses it
    // while it has not yet told whether the MR can merge.
    const status = opened?.detailed_merge_status ?? '';
    const unsettled = UNSETTLED_MERGE_STATUSES.has(status);
    showStatus(unsettled ? `enabling auto-merge, GitLab checking (${status})` : 'enabling auto-merge');

    const merged = await io.enableAutoMerge();
    if (stopped) return;

    if (merged.code !== 0) {
      const reason = (merged.stderr.trim() || merged.stdout.trim()).slice(-2000);
      if (!unsettled || io.now() - started > UNSETTLED_WAIT_MS) {
        stopWith(`Auto-merge not enabled:\n${reason}`, 'error');
        return;
      }

      if (!toldUnsettled) io.notify(`GitLab is still checking whether !${iid} can merge (${status}): enabling auto-merge is retried in the background\n${reason}`, 'warning');
      toldUnsettled = true;

      return;
    }

    const { mr } = JSON.parse(merged.stdout) as { mr: { iid: number; web_url: string } };
    iid = mr.iid;
    mrUrl = mr.web_url;
    enabled = true;
    io.notify(`Auto-merge enabled on !${iid}: followed in the background, this pane closes once it merged`, 'info');
    showStatus('auto-merge on');
  };

  const follow = async () => {
    let current: Mr;
    try {
      current = await io.gitlab<Mr>(`projects/:fullpath/merge_requests/${iid}`);
      failures = 0;
    } catch (error: unknown) {
      // Retried at the next step; told once.
      failures += 1;
      if (failures === FOLLOW_FAILURES_TOLD && !stopped) io.notify(`Cannot follow !${iid}, retrying: ${errorText(error)}`, 'warning');
      return;
    }
    if (stopped) return;

    if (current.state === 'merged') {
      showStatus('merged, closing the pane');
      try {
        await io.closePane();
      } catch (error: unknown) {
        // Kept watching: the next step tries again, until the deadline; told once.
        if (closeFailed || stopped) return;

        closeFailed = true;
        io.notify(`!${iid} merged, but its pane did not close: ${errorText(error)}`, 'error');
      }
      return;
    }

    if (current.state === 'opened' && hasConflicts(current)) {
      await stopOnConflicts(current);
      return;
    }

    const autoMerge = Boolean(current.auto_merge_enabled || current.merge_when_pipeline_succeeds);
    const pipeline = current.head_pipeline?.status;
    const stuck =
      current.state !== 'opened' ? `is ${current.state}`
      : pipeline === 'failed' || pipeline === 'canceled' ? `has its pipeline ${pipeline}`
      : !autoMerge ? 'lost its auto-merge'
      : undefined;
    if (stuck) {
      stopWith(`!${iid} ${stuck}: the pane stays open (${mrUrl})`, 'warning');
      return;
    }

    showStatus(`auto-merge on, pipeline ${pipeline ?? 'pending'}`);
  };

  // One step at a time, the next one scheduled once it ended: a GitLab call may outlast the interval.
  const step = async () => {
    if (stopped) return;

    try {
      if (io.now() - started > MERGE_WAIT_MS) stopWith(`!${iid} is still not merged after ${MERGE_WAIT_MS / 60_000} min: the pane stays open (${mrUrl})`, 'warning');
      else if (enabled) await follow();
      else await enable();
    } catch (error: unknown) {
      if (!stopped) stopWith(`/fire merge failed: ${errorText(error)}`, 'error');
    }
    if (stopped) return;

    cancelNext = io.schedule(() => void step(), enabled ? MERGE_POLL_MS : ENABLE_RETRY_MS);
  };

  showStatus('checking the MR');

  return { step, stop };
}
