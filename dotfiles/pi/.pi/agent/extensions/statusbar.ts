/**
 * statusbar — minimalist single-line footer.
 * Replaces the built-in two/three-line footer (pwd+branch / token stats /
 * extension statuses, e.g. MCP info) with one line:
 *   <repo path> (<branch>)        <model> · <effort>        <context %>
 * left-aligned / centered / right-aligned. Extension statuses (MCP, etc.)
 * and token/cost stats are deliberately not shown.
 */
import { isAbsolute, relative, resolve, sep } from 'node:path';
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';
import { truncateToWidth, visibleWidth } from '@earendil-works/pi-tui';

function shortenCwd(cwd: string, home: string | undefined): string {
  if (!home) return cwd;
  const rel = relative(resolve(home), resolve(cwd));
  const inside = rel === '' || (rel !== '..' && !rel.startsWith(`..${sep}`) && !isAbsolute(rel));
  if (!inside) return cwd;
  return rel === '' ? '~' : `~${sep}${rel}`;
}

export default function (pi: ExtensionAPI) {
  pi.on('session_start', async (_event, ctx) => {
    ctx.ui.setFooter((tui, theme, footerData) => {
      const unsub = footerData.onBranchChange(() => tui.requestRender());
      return {
        dispose: unsub,
        invalidate() {},
        render(width: number): string[] {
          const cwd = shortenCwd(ctx.sessionManager.getCwd(), process.env.HOME);
          const branch = footerData.getGitBranch();
          let left = branch ? `${cwd} (${branch})` : cwd;

          const model = ctx.model?.id ?? 'no-model';
          const center = ctx.model?.reasoning ? `${model} · ${ctx.thinkingLevel ?? 'off'}` : model;

          const usage = ctx.getContextUsage();
          const pct = usage?.percent ?? null;
          const pctPlain = pct === null ? '?%' : `${pct.toFixed(0)}%`;
          // Only the vendored permissions extension's status is surfaced;
          // everything else published via setStatus (MCP, etc.) stays hidden.
          const perms = footerData.getExtensionStatuses().get('permissions');
          const rightPlain = perms ? `${perms} ${pctPlain}` : pctPlain;
          const right = theme.fg('dim', rightPlain);

          const centerW = visibleWidth(center);
          const rightW = visibleWidth(rightPlain);
          // Truncate the path first if the three parts can't coexist.
          const maxLeft = Math.max(0, width - centerW - rightW - 4);
          if (visibleWidth(left) > maxLeft) left = truncateToWidth(left, maxLeft, '…');
          const leftW = visibleWidth(left);

          // justify-between: distribute the remaining space evenly across the two gaps.
          const free = Math.max(2, width - leftW - centerW - rightW);
          const padL = Math.max(1, Math.floor(free / 2));
          const padR = Math.max(1, free - padL);
          const line = theme.fg('dim', left + ' '.repeat(padL) + center + ' '.repeat(padR)) + right;
          return [truncateToWidth(line, width)];
        },
      };
    });
  });
}
