import type { Tab, TabState } from './rex.ts';
import { lockOwner, type FireDetails } from './session.ts';

const PING_EXCERPT_CHARS = 400;

/** A fired agent's state. `stopped`: no pi runs its session; `running`: one does, outside Rex. */
export type AgentState = TabState | 'running' | 'stopped';

const STATE_ICONS: Record<AgentState, string> = { working: '●', running: '◐', done: '✓', failed: '⚠', stopped: '○' };

/** A fired agent's state: its Rex tab's while a pi holds its session, `running` without a tab. */
export function agentState(sessionFile: string, branch: string, tabs: readonly Tab[], isAlive?: (pid: number) => boolean): { state: AgentState; pid?: number; tab?: Tab } {
  const pid = lockOwner(sessionFile, isAlive);
  if (!pid) return { state: 'stopped' };

  const tab = tabs.find((candidate) => candidate.branch === branch);

  return { state: tab?.state ?? 'running', pid, tab };
}

/** A row of the `/fire` picker. */
export interface AgentRow {
  state: AgentState;
  repo: string;
  branch: string;
  mr?: string;
  modified: Date;
}

/** The footer status of the agents fired from a session, as icon counts: `fire ●2 ◐1 ✓9`. */
export function firedStatus(states: readonly AgentState[]): string | undefined {
  const counts = (['working', 'running', 'done', 'failed'] as const)
    .map((state) => ({ state, count: states.filter((candidate) => candidate === state).length }))
    .filter(({ count }) => count > 0)
    .map(({ state, count }) => `${STATE_ICONS[state]}${count}`);

  return counts.length > 0 ? `fire ${counts.join(' ')}` : undefined;
}

/** One distinct label per row: the picker returns the chosen label, not its index. */
export function agentLabels(rows: readonly AgentRow[]): string[] {
  const seen = new Map<string, number>();

  return rows.map((row) => {
    const parts = [`${STATE_ICONS[row.state]} ${row.state}`, row.repo, row.branch, row.mr && `MR ${row.mr}`, row.modified.toLocaleString()];
    const label = parts.filter(Boolean).join('  ·  ');
    const count = (seen.get(label) ?? 0) + 1;
    seen.set(label, count);

    return count === 1 ? label : `${label} (${count})`;
  });
}

export const SWITCH_TO_PARENT = '↑ the session that fired this one';

/**
 * The rows of the `/fire switch` picker: the agents this session fired, in the order they were fired,
 * after the session that fired it when there is one. Distinct, as issues are.
 */
export function switchLabels(fires: readonly FireDetails[], states: ReadonlyMap<string, AgentState | undefined>, hasParent: boolean): string[] {
  const children = fires.map((fire) => {
    const state = states.get(fire.branch);

    return [state && STATE_ICONS[state], `#${fire.issue} ${fire.issueTitle}`, `· !${fire.mr}`].filter(Boolean).join(' ');
  });

  return hasParent ? [SWITCH_TO_PARENT, ...children] : children;
}

/** What `/fire ping` tells of one fired agent. */
export interface PingRow {
  state: AgentState;
  issue: number;
  issueTitle: string;
  mr: number;
  mrUrl: string;
  /** Absent when GitLab could not be reached. */
  mrStatus?: string;
  /** Last write of the agent's session. */
  active?: Date;
  lastMessage?: string;
}

function ago(date: Date, now: Date): string {
  const minutes = Math.max(0, Math.round((now.getTime() - date.getTime()) / 60_000));
  if (minutes < 60) return `${minutes} min ago`;
  if (minutes < 48 * 60) return `${Math.round(minutes / 60)} h ago`;

  return `${Math.round(minutes / (24 * 60))} d ago`;
}

/** The report of `/fire ping`, as Markdown: one item per agent, in the order they were fired. */
export function pingReport(rows: readonly PingRow[], now: Date): string {
  const counts = (['working', 'running', 'done', 'failed', 'stopped'] as const)
    .map((state) => ({ state, count: rows.filter((row) => row.state === state).length }))
    .filter(({ count }) => count > 0)
    .map(({ state, count }) => `${count} ${state}`);

  const items = rows.map((row) => {
    const mr = `[!${row.mr}](${row.mrUrl})${row.mrStatus ? ` ${row.mrStatus}` : ''}`;
    const head = [`${STATE_ICONS[row.state]} ${row.state}`, `#${row.issue} ${row.issueTitle}`, mr, row.active && ago(row.active, now)].filter(Boolean).join(' · ');
    if (!row.lastMessage) return `- ${head}`;

    // Its first paragraph: an agent's report leads with its conclusion.
    const paragraph = row.lastMessage.trim().split(/\n\s*\n/)[0];
    const flat = paragraph.split('\n').map((line) => line.trim()).join(' ');
    const excerpt = flat.length > PING_EXCERPT_CHARS ? `${flat.slice(0, PING_EXCERPT_CHARS).trimEnd()}…` : flat;

    return `- ${head}\n  > ${excerpt}`;
  });

  return [`Fired agents of this session: ${counts.join(', ')}.`, '', ...items].join('\n');
}
