import { realpathSync } from 'node:fs';
import { createRequire } from 'node:module';
import { basename } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import type { Node, Parser } from 'web-tree-sitter';
import type { ArgvPredicate, ShellDenyRule } from './config.ts';

const extensionPath = realpathSync(fileURLToPath(import.meta.url));
const localRequire = createRequire(extensionPath);
const SCRIPT_EXECUTORS = new Set(['sh', 'bash', 'zsh', 'dash', 'ksh']);
const REMOVAL_COMMANDS = new Set(['rm', 'rmdir']);
const MAX_NESTING_DEPTH = 3;
const MAX_WRAPPER_DEPTH = 8;
const ENV_SPLIT_SHORT = /^-[iv0]*S(.*)$/;

export type ShellDenialRule =
  | 'parse-error'
  | 'nesting-limit'
  | 'wrapper-limit'
  | 'dynamic-script'
  | 'dynamic-arguments'
  | 'removal-path-bypass'
  | 'removal-environment-bypass'
  | 'git-rm'
  | 'git-clean'
  | 'git-reset-hard'
  | 'git-checkout-path'
  | 'git-restore'
  | 'git-stash-delete'
  | 'git-shell-alias'
  | 'find-delete'
  | 'permanent-delete'
  | 'crontab-delete'
  | 'rsync-delete'
  | 'device-write'
  | 'diskutil-destructive'
  | 'filesystem-create'
  | 'tmutil-delete'
  | 'configured';

export interface ShellDenial {
  rule: ShellDenialRule;
  reason: string;
}

function deny(rule: ShellDenialRule, reason: string): ShellDenial {
  return { rule, reason };
}

export async function createBashParser(): Promise<Parser> {
  const wasmPath = localRequire.resolve('tree-sitter-bash/tree-sitter-bash.wasm');
  const module = (await import(
    pathToFileURL(localRequire.resolve('web-tree-sitter')).href
  )) as typeof import('web-tree-sitter');
  await module.Parser.init();
  const language = await module.Language.load(wasmPath);
  const parser = new module.Parser();
  parser.setLanguage(language);
  return parser;
}

function decodeWord(value: string): string | undefined {
  if (value.includes('$')) return undefined;
  let decoded = '';
  for (let index = 0; index < value.length; index += 1) {
    const character = value[index];
    if (character !== '\\') {
      decoded += character;
      continue;
    }
    const escaped = value[index + 1];
    if (escaped === undefined) return undefined;
    index += 1;
    if (escaped !== '\n') decoded += escaped;
  }
  return decoded;
}

function decodeAnsiCString(value: string): string | undefined {
  if (!value.startsWith("$'") || !value.endsWith("'")) return undefined;
  const body = value.slice(2, -1);
  let decoded = '';
  const simpleEscapes: Record<string, string> = {
    a: '\x07',
    b: '\b',
    e: '\x1b',
    E: '\x1b',
    f: '\f',
    n: '\n',
    r: '\r',
    t: '\t',
    v: '\v',
    '\\': '\\',
    "'": "'",
    '"': '"',
  };

  for (let index = 0; index < body.length; index += 1) {
    const character = body[index];
    if (character !== '\\') {
      decoded += character;
      continue;
    }
    const escaped = body[index + 1];
    if (escaped === undefined) return undefined;
    index += 1;
    if (escaped in simpleEscapes) {
      decoded += simpleEscapes[escaped];
      continue;
    }
    if (escaped === '\n') continue;
    const hexadecimalLength = escaped === 'x' ? 2 : escaped === 'u' ? 4 : escaped === 'U' ? 8 : 0;
    if (hexadecimalLength > 0) {
      const digits = body.slice(index + 1, index + 1 + hexadecimalLength);
      if (!new RegExp(`^[0-9A-Fa-f]{${hexadecimalLength}}$`).test(digits)) return undefined;
      const codePoint = Number.parseInt(digits, 16);
      try {
        decoded += String.fromCodePoint(codePoint);
      } catch {
        return undefined;
      }
      index += hexadecimalLength;
      continue;
    }
    if (/[0-7]/.test(escaped)) {
      const remainder = body.slice(index + 1).match(/^[0-7]{0,2}/)?.[0] ?? '';
      decoded += String.fromCodePoint(Number.parseInt(escaped + remainder, 8));
      index += remainder.length;
      continue;
    }
    return undefined;
  }
  return decoded;
}

