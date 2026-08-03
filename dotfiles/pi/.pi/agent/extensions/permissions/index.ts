/**
 * permissions — vendored fork of npm:pi-permissions@1.0.4 (MIT, badlogic).
 * Identical rule loading/evaluation (rules.ts untouched); the only change is
 * startup reporting: instead of the chat notification ("Permissions loaded:
 * 0 allow, N deny rules") it publishes a deny-rule count via
 * ctx.ui.setStatus("permissions", ...), which the statusbar extension picks up.
 * A count of 0 in the statusbar signals a missing/broken permissions.json.
 */
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';
import type { ParsedRule, PermissionsConfig } from './rules.ts';
import { evaluate, parseRules } from './rules.ts';

async function loadConfig(cwd: string): Promise<PermissionsConfig> {
  const paths = [join(cwd, '.pi', 'permissions.json')];

  const home = process.env.HOME || process.env.USERPROFILE || '';
  if (home) {
    paths.push(join(home, '.pi', 'agent', 'permissions.json'));
  }

  for (const configPath of paths) {
    try {
      const content = await readFile(configPath, 'utf-8');
      return JSON.parse(content) as PermissionsConfig;
    } catch {
      // File not found or invalid, try next
    }
  }
  return {};
}

export default function (pi: ExtensionAPI) {
  let allowRules: ParsedRule[] = [];
  let denyRules: ParsedRule[] = [];

  async function reloadRules(cwd: string) {
    const config = await loadConfig(cwd);
    allowRules = parseRules(config.permissions?.allow ?? []);
    denyRules = parseRules(config.permissions?.deny ?? []);
  }

  pi.on('session_start', async (_event, ctx) => {
    await reloadRules(ctx.cwd);
    ctx.ui.setStatus('permissions', `⛨${denyRules.length}`);
  });

  pi.on('tool_call', async (event) => {
    const result = evaluate(event.toolName, event.input as Record<string, unknown>, allowRules, denyRules);
    if (result.blocked) {
      return { block: true, reason: result.reason! };
    }
  });
}
