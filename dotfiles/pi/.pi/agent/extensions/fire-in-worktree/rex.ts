import { run, runOrThrow } from './exec.ts';

export const REX_SESSION = 'ai-agents';

/** What a fired agent's Rex tab says of it: the tab's label is its branch, marked once it settles. */
export type TabState = 'working' | 'done' | 'failed';

const TAB_MARKS: Record<TabState, string> = { working: '', done: '✓ ', failed: '⚠ ' };

export interface Tab {
  windowId: string;
  branch: string;
  state: TabState;
}

export interface Pane {
  sessionId: string;
  windowId: string;
  blockId: string;
}

interface RexWindow {
  windowId: string;
  label: string;
  blocks: { blockId: string; label: string }[];
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

/** The tabs of a Rex session (a label or an id), with their panes; none when it does not exist. */
async function listWindows(session: string): Promise<{ sessionId?: string; windows: RexWindow[] }> {
  const listing = await run('rex', ['window', 'ls', '-s', session, '--json']);
  if (listing.code !== 0) return { windows: [] };

  const { session_id, windows = [] } = JSON.parse(listing.stdout) as {
    session_id: string;
    windows?: { window_id: string; label: string; layers?: { blocks: { block_id: string; label: string }[] }[] }[];
  };

  return {
    sessionId: session_id,
    windows: windows.map((window) => ({
      windowId: window.window_id,
      label: window.label,
      blocks: (window.layers ?? []).flatMap((layer) => layer.blocks).map((block) => ({ blockId: block.block_id, label: block.label })),
    })),
  };
}

export async function rexSessionExists(): Promise<boolean> {
  const { sessions } = JSON.parse(await runOrThrow('rex', ['ls', '--json'])) as { sessions: { label: string }[] };

  return sessions.some((session) => session.label === REX_SESSION);
}

/** The tabs of the Rex session of fired agents; none when that session does not exist. */
export async function listTabs(): Promise<{ sessionId?: string; tabs: Tab[] }> {
  const { sessionId, windows } = await listWindows(REX_SESSION);

  return { sessionId, tabs: windows.map((window) => ({ windowId: window.windowId, ...parseTabLabel(window.label) })) };
}

/** The pane of a Rex session (a label or an id) that `matches`, with the tab holding it. */
export async function findPane(session: string, matches: (block: { blockId: string; label: string }) => boolean): Promise<Pane | undefined> {
  const { sessionId, windows } = await listWindows(session);
  for (const window of windows) {
    const block = window.blocks.find(matches);
    if (block && sessionId) return { sessionId, windowId: window.windowId, blockId: block.blockId };
  }

  return undefined;
}

/**
 * A tab and pane named after the branch: Go to Anything finds the agent by either. Returns the tab's
 * window and its pane.
 */
export async function openRexTab(label: string, cwd: string, command: string[], sessionExists: boolean): Promise<{ window: string; block: string }> {
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

export function closeTabs(windowIds: string[]): Promise<unknown> {
  return windowIds.length > 0 ? run('rex', ['window', 'close', '-s', REX_SESSION, ...windowIds]) : Promise.resolve();
}

/** Show a tab of a Rex session in the app. Returns whether the app shows it. */
async function showInApp(sessionId: string, windowId: string): Promise<boolean> {
  const listing = await run('rex', ['client', 'ls', '--json']);
  if (listing.code !== 0) return false;

  const { clients = [] } = JSON.parse(listing.stdout) as { clients?: { client_id: string; info?: { kind?: string } }[] };
  const app = clients.find((client) => client.info?.kind === 'app');
  if (!app) return false;

  const shown = await run('rex', ['-C', app.client_id, 'do', 'session.select', `session_id=${sessionId}`, `window_id=${windowId}`]);

  return shown.code === 0;
}

/**
 * Make a tab the active one of the Rex session, then show that session in the app, which the app
 * accepts only with its Remote Control setting on. Returns whether the app shows it.
 */
export async function jumpToTab(sessionId: string, windowId: string): Promise<boolean> {
  await runOrThrow('rex', ['focus', '-s', REX_SESSION, windowId]);

  return showInApp(sessionId, windowId);
}

/** Focus a pane, then show its tab in the app. Returns whether the app shows it. */
export async function focusPane(pane: Pane): Promise<boolean> {
  await runOrThrow('rex', ['focus', '-s', pane.sessionId, pane.blockId]);

  return showInApp(pane.sessionId, pane.windowId);
}

/** The Rex tab of the fired agents' session holding a pane. */
export async function tabOfPane(blockId: string): Promise<string | undefined> {
  const { windows } = await listWindows(REX_SESSION);

  return windows.find((window) => window.blocks.some((block) => block.blockId === blockId))?.windowId;
}

/** The last lines a pane shows. */
export async function paneTail(blockId: string, lines = 30): Promise<string> {
  const screen = await run('rex', ['capture', '-s', REX_SESSION, '-b', blockId, '--trim']);

  return screen.stdout.trim().split('\n').slice(-lines).join('\n');
}
