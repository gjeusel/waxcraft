import { existsSync, realpathSync } from 'node:fs';
import { homedir } from 'node:os';
import { basename, dirname, resolve } from 'node:path';

export interface PathRules {
  deny: string[];
  ask: string[];
}

export interface PathVerdict {
  action: 'deny' | 'ask';
  /** The candidate path (lexical or symlink-resolved) that matched. */
  path: string;
  pattern: string;
}

/** A pattern must be anchored so it cannot silently match relative to an unknown directory. */
export function isAnchoredPattern(pattern: string): boolean {
  return pattern.startsWith('/') || pattern.startsWith('~/') || pattern.startsWith('**/');
}

function expandHome(path: string): string {
  if (path === '~') return homedir();
  return path.startsWith('~/') ? `${homedir()}${path.slice(1)}` : path;
}

/**
 * Compile a path glob: `**` spans directories (`**` followed by `/` also matches zero of them), while
 * `*` and `?` stay within one segment. macOS volumes are case-insensitive by default, so matching
 * is too; otherwise `~/.SSH/config` would slip past a `~/.ssh/**` rule.
 */
export function globToRegExp(pattern: string): RegExp {
  const expanded = expandHome(pattern);
  let source = '';

  for (let index = 0; index < expanded.length; index += 1) {
    const character = expanded[index];
    if (character === '*' && expanded[index + 1] === '*') {
      index += 1;
      if (expanded[index + 1] === '/') {
        index += 1;
        source += '(?:.*/)?';
      } else {
        source += '.*';
      }
    } else if (character === '*') {
      source += '[^/]*';
    } else if (character === '?') {
      source += '[^/]';
    } else {
      source += character.replace(/[.+^${}()|[\]\\]/g, '\\$&');
    }
  }

  return new RegExp(`^${source}$`, process.platform === 'darwin' ? 'i' : '');
}

/** Follow symlinks through the deepest existing ancestor; a new file has no real path of its own. */
function realTarget(path: string): string {
  const missing: string[] = [];
  let existing = path;
  while (!existsSync(existing)) {
    const parent = dirname(existing);
    if (parent === existing) return path;

    missing.unshift(basename(existing));
    existing = parent;
  }

  try {
    return resolve(realpathSync(existing), ...missing);
  } catch {
    return path;
  }
}

/**
 * Candidate paths for a write/edit target, resolved like Pi's tools (optional `@` prefix, `~`, cwd).
 * Both the lexical and the symlink-resolved path are checked: stowed dotfiles are reachable through
 * `~/...` links and through the repository, and either spelling must hit the same rule.
 */
export function targetPaths(inputPath: string, cwd: string): string[] {
  const stripped = inputPath.startsWith('@') ? inputPath.slice(1) : inputPath;
  const lexical = resolve(cwd, expandHome(stripped));

  return [...new Set([lexical, realTarget(lexical)])];
}

/** Deny rules take precedence over ask rules; returns undefined when no rule matches. */
export function inspectPath(inputPath: string, cwd: string, rules: PathRules): PathVerdict | undefined {
  const targets = targetPaths(inputPath, cwd);

  for (const action of ['deny', 'ask'] as const) {
    for (const pattern of rules[action]) {
      const expression = globToRegExp(pattern);
      const path = targets.find((target) => expression.test(target));
      if (path !== undefined) return { action, path, pattern };
    }
  }

  return undefined;
}
