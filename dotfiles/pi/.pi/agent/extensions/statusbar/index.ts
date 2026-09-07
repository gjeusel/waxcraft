/**
 * statusbar — minimalist single-line footer.
 * Replaces the built-in two/three-line footer (pwd+branch / token stats /
 * extension statuses, e.g. MCP info) with one line:
 *   <repo path>       <model> · <effort> · [fast] · [session]       <context %>
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
    ctx.ui.setFooter((_tui, theme, footerData) => {
      return {
        dispose() {},
        invalidate() {},
        render(width: number): string[] {
          const cwd = shortenCwd(ctx.sessionManager.getCwd(), process.env.HOME);
          let left = cwd;

          const usageStatus = footerData.getExtensionStatuses().get('usage');
          const isFast = usageStatus !== undefined && /^codex fast(?:\s|$)/u.test(usageStatus);
          const sessionName = pi.getSessionName();
          const truncatedSessionName = sessionName
            ? truncateToWidth(sessionName, 50, '…').replaceAll('\x1b[0m', '')
            : undefined;
          const centerParts = [
            ctx.model?.id ?? 'no-model',
            ctx.thinkingLevel ?? 'off',
            isFast ? 'fast' : undefined,
            truncatedSessionName,
          ].filter((part): part is string => part !== undefined);
          let center = centerParts.join(' · ');

          const usage = ctx.getContextUsage();
          const pct = usage?.percent ?? null;
          const pctPlain = pct === null ? '?%' : `${pct.toFixed(0)}%`;
          const rightW = visibleWidth(pctPlain);
          const maxCenter = Math.max(0, width - rightW - 2);
          if (visibleWidth(center) > maxCenter) {
            center = truncateToWidth(center, maxCenter, '…').replaceAll('\x1b[0m', '');
          }
          const centerW = visibleWidth(center);
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
