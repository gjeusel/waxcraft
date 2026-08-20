import { createHash } from 'node:crypto';
import { existsSync, readFileSync, realpathSync } from 'node:fs';
import { homedir } from 'node:os';
import { basename, dirname, isAbsolute, join, normalize, resolve } from 'node:path';
import { parse, printParseErrorCode, type ParseError } from 'jsonc-parser';

export interface ArgvPredicate {
  empty?: boolean;
  contains?: string[];
  containsAny?: string[];
  ordered?: string[];
  startsWithAny?: string[];
}

export interface ShellDenyRule {
  command: string;
  argv?: ArgvPredicate;
  reason?: string;
}

export interface SafetyConfig {
  filesystem: {
    denyRead: string[];
    denyWrite: string[];
  };
  shell: {
    deny: ShellDenyRule[];
  };
}

export interface LoadedSafetyConfig {
  config: SafetyConfig;
  configPath: string;
  status: 'loaded' | 'missing' | 'invalid';
  errors: string[];
}

const EMPTY_CONFIG: SafetyConfig = {
  filesystem: { denyRead: [], denyWrite: [] },
  shell: { deny: [] },
};

function agentDirectory(): string {
  return process.env.PI_CODING_AGENT_DIR || join(homedir(), '.pi', 'agent');
}

export function defaultConfigPath(): string {
  return join(agentDirectory(), 'pi-safety.jsonc');
}

