import { existsSync, readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { parse, printParseErrorCode, type ParseError } from 'jsonc-parser';
import { AUTO_MODE_SOURCES, DEFAULT_AUTO_MODE_SOURCE, DEFAULT_MIN_CONFIDENCE, type AutoModeSource } from './auto-mode.ts';
import { isAnchoredPattern, type PathRules } from './path-policy.ts';

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
  /** Require confirmation instead of denying while auto mode is enabled. */
  autoMode?: 'ask';
}

export interface AutoModeConfig {
  enabled: boolean;
  source: AutoModeSource;
  /** Verdicts below this confidence (0–1) require confirmation; 0 disables confidence-only prompts. */
  minConfidence: number;
}

export interface SafetyConfig {
  shell: {
    deny: ShellDenyRule[];
  };
  /** Path globs guarding the write and edit tools. */
  paths: PathRules;
  autoMode: AutoModeConfig;
}

export interface LoadedSafetyConfig {
  config: SafetyConfig;
  configPath: string;
  status: 'loaded' | 'missing' | 'invalid';
  errors: string[];
}

const DEFAULT_AUTO_MODE: AutoModeConfig = {
  enabled: true,
  source: DEFAULT_AUTO_MODE_SOURCE,
  minConfidence: DEFAULT_MIN_CONFIDENCE,
};
const EMPTY_CONFIG: SafetyConfig = { shell: { deny: [] }, paths: { deny: [], ask: [] }, autoMode: DEFAULT_AUTO_MODE };

function agentDirectory(): string {
  return process.env.PI_CODING_AGENT_DIR || join(homedir(), '.pi', 'agent');
}

export function defaultConfigPath(): string {
  return join(agentDirectory(), 'pi-safety.jsonc');
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
  if (!Array.isArray(value)) {
    errors.push(`${location}: expected an array of strings`);
    return [];
  }
  const result: string[] = [];
  for (const [index, item] of value.entries()) {
    if (typeof item !== 'string' || item.length === 0)
      errors.push(`${location}[${index}]: expected a non-empty string`);
    else result.push(item);
  }
  return result;
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
  if (value.empty !== undefined && typeof value.empty !== 'boolean')
    errors.push(`${location}.empty: expected a boolean`);
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
    rejectUnknownKeys(item, ['command', 'argv', 'reason', 'autoMode'], ruleLocation, errors);
    if (typeof item.command !== 'string' || !/^[A-Za-z0-9_.+-]+$/.test(item.command)) {
      errors.push(`${ruleLocation}.command: expected a literal executable basename`);
      continue;
    }
    if (item.reason !== undefined && (typeof item.reason !== 'string' || item.reason.length === 0)) {
      errors.push(`${ruleLocation}.reason: expected a non-empty string`);
    }
    if (item.autoMode !== undefined && item.autoMode !== 'ask') {
      errors.push(`${ruleLocation}.autoMode: expected "ask"`);
    }
    rules.push({
      command: item.command,
      ...(item.argv !== undefined ? { argv: parseArgvPredicate(item.argv, `${ruleLocation}.argv`, errors) } : {}),
      ...(typeof item.reason === 'string' && item.reason.length > 0 ? { reason: item.reason } : {}),
      ...(item.autoMode === 'ask' ? { autoMode: 'ask' as const } : {}),
    });
  }
  return rules;
}

function parsePathPatterns(value: unknown, location: string, errors: string[]): string[] {
  if (value === undefined) return [];

  const patterns = stringArray(value, location, errors);
  for (const [index, pattern] of patterns.entries()) {
    if (!isAnchoredPattern(pattern)) {
      errors.push(`${location}[${index}]: expected a pattern starting with /, ~/, or **/`);
    }
  }
  return patterns;
}

function parsePaths(value: unknown, location: string, errors: string[]): PathRules {
  if (value === undefined) return { deny: [], ask: [] };
  if (!isRecord(value)) {
    errors.push(`${location}: expected an object`);
    return { deny: [], ask: [] };
  }

  rejectUnknownKeys(value, ['deny', 'ask'], location, errors);
  return {
    deny: parsePathPatterns(value.deny, `${location}.deny`, errors),
    ask: parsePathPatterns(value.ask, `${location}.ask`, errors),
  };
}

function parseAutoMode(value: unknown, location: string, errors: string[]): AutoModeConfig {
  if (value === undefined) return DEFAULT_AUTO_MODE;
  if (!isRecord(value)) {
    errors.push(`${location}: expected an object`);
    return DEFAULT_AUTO_MODE;
  }
  rejectUnknownKeys(value, ['enabled', 'source', 'minConfidence'], location, errors);
  const result = { ...DEFAULT_AUTO_MODE };
  if (value.enabled !== undefined) {
    if (typeof value.enabled === 'boolean') result.enabled = value.enabled;
    else errors.push(`${location}.enabled: expected a boolean`);
  }
  if (value.source !== undefined) {
    if (typeof value.source === 'string' && (AUTO_MODE_SOURCES as readonly string[]).includes(value.source)) {
      result.source = value.source as AutoModeSource;
    } else {
      errors.push(`${location}.source: expected one of ${AUTO_MODE_SOURCES.join(', ')}`);
    }
  }
  if (value.minConfidence !== undefined) {
    if (typeof value.minConfidence === 'number' && value.minConfidence >= 0 && value.minConfidence <= 1) {
      result.minConfidence = value.minConfidence;
    } else {
      errors.push(`${location}.minConfidence: expected a number between 0 and 1`);
    }
  }

  return result;
}

export function validateConfig(value: unknown): { config: SafetyConfig; errors: string[] } {
  const errors: string[] = [];
  if (!isRecord(value)) return { config: EMPTY_CONFIG, errors: ['root: expected an object'] };
  rejectUnknownKeys(value, ['shell', 'paths', 'autoMode'], 'root', errors);
  const shell = value.shell;
  if (shell !== undefined && !isRecord(shell)) errors.push('shell: expected an object');
  const shellRecord = isRecord(shell) ? shell : {};
  rejectUnknownKeys(shellRecord, ['deny'], 'shell', errors);
  return {
    config: {
      shell: { deny: parseShellRules(shellRecord.deny, 'shell.deny', errors) },
      paths: parsePaths(value.paths, 'paths', errors),
      autoMode: parseAutoMode(value.autoMode, 'autoMode', errors),
    },
    errors,
  };
}

export function loadSafetyConfig(configPath = defaultConfigPath()): LoadedSafetyConfig {
  if (!existsSync(configPath)) {
    return { config: EMPTY_CONFIG, configPath, status: 'missing', errors: [`missing configuration: ${configPath}`] };
  }
  const parseErrors: ParseError[] = [];
  const parsed = parse(readFileSync(configPath, 'utf8'), parseErrors, {
    allowTrailingComma: true,
    disallowComments: false,
  }) as unknown;
  if (parseErrors.length > 0) {
    return {
      config: EMPTY_CONFIG,
      configPath,
      status: 'invalid',
      errors: parseErrors.map((error) => `${printParseErrorCode(error.error)} at offset ${error.offset}`),
    };
  }
  const validated = validateConfig(parsed);
  if (validated.errors.length > 0)
    return { config: EMPTY_CONFIG, configPath, status: 'invalid', errors: validated.errors };
  return { config: validated.config, configPath, status: 'loaded', errors: [] };
}