function literalText(node: Node | null): string | undefined {
  if (!node) return undefined;
  switch (node.type) {
    case 'command_name':
      return literalText(node.namedChildren[0] ?? null);
    case 'number':
      return node.text;
    case 'word':
      return node.namedChildCount === 0 ? decodeWord(node.text) : undefined;
    case 'ansi_c_string':
      return decodeAnsiCString(node.text);
    case 'raw_string':
      return node.text.slice(1, -1);
    case 'string': {
      const children = node.namedChildren;
      if (!children.every((child) => child.type === 'string_content')) return undefined;
      return children.map((child) => child.text).join('');
    }
    case 'concatenation': {
      const parts = node.namedChildren.map((child) => literalText(child));
      return parts.every((part) => part !== undefined) ? parts.join('') : undefined;
    }
    default:
      return undefined;
  }
}

function gitSubcommand(args: string[]): { name: string; rest: string[] } | undefined {
  const optionsWithValues = new Set(['-C', '-c', '--git-dir', '--work-tree', '--namespace', '--config-env']);
  const invocation = commandAfterOptions(args, optionsWithValues);
  return invocation ? { name: invocation.name, rest: invocation.args } : undefined;
}

function denialForGitCommand(args: string[]): ShellDenial | undefined {
  const subcommand = gitSubcommand(args);
  if (!subcommand) return undefined;
  const { name, rest } = subcommand;
  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    const inlineConfig =
      argument === '-c' ? args[index + 1] : argument.startsWith('-c') ? argument.slice(2) : undefined;
    if (inlineConfig && /^alias\.[^=]+=!/i.test(inlineConfig)) {
      return deny('git-shell-alias', 'Git shell aliases can bypass command inspection; use a non-shell Git alias');
    }
    if (/^--config-env=alias\./i.test(argument)) {
      return deny('git-shell-alias', 'dynamic Git aliases can bypass command inspection; use a non-shell Git alias');
    }
  }
  if (name === 'config') {
    const aliasKey = rest.findIndex((argument) => /^alias\.[^=]+$/i.test(argument));
    if (aliasKey >= 0 && rest[aliasKey + 1]?.startsWith('!')) {
      return deny('git-shell-alias', 'Git shell aliases can bypass command inspection; use a non-shell Git alias');
    }
  }
  if (name === 'rm' && !rest.includes('--cached')) {
    return deny(
      'git-rm',
      'git rm deletes permanently; use git rm --cached to unstage, or trash the file and git add -u',
    );
  }
  if (name === 'clean') {
    const force = rest.includes('--force') || rest.some((argument) => /^-[A-Za-z]*f/.test(argument));
    const dryRun = rest.includes('-n') || rest.includes('--dry-run');
    if (force && !dryRun)
      return deny('git-clean', 'git clean -f deletes untracked files permanently; preview with -n, then trash them');
  }
  if (name === 'reset' && rest.includes('--hard')) {
    return deny('git-reset-hard', 'git reset --hard discards uncommitted changes permanently; git stash them first');
  }
  if (name === 'checkout' && (rest.includes('--') || rest.includes('.'))) {
    return deny(
      'git-checkout-path',
      'git checkout with pathspecs overwrites uncommitted changes; git stash them first',
    );
  }
  if (name === 'restore') {
    const staged = rest.includes('--staged') || rest.some((argument) => /^-[A-Za-z]*S/.test(argument));
    const worktree = rest.includes('--worktree') || rest.some((argument) => /^-[A-Za-z]*W/.test(argument));
    if (worktree || !staged)
      return deny(
        'git-restore',
        'git restore overwrites uncommitted changes; git stash them first (git restore --staged is allowed)',
      );
  }
  const stashSubcommand =
    name === 'stash'
      ? commandAfterOptions(rest, new Set(['-m', '--message', '--pathspec-from-file']))?.name
      : undefined;
  if (stashSubcommand === 'drop' || stashSubcommand === 'clear') {
    return deny('git-stash-delete', 'git stash drop/clear discards stashed changes permanently');
  }
  return undefined;
}

