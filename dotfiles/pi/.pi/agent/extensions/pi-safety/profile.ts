import type { SafetyConfig } from './config.ts';
import { effectiveDenyWrite } from './config.ts';

const GLOB_TOKEN = /(\*\*\/|\*\*|\*)/g;
const REGEX_METACHARACTER = /[.*+?^${}()|[\]\\]/g;

function escapeRegexLiteral(value: string): string {
  return value.replace(REGEX_METACHARACTER, '\\$&');
}

/** Compile our small path-glob language to Seatbelt-compatible regex syntax. */
export function pathGlobToSeatbeltRegex(pattern: string): string {
  // A directory/** rule protects both the directory inode and its contents.
  const matchesDirectoryTree = pattern.endsWith('/**');
  const body = (matchesDirectoryTree ? pattern.slice(0, -3) : pattern)
    .split(GLOB_TOKEN)
    .map((token) => {
      if (token === '**/') return '(.*/)?';
      if (token === '**') return '.*';
      if (token === '*') return '[^/]*';
      return escapeRegexLiteral(token);
    })
    .join('');

  return `^${body}${matchesDirectoryTree ? '(/.*)?' : ''}$`;
}

function pathFilter(pattern: string): string {
  if (pattern.includes('*')) return `(regex ${JSON.stringify(pathGlobToSeatbeltRegex(pattern))})`;
  return `(subpath ${JSON.stringify(pattern)})`;
}

function denyRules(operation: 'file-read*' | 'file-write*', patterns: string[]): string[] {
  return patterns.map((pattern) => `(deny ${operation} ${pathFilter(pattern)})`);
}

export function buildSandboxProfile(config: SafetyConfig): string {
  return [
    '(version 1)',
    '(allow default)',
    ...denyRules('file-read*', config.filesystem.denyRead),
    ...denyRules('file-write*', effectiveDenyWrite(config)),
  ].join('\n');
}