function builtInConfig(configPath: string): SafetyConfig {
  const extensionDirectory = join(agentDirectory(), 'extensions', 'pi-safety');
  const wrapper = join(homedir(), '.local', 'bin', 'pi');
  const logicalPaths = [configPath, extensionDirectory, wrapper].map((path) => normalize(path));
  const canonicalPaths = logicalPaths.map(canonicalizeLiteralPath);
  const protectedPaths = [...new Set([...logicalPaths, ...canonicalPaths])];
  return {
    filesystem: { denyRead: [], denyWrite: [...new Set(protectedPaths)] },
    shell: { deny: [] },
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function rejectUnknownKeys(
  value: Record<string, unknown>,
  allowed: string[],
  location: string,
  errors: string[],
): void {
  for (const key of Object.keys(value)) {
    if (!allowed.includes(key)) errors.push(`${location}: unknown property "${key}"`);
  }
}

function stringArray(value: unknown, location: string, errors: string[]): string[] {
  if (value === undefined) return [];
  if (!Array.isArray(value)) {
    errors.push(`${location}: expected an array of strings`);
    return [];
  }
  const result: string[] = [];
  for (const [index, item] of value.entries()) {
    if (typeof item !== 'string' || item.length === 0) {
      errors.push(`${location}[${index}]: expected a non-empty string`);
    } else {
      result.push(item);
    }
  }
  return result;
}

function canonicalizeLiteralPath(path: string): string {
  try {
    return realpathSync.native(path);
  } catch {
    const tail: string[] = [];
    let probe = path;
    while (!existsSync(probe)) {
      const parent = dirname(probe);
      if (parent === probe) return path;
      tail.unshift(basename(probe));
      probe = parent;
    }
    try {
      return resolve(realpathSync.native(probe), ...tail);
    } catch {
      return path;
    }
  }
}

function normalizePathPattern(pattern: string, location: string, errors: string[]): string | undefined {
  const expanded = pattern.replace(/^~(?=$|\/)/, homedir());
  if (/[\u0000-\u001f\u007f]/.test(expanded)) {
    errors.push(`${location}: control characters are not allowed in path patterns`);
    return undefined;
  }
  if (expanded.split('/').some((segment) => segment.includes('**') && segment !== '**')) {
    errors.push(`${location}: ** must occupy a complete path segment`);
    return undefined;
  }
  if (!isAbsolute(expanded)) {
    errors.push(`${location}: path patterns must start with / or ~/`);
    return undefined;
  }
  if (expanded.split('/').includes('..')) {
    errors.push(`${location}: .. path segments are not allowed`);
    return undefined;
  }
  const normalized = normalize(expanded);
  const firstGlob = normalized.indexOf('*');
  if (firstGlob < 0) return canonicalizeLiteralPath(normalized);

  // Canonicalize the non-glob parent so aliases such as /var -> /private/var
  // cannot bypass the Seatbelt profile or produce mismatched policy hashes.
  const separator = normalized.lastIndexOf('/', firstGlob);
  const parent = separator === 0 ? '/' : normalized.slice(0, separator);
  const tail = normalized.slice(separator + 1);
  return join(canonicalizeLiteralPath(parent), tail);
}

function nonEmptyStringArray(value: unknown, location: string, errors: string[]): string[] {
  const result = stringArray(value, location, errors);
  if (Array.isArray(value) && result.length === 0) errors.push(`${location}: expected at least one token`);
  return result;
}

function parseArgvPredicate(value: unknown, location: string, errors: string[]): ArgvPredicate | undefined {
  if (value === undefined) return undefined;
  if (!isRecord(value)) {
    errors.push(`${location}: expected an object`);
    return undefined;
  }
  rejectUnknownKeys(value, ['empty', 'contains', 'containsAny', 'ordered', 'startsWithAny'], location, errors);
  if (value.empty !== undefined && typeof value.empty !== 'boolean') {
    errors.push(`${location}.empty: expected a boolean`);
  }
  const predicate: ArgvPredicate = {
    ...(typeof value.empty === 'boolean' ? { empty: value.empty } : {}),
    ...(value.contains !== undefined
      ? { contains: nonEmptyStringArray(value.contains, `${location}.contains`, errors) }
      : {}),
    ...(value.containsAny !== undefined
      ? { containsAny: nonEmptyStringArray(value.containsAny, `${location}.containsAny`, errors) }
      : {}),
    ...(value.ordered !== undefined
      ? { ordered: nonEmptyStringArray(value.ordered, `${location}.ordered`, errors) }
      : {}),
    ...(value.startsWithAny !== undefined
      ? { startsWithAny: nonEmptyStringArray(value.startsWithAny, `${location}.startsWithAny`, errors) }
      : {}),
  };
  if (Object.keys(predicate).length === 0) errors.push(`${location}: expected at least one argv predicate`);
  if (
    predicate.empty === true &&
    (predicate.contains?.length ||
      predicate.containsAny?.length ||
      predicate.ordered?.length ||
      predicate.startsWithAny?.length)
  ) {
    errors.push(`${location}: empty cannot be combined with token predicates`);
  }
  return predicate;
}

function parseShellRules(value: unknown, location: string, errors: string[]): ShellDenyRule[] {
  if (value === undefined) return [];
  if (!Array.isArray(value)) {
    errors.push(`${location}: expected an array`);
    return [];
  }
  const rules: ShellDenyRule[] = [];
  for (const [index, item] of value.entries()) {
    const ruleLocation = `${location}[${index}]`;
    if (!isRecord(item)) {
      errors.push(`${ruleLocation}: expected an object`);
      continue;
    }
    rejectUnknownKeys(item, ['command', 'argv', 'reason'], ruleLocation, errors);
    if (typeof item.command !== 'string' || !/^[A-Za-z0-9_.+-]+$/.test(item.command)) {
      errors.push(`${ruleLocation}.command: expected a literal executable basename`);
      continue;
    }
    if (item.reason !== undefined && (typeof item.reason !== 'string' || item.reason.length === 0)) {
      errors.push(`${ruleLocation}.reason: expected a non-empty string`);
    }
    rules.push({
      command: item.command,
      ...(item.argv !== undefined ? { argv: parseArgvPredicate(item.argv, `${ruleLocation}.argv`, errors) } : {}),
      ...(typeof item.reason === 'string' && item.reason.length > 0 ? { reason: item.reason } : {}),
    });
  }
  return rules;
}

export function validateConfig(value: unknown): { config: SafetyConfig; errors: string[] } {
  const errors: string[] = [];
  if (!isRecord(value)) return { config: EMPTY_CONFIG, errors: ['root: expected an object'] };
  rejectUnknownKeys(value, ['filesystem', 'shell'], 'root', errors);

  const filesystem = value.filesystem;
  if (filesystem !== undefined && !isRecord(filesystem)) errors.push('filesystem: expected an object');
  const filesystemRecord = isRecord(filesystem) ? filesystem : {};
  rejectUnknownKeys(filesystemRecord, ['denyRead', 'denyWrite'], 'filesystem', errors);

  const normalizePatterns = (raw: unknown, name: 'denyRead' | 'denyWrite') =>
    stringArray(raw, `filesystem.${name}`, errors)
      .map((pattern, index) => normalizePathPattern(pattern, `filesystem.${name}[${index}]`, errors))
      .filter((pattern): pattern is string => pattern !== undefined);

  const shell = value.shell;
  if (shell !== undefined && !isRecord(shell)) errors.push('shell: expected an object');
  const shellRecord = isRecord(shell) ? shell : {};
  rejectUnknownKeys(shellRecord, ['deny'], 'shell', errors);

  return {
    config: {
      filesystem: {
        denyRead: [...new Set(normalizePatterns(filesystemRecord.denyRead, 'denyRead'))],
        denyWrite: [...new Set(normalizePatterns(filesystemRecord.denyWrite, 'denyWrite'))],
      },
      shell: { deny: parseShellRules(shellRecord.deny, 'shell.deny', errors) },
    },
    errors,
  };
}

export function loadSafetyConfig(configPath = defaultConfigPath()): LoadedSafetyConfig {
  const defaults = builtInConfig(configPath);
  if (!existsSync(configPath)) {
    return { config: defaults, configPath, status: 'missing', errors: [`missing configuration: ${configPath}`] };
  }

  const parseErrors: ParseError[] = [];
  const parsed = parse(readFileSync(configPath, 'utf8'), parseErrors, {
    allowTrailingComma: true,
    disallowComments: false,
  }) as unknown;
  if (parseErrors.length > 0) {
    return {
      config: defaults,
      configPath,
      status: 'invalid',
      errors: parseErrors.map((error) => `${printParseErrorCode(error.error)} at offset ${error.offset}`),
    };
  }

  const validated = validateConfig(parsed);
  if (validated.errors.length > 0) {
    return { config: defaults, configPath, status: 'invalid', errors: validated.errors };
  }
  return {
    config: {
      filesystem: {
        denyRead: validated.config.filesystem.denyRead,
        denyWrite: [...new Set([...defaults.filesystem.denyWrite, ...validated.config.filesystem.denyWrite])],
      },
      shell: validated.config.shell,
    },
    configPath,
    status: 'loaded',
    errors: [],
  };
}

export function effectiveDenyWrite(config: SafetyConfig): string[] {
  return [...new Set([...config.filesystem.denyRead, ...config.filesystem.denyWrite])];
}

export function filesystemPolicyHash(config: SafetyConfig): string {
  const normalized = {
    denyRead: [...config.filesystem.denyRead].sort(),
    denyWrite: [...effectiveDenyWrite(config)].sort(),
  };
  return createHash('sha256').update(JSON.stringify(normalized)).digest('hex');
}