function denialForDestructiveCommand(name: string, args: string[]): ShellDenial | undefined {
  const base = basename(name);
  if (REMOVAL_COMMANDS.has(base) && name !== base) {
    return deny(
      'removal-path-bypass',
      `'${name}' bypasses the ${base}-to-trash shim; use plain ${base} (transparently redirected to trash) or trash`,
    );
  }
  if (base === 'git') return denialForGitCommand(args);
  if (base === 'find' && args.includes('-delete')) {
    return deny('find-delete', 'find -delete deletes permanently; pipe the results to trash instead');
  }
  if (base === 'shred' || base === 'srm' || base === 'unlink') {
    return deny('permanent-delete', `${base} deletes permanently; use trash`);
  }
  if (base === 'crontab' && args.some((argument) => /^-[a-z]*r/.test(argument))) {
    return deny('crontab-delete', 'crontab -r wipes the crontab irreversibly; edit it with crontab -e instead');
  }
  if (
    base === 'rsync' &&
    args.some(
      (argument) =>
        argument === '--del' ||
        argument === '--delete' ||
        argument.startsWith('--delete-') ||
        argument === '--remove-source-files' ||
        argument === '--remove-sent-files',
    )
  ) {
    return deny(
      'rsync-delete',
      'rsync delete options remove destination files permanently; run without them or trash them',
    );
  }
  if (base === 'dd' && args.some((argument) => argument.startsWith('of=/dev/'))) {
    return deny('device-write', 'dd onto a device is destructive');
  }
  if (base === 'diskutil') {
    const verb = args[0]?.toLowerCase() ?? '';
    const apfsVerb = verb === 'apfs' ? (args[1]?.toLowerCase() ?? '') : '';
    if (
      verb.startsWith('erase') ||
      verb.startsWith('secureerase') ||
      verb === 'partitiondisk' ||
      verb === 'zerodisk' ||
      verb === 'reformat' ||
      apfsVerb.startsWith('delete') ||
      apfsVerb.startsWith('erase')
    ) {
      return deny('diskutil-destructive', 'diskutil erase/partition/delete operations are destructive');
    }
  }
  if (base.startsWith('mkfs') || base.startsWith('newfs')) {
    return deny('filesystem-create', 'creating a filesystem is destructive');
  }
  if (base === 'tmutil' && (args[0]?.toLowerCase() ?? '').startsWith('delete')) {
    return deny('tmutil-delete', 'tmutil delete removes Time Machine snapshots, the recovery of last resort');
  }
  return undefined;
}

function orderedSubsequence(args: string[], ordered: string[]): boolean {
  let index = 0;
  for (const argument of args) {
    if (argument === ordered[index]) index += 1;
    if (index === ordered.length) return true;
  }
  return ordered.length === 0;
}

function argvMatches(predicate: ArgvPredicate | undefined, args: string[], rawArgumentCount: number): boolean {
  if (!predicate) return true;
  if (predicate.empty !== undefined && (rawArgumentCount === 0) !== predicate.empty) return false;
  if (predicate.contains && !predicate.contains.every((token) => args.includes(token))) return false;
  if (predicate.containsAny && !predicate.containsAny.some((token) => args.includes(token))) return false;
  if (
    predicate.startsWithAny &&
    !args.some((argument) => predicate.startsWithAny?.some((prefix) => argument.startsWith(prefix)))
  ) {
    return false;
  }
  if (predicate.ordered && !orderedSubsequence(args, predicate.ordered)) return false;
  return true;
}

