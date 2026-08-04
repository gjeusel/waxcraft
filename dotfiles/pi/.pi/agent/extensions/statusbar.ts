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
          const centerW = visibleWidth(center);
          const rightW = visibleWidth(pctPlain);
          // Truncate the path first if the three parts can't coexist.
          const maxLeft = Math.max(0, width - centerW - rightW - 4);
          if (visibleWidth(left) > maxLeft) {
            // The TUI truncator surrounds its ellipsis with full ANSI resets,
            // even for plain input. Remove those before styling the whole line.
            left = truncateToWidth(left, maxLeft, '…').replaceAll('\x1b[0m', '');
          }
          const leftW = visibleWidth(left);

          // justify-between: distribute the remaining space evenly across the two gaps.
          const free = Math.max(2, width - leftW - centerW - rightW);
          const padL = Math.max(1, Math.floor(free / 2));
          const padR = Math.max(1, free - padL);
          // Truncate before applying the theme color. `truncateToWidth()` resets
          // ANSI styles before its ellipsis, which would otherwise make the
          // truncated suffix fall back to the terminal's bright default color.
          const line = left + ' '.repeat(padL) + center + ' '.repeat(padR) + pctPlain;
          return [theme.fg('dim', truncateToWidth(line, width))];
        },
      };
    });
  });
}