function denialForConfiguredRule(
  name: string,
  args: string[],
  rawArgumentCount: number,
  rules: ShellDenyRule[],
): ShellDenial | undefined {
  const base = basename(name);
  const rule = rules.find(
    (candidate) => candidate.command === base && argvMatches(candidate.argv, args, rawArgumentCount),
  );
  if (!rule) return undefined;
  return deny('configured', rule.reason ?? `command denied by pi-safety policy: ${base}`);
}

function literalGitSubcommand(args: Array<string | undefined>): { name?: string; dynamic: boolean } {
  const optionsWithValues = new Set(['-C', '-c', '--git-dir', '--work-tree', '--namespace', '--config-env']);
  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    if (argument === undefined) return { dynamic: true };
    if (argument === '--') {
      const name = args[index + 1];
      return name === undefined ? { dynamic: true } : { name, dynamic: false };
    }
    if (optionsWithValues.has(argument)) {
      if ((argument === '-c' || argument === '--config-env') && args[index + 1] === undefined) {
        return { dynamic: true };
      }
      index += 1;
      continue;
    }
    if (!argument.startsWith('-')) return { name: argument, dynamic: false };
  }
  return { dynamic: false };
}

function requiresLiteralArguments(invocation: Invocation, rules: ShellDenyRule[]): boolean {
  const base = basename(invocation.name);
  const configuredTokenRule = rules.some((rule) =>
    rule.command === base && rule.argv
      ? Boolean(rule.argv.contains || rule.argv.containsAny || rule.argv.ordered || rule.argv.startsWithAny)
      : false,
  );
  if (configuredTokenRule) return true;
  if (base === 'git') {
    const subcommand = literalGitSubcommand(invocation.literalArguments);
    return (
      subcommand.dynamic ||
      subcommand.name === undefined ||
      ['rm', 'clean', 'reset', 'checkout', 'restore', 'stash', 'config'].includes(subcommand.name)
    );
  }
  return ['find', 'rsync', 'dd', 'diskutil', 'tmutil', 'crontab'].includes(base);
}

interface Invocation {
  name: string;
  args: string[];
  literalArguments: Array<string | undefined>;
  rawArgumentCount: number;
  removalShimBypassed: boolean;
  literalComplete: boolean;
}

function commandAfterOptions(
  args: string[],
  optionsWithValues: ReadonlySet<string>,
  positionalValuesToSkip = 0,
): { name: string; args: string[] } | undefined {
  let remainingPositionals = positionalValuesToSkip;
  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    if (argument === '--') {
      const name = args[index + 1];
      return name === undefined ? undefined : { name, args: args.slice(index + 2) };
    }
    if (optionsWithValues.has(argument)) {
      index += 1;
      continue;
    }
    if (argument.startsWith('-')) continue;
    if (remainingPositionals > 0) {
      remainingPositionals -= 1;
      continue;
    }
    return { name: argument, args: args.slice(index + 1) };
  }
  return undefined;
}

function findExecutedCommand(args: string[]): { name: string; args: string[] } | undefined {
  const operatorIndex = args.findIndex((argument) => ['-exec', '-execdir', '-ok', '-okdir'].includes(argument));
  if (operatorIndex < 0 || args[operatorIndex + 1] === undefined) return undefined;
  return {
    name: args[operatorIndex + 1],
    args: args.slice(operatorIndex + 2).filter((argument) => ![';', '+'].includes(argument)),
  };
}

function envCommand(args: string[]): { name: string; args: string[]; bypassesRemovalShim: boolean } | undefined {
  const optionsWithValues = new Set(['-u', '--unset', '-C', '--chdir', '-P', '--path', '-a', '--argv0']);
  let bypassesRemovalShim = false;
  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    if (argument === '--') {
      const name = args[index + 1];
      return name === undefined ? undefined : { name, args: args.slice(index + 2), bypassesRemovalShim };
    }
    if (/^-uPATH$/.test(argument) || /^-P.+/.test(argument)) bypassesRemovalShim = true;
    if (/^-u.+/.test(argument) || /^-P.+/.test(argument)) continue;
    if ((argument === '-u' || argument === '--unset') && args[index + 1] === 'PATH') bypassesRemovalShim = true;
    if (argument === '--unset=PATH') bypassesRemovalShim = true;
    if (argument === '-i' || argument === '--ignore-environment') bypassesRemovalShim = true;
    if (argument === '-P' || argument === '--path' || argument.startsWith('--path=')) bypassesRemovalShim = true;
    if (optionsWithValues.has(argument)) {
      index += 1;
      continue;
    }
    if (/^PATH=/.test(argument)) bypassesRemovalShim = true;
    if (argument.startsWith('-') || /^[A-Za-z_][A-Za-z0-9_]*=/.test(argument)) continue;
    return { name: argument, args: args.slice(index + 1), bypassesRemovalShim };
  }
  return undefined;
}

function wrappedInvocation(invocation: Invocation): Invocation | undefined {
  const { name, args, removalShimBypassed } = invocation;
  const base = basename(name);
  let wrapped: { name: string; args: string[] } | undefined;
  let bypassesRemovalShim = removalShimBypassed;

  if (base === 'command') {
    if (args.some((argument) => /^-[^-]*[vV]/.test(argument))) return undefined;
    const index = args.findIndex((argument) => !argument.startsWith('-'));
    wrapped = index < 0 ? undefined : { name: args[index], args: args.slice(index + 1) };
    if (args.includes('-p')) bypassesRemovalShim = true;
  } else if (base === 'builtin' || base === 'nohup') {
    const index = args.findIndex((argument) => !argument.startsWith('-'));
    wrapped = index < 0 ? undefined : { name: args[index], args: args.slice(index + 1) };
  } else if (base === 'env') {
    if (
      args.some(
        (argument) =>
          ENV_SPLIT_SHORT.test(argument) || argument === '--split-string' || argument.startsWith('--split-string='),
      )
    ) {
      return undefined;
    }
    const envWrapped = envCommand(args);
    wrapped = envWrapped;
    if (envWrapped?.bypassesRemovalShim) bypassesRemovalShim = true;
  } else if (base === 'xargs') {
    wrapped = commandAfterOptions(
      args,
      new Set([
        '-E',
        '--eof',
        '-I',
        '--replace',
        '-L',
        '--max-lines',
        '-n',
        '--max-args',
        '-P',
        '--max-procs',
        '-s',
        '--max-chars',
        '-a',
        '--arg-file',
        '-d',
        '--delimiter',
        '--process-slot-var',
        '-J',
        '-R',
        '-S',
      ]),
    );
  } else if (base === 'timeout') {
    wrapped = commandAfterOptions(args, new Set(['-k', '--kill-after', '-s', '--signal']), 1);
  } else if (base === 'nice') {
    wrapped = commandAfterOptions(args, new Set(['-n', '--adjustment']));
  } else if (base === 'caffeinate') {
    wrapped = commandAfterOptions(args, new Set(['-t', '-w']));
  } else if (base === 'sudo') {
    wrapped = commandAfterOptions(args, new Set(['-C', '-D', '-g', '-h', '-p', '-R', '-r', '-t', '-u']));
    bypassesRemovalShim = true;
  } else if (base === 'doas') {
    wrapped = commandAfterOptions(args, new Set(['-a', '-C', '-u']));
    bypassesRemovalShim = true;
  } else if (base === 'find') {
    wrapped = findExecutedCommand(args);
  }

  if (!wrapped) return undefined;
  return {
    ...wrapped,
    literalArguments: wrapped.args,
    rawArgumentCount: wrapped.args.length,
    removalShimBypassed: bypassesRemovalShim,
    literalComplete: true,
  };
}

function unwrapInvocationChain(root: Invocation): { invocations: Invocation[]; exceeded: boolean } {
  const invocations = [root];
  let current = root;
  for (let depth = 0; depth < MAX_WRAPPER_DEPTH; depth += 1) {
    const wrapped = wrappedInvocation(current);
    if (!wrapped) return { invocations, exceeded: false };
    invocations.push(wrapped);
    current = wrapped;
  }
  return { invocations, exceeded: wrappedInvocation(current) !== undefined };
}

// A missing or dynamic assignment value is treated conservatively as replacing PATH.
function shadowsShim(assignedValue: string | undefined): boolean {
  if (assignedValue === undefined) return true;
  const unquoted = assignedValue.replace(/^(['"])(.*)\1$/, '$2');
  return !/^\$PATH(?:$|[^A-Za-z0-9_])/.test(unquoted) && !/^\$\{PATH\}/.test(unquoted);
}

interface ScriptCandidates {
  scripts: string[];
  dynamic: boolean;
}

function envSplitScript(invocation: Invocation): ScriptCandidates {
  const { args, literalComplete } = invocation;
  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    const shortSplit = argument.match(ENV_SPLIT_SHORT);
    if (shortSplit) {
      const script = shortSplit[1] || args[index + 1];
      return script === undefined || !literalComplete
        ? { scripts: [], dynamic: true }
        : { scripts: [script], dynamic: false };
    }
    if (argument === '--split-string') {
      const script = args[index + 1];
      return script === undefined || !literalComplete
        ? { scripts: [], dynamic: true }
        : { scripts: [script], dynamic: false };
    }
    if (argument.startsWith('--split-string=')) {
      return { scripts: [argument.slice('--split-string='.length)], dynamic: false };
    }
  }
  return { scripts: [], dynamic: false };
}

function shellMetadataOnly(args: string[]): boolean {
  for (const argument of args) {
    if (argument === '--help' || argument === '--version') return true;
    if (argument === '--' || !argument.startsWith('-')) return false;
  }
  return false;
}

function shellCommandFlagIndex(args: string[]): number {
  for (let index = 0; index < args.length; index += 1) {
    if (args[index] === '--') return -1;
    if (/^-[^-]*c/.test(args[index])) return index;
  }
  return -1;
}

function invocationScripts(invocation: Invocation): ScriptCandidates {
  const base = basename(invocation.name);
  if (base === 'eval') {
    return invocation.literalComplete
      ? { scripts: [invocation.args.join(' ')], dynamic: false }
      : { scripts: [], dynamic: true };
  }
  if (base === 'env') return envSplitScript(invocation);
  if (!SCRIPT_EXECUTORS.has(base)) return { scripts: [], dynamic: false };

  const commandFlag = shellCommandFlagIndex(invocation.args);
  if (commandFlag < 0) return { scripts: [], dynamic: false };
  const script = invocation.args[commandFlag + 1];
  return script === undefined || !invocation.literalComplete
    ? { scripts: [], dynamic: true }
    : { scripts: [script], dynamic: false };
}

function redirectedInputScripts(commandNode: Node): ScriptCandidates {
  const scope = commandNode.parent?.type === 'redirected_statement' ? commandNode.parent : commandNode;
  const scripts: string[] = [];
  let dynamic = false;
  const stack = [...scope.namedChildren];
  while (stack.length > 0) {
    const node = stack.pop();
    if (!node) continue;
    if (node.type === 'heredoc_body') {
      scripts.push(node.text);
      continue;
    }
    if (node.type === 'herestring_redirect') {
      const script = literalText(node.namedChildren[0] ?? null);
      if (script === undefined) dynamic = true;
      else scripts.push(script);
      continue;
    }
    stack.push(...node.namedChildren);
  }
  return { scripts, dynamic };
}

function inspectTree(parser: Parser, source: string, rules: ShellDenyRule[], depth: number): ShellDenial | undefined {
  const tree = parser.parse(source);
  if (!tree) return deny('parse-error', 'tree-sitter returned no syntax tree');
  try {
    if (tree.rootNode.hasError) return deny('parse-error', 'tree-sitter could not parse the Bash script reliably');

    let pathReplaced = false;
    let usesPlainRemoval = false;
    const nestedScripts: string[] = [];
    const stack: Node[] = [tree.rootNode];

    while (stack.length > 0) {
      const node = stack.pop();
      if (!node) continue;
      stack.push(...node.namedChildren);

      if (node.type === 'variable_assignment') {
        const variable = node.childForFieldName('name')?.text;
        if (variable === 'PATH' && shadowsShim(node.childForFieldName('value')?.text)) pathReplaced = true;
        continue;
      }
      if (node.type !== 'command') continue;

      const name = literalText(node.childForFieldName('name'));
      if (!name) continue;
      const argumentNodes = node.childrenForFieldName('argument');
      const literalArguments = argumentNodes.map((argument) => literalText(argument));
      const args = literalArguments.filter((argument): argument is string => argument !== undefined);
      const rootInvocation: Invocation = {
        name,
        args,
        literalArguments,
        rawArgumentCount: argumentNodes.length,
        removalShimBypassed: false,
        literalComplete: literalArguments.every((argument) => argument !== undefined),
      };
      const chain = rootInvocation.literalComplete
        ? unwrapInvocationChain(rootInvocation)
        : { invocations: [rootInvocation], exceeded: false };
      if (chain.exceeded) return deny('wrapper-limit', 'command wrapper nesting exceeds the inspection limit');

      for (const invocation of chain.invocations) {
        const destructive = denialForDestructiveCommand(invocation.name, invocation.args);
        if (destructive) return destructive;
        const configured = denialForConfiguredRule(
          invocation.name,
          invocation.args,
          invocation.rawArgumentCount,
          rules,
        );
        if (configured) return configured;
        if (!invocation.literalComplete && requiresLiteralArguments(invocation, rules)) {
          return deny('dynamic-arguments', `${basename(invocation.name)} arguments cannot be inspected literally`);
        }

        const base = basename(invocation.name);
        if (REMOVAL_COMMANDS.has(base) && invocation.name === base) {
          if (invocation.removalShimBypassed) {
            return deny(
              'removal-environment-bypass',
              'the command wrapper bypasses the rm/rmdir-to-trash shims; use plain rm, rmdir, or trash',
            );
          }
          usesPlainRemoval = true;
        }

        const candidates = invocationScripts(invocation);
        if (candidates.dynamic) {
          return deny('dynamic-script', `${base} would execute a script that cannot be inspected literally`);
        }
        nestedScripts.push(...candidates.scripts);
      }

      const shellInvocations = chain.invocations.filter((invocation) =>
        SCRIPT_EXECUTORS.has(basename(invocation.name)),
      );
      if (shellInvocations.length > 0) {
        const redirected = redirectedInputScripts(node);
        if (redirected.dynamic) {
          return deny('dynamic-script', 'shell input redirection cannot be inspected literally');
        }
        const needsLiteralInput = shellInvocations.some(
          (invocation) => shellCommandFlagIndex(invocation.args) < 0 && !shellMetadataOnly(invocation.args),
        );
        if (needsLiteralInput && redirected.scripts.length === 0) {
          return deny('dynamic-script', 'shell input or script file cannot be inspected literally');
        }
        nestedScripts.push(...redirected.scripts);
      }
    }

    if (pathReplaced && usesPlainRemoval) {
      return deny(
        'removal-environment-bypass',
        'prepending or replacing PATH can shadow the rm/rmdir-to-trash shims; keep $PATH first or use trash',
      );
    }
    if (nestedScripts.length > 0 && depth >= MAX_NESTING_DEPTH) {
      return deny('nesting-limit', 'nested shell script depth exceeds the inspection limit');
    }
    for (const script of nestedScripts) {
      const denial = inspectTree(parser, script, rules, depth + 1);
      if (denial) return denial;
    }
    return undefined;
  } finally {
    tree.delete();
  }
}

export function inspectBashCommand(parser: Parser, source: string, rules: ShellDenyRule[]): ShellDenial | undefined {
  return inspectTree(parser, source, rules, 0);
}
