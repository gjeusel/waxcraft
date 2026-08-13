import { chmodSync, realpathSync } from 'node:fs';
import { createRequire } from 'node:module';
import { basename, delimiter, dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { type ExtensionAPI, isToolCallEventType } from '@earendil-works/pi-coding-agent';
import type { Node, Parser } from 'web-tree-sitter';

const extensionPath = realpathSync(fileURLToPath(import.meta.url));
const extensionDirectory = dirname(extensionPath);
const shimDirectory = join(extensionDirectory, 'bin');
const localRequire = createRequire(extensionPath);

const SHELLS = new Set(['sh', 'bash', 'zsh', 'dash', 'ksh', 'eval']);
const MAX_NESTING_DEPTH = 3;

let parserPromise: Promise<Parser | undefined> | undefined;

function loadParser(): Promise<Parser | undefined> {
  parserPromise ??= (async () => {
    const wasmPath = localRequire.resolve('tree-sitter-bash/tree-sitter-bash.wasm');
    const module = (await import(
      pathToFileURL(localRequire.resolve('web-tree-sitter')).href
    )) as typeof import('web-tree-sitter');
    await module.Parser.init();
    const language = await module.Language.load(wasmPath);
    const parser = new module.Parser();
    parser.setLanguage(language);
    return parser;
  })().catch(() => undefined);
  return parserPromise;
}

// The final component being a literal token ending in /rm catches every form
// of path-invoked rm (/bin/rm, xargs /bin/rm, bash -c "/bin/rm x", ...) that
// would bypass the PATH shim. Plain `rm` is fine: the shim redirects it.
function pathInvokedRm(command: string): string | undefined {
  for (const token of command.split(/[\s;|&()<>'"`]+/)) {
    if (token.endsWith('/rm')) {
      return `'${token}' bypasses the rm-to-trash shim; use plain rm (transparently redirected to trash) or trash`;
    }
  }
  return undefined;
}

function literalText(node: Node | null): string | undefined {
  if (!node) return undefined;
  switch (node.type) {
    case 'command_name':
      return literalText(node.namedChildren[0] ?? null);
    case 'word':
      return node.text.includes('$') ? undefined : node.text;
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
  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    if (argument === '--') {
      const name = args[index + 1];
      return name === undefined ? undefined : { name, rest: args.slice(index + 2) };
    }
    if (optionsWithValues.has(argument)) {
      index += 1;
      continue;
    }
    if (!argument.startsWith('-')) return { name: argument, rest: args.slice(index + 1) };
  }
  return undefined;
}

function checkGitCommand(args: string[]): string | undefined {
  const subcommand = gitSubcommand(args);
  if (!subcommand) return undefined;
  const { name, rest } = subcommand;
  if (name === 'rm' && !rest.includes('--cached')) {
    return 'git rm deletes permanently; use git rm --cached to unstage, or trash the file and git add -u';
  }
  if (name === 'clean') {
    const force = rest.includes('--force') || rest.some((argument) => /^-[A-Za-z]*f/.test(argument));
    const dryRun = rest.includes('-n') || rest.includes('--dry-run');
    if (force && !dryRun) return 'git clean -f deletes untracked files permanently; preview with -n, then trash them';
  }
  if (name === 'reset' && rest.includes('--hard')) {
    return 'git reset --hard discards uncommitted changes permanently; git stash them first';
  }
  if (name === 'checkout' && (rest.includes('--') || rest.includes('.'))) {
    return 'git checkout with pathspecs overwrites uncommitted changes; git stash them first';
  }
  if (name === 'restore') {
    const staged = rest.includes('--staged') || rest.some((argument) => /^-[A-Za-z]*S/.test(argument));
    const worktree = rest.includes('--worktree') || rest.some((argument) => /^-[A-Za-z]*W/.test(argument));
    if (worktree || !staged) return 'git restore overwrites uncommitted changes; git stash them first (git restore --staged is allowed)';
  }
  if (name === 'stash' && (rest.includes('drop') || rest.includes('clear'))) {
    return 'git stash drop/clear discards stashed changes permanently';
  }
  return undefined;
}

function replacesPath(assignedValue: string | undefined): boolean {
  return assignedValue !== undefined && !assignedValue.includes('$PATH') && !assignedValue.includes('${PATH');
}

function checkCommandNode(name: string, args: string[]): string | undefined {
  const base = basename(name);
  if (base === 'git') return checkGitCommand(args);
  if (base === 'find' && args.includes('-delete')) {
    return 'find -delete deletes permanently; pipe the results to trash instead';
  }
  if ((base === 'sudo' || base === 'doas') && args.some((argument) => argument === 'rm')) {
    return `${base} rm bypasses the rm-to-trash shim; use trash`;
  }
  if (base === 'env' && args.includes('rm')) {
    if (args.includes('-i') || args.some((argument) => argument.startsWith('PATH='))) {
      return 'env with a replaced environment bypasses the rm-to-trash shim; use plain rm or trash';
    }
  }
  if (base === 'shred' || base === 'srm' || base === 'unlink') {
    return `${base} deletes permanently; use trash`;
  }
  if (base === 'crontab' && args.some((argument) => /^-[a-z]*r/.test(argument))) {
    return 'crontab -r wipes the crontab irreversibly; edit it with crontab -e instead';
  }
  if (base === 'rsync' && args.some((argument) => argument.startsWith('--delete'))) {
    return 'rsync --delete removes destination files permanently; run without it or trash them';
  }
  if (base === 'dd' && args.some((argument) => argument.startsWith('of=/dev/'))) {
    return 'dd onto a device is destructive';
  }
  if (base === 'diskutil') {
    const verb = args[0]?.toLowerCase() ?? '';
    if (verb.startsWith('erase') || verb === 'partitiondisk' || verb === 'zerodisk' || verb === 'reformat') {
      return 'diskutil erase/partition operations are destructive';
    }
  }
  if (base.startsWith('mkfs') || base.startsWith('newfs')) {
    return 'creating a filesystem is destructive';
  }
  if (base === 'tmutil' && (args[0]?.toLowerCase() ?? '').startsWith('delete')) {
    return 'tmutil delete removes Time Machine snapshots, the recovery of last resort';
  }
  return undefined;
}

function checkWithParser(parser: Parser, source: string, depth: number): string | undefined {
  const tree = parser.parse(source);
  if (!tree) return undefined;
  try {
    let pathReplaced = false;
    let usesPlainRm = false;
    const nestedScripts: string[] = [];
    const stack: Node[] = [tree.rootNode];

    while (stack.length > 0) {
      const node = stack.pop();
      if (!node) continue;
      stack.push(...node.namedChildren);

      if (node.type === 'variable_assignment') {
        const variable = node.childForFieldName('name')?.text;
        if (variable === 'PATH' && replacesPath(node.childForFieldName('value')?.text)) pathReplaced = true;
        continue;
      }
      if (node.type !== 'command') continue;

      const name = literalText(node.childForFieldName('name'));
      if (!name) continue;
      const argumentNodes = node.childrenForFieldName('argument');
      const args = argumentNodes
        .map((argument) => literalText(argument))
        .filter((argument): argument is string => argument !== undefined);

      if (name === 'rm') usesPlainRm = true;
      const reason = checkCommandNode(name, args);
      if (reason) return reason;

      if (SHELLS.has(name) && depth < MAX_NESTING_DEPTH) {
        for (const argument of argumentNodes) {
          if (argument.type !== 'string' && argument.type !== 'raw_string') continue;
          const script = literalText(argument);
          if (script) nestedScripts.push(script);
        }
      }
    }

    if (pathReplaced && usesPlainRm) {
      return 'replacing PATH disables the rm-to-trash shim; keep $PATH in the assignment or use trash';
    }
    for (const script of nestedScripts) {
      const reason = checkWithParser(parser, script, depth + 1);
      if (reason) return reason;
    }
    return undefined;
  } finally {
    tree.delete();
  }
}

// Regex fallback for when the parser packages are not installed. Coarser than
// the parser (may over-block), but the shim remains the primary defense.
function fallbackCheck(command: string): string | undefined {
  if (/(^|[\s;|&`(])git\s[^;|&\n]*\brm\b/.test(command) && !command.includes('--cached')) {
    return 'git rm deletes permanently; use git rm --cached to unstage, or trash the file and git add -u';
  }
  if (/(^|[\s;|&`(])(shred|srm|unlink)\s/.test(command)) {
    return 'shred, srm, and unlink delete permanently; use trash';
  }
  if (/(^|[\s;|&`(])git\s[^;|&\n]*\bclean\b[^;|&\n]*\s-[A-Za-z]*f/.test(command) && !/-n|--dry-run/.test(command)) {
    return 'git clean -f deletes untracked files permanently; preview with -n, then trash them';
  }
  if (/(^|[\s;|&`(])git\s[^;|&\n]*\breset\b[^;|&\n]*--hard/.test(command)) {
    return 'git reset --hard discards uncommitted changes permanently; git stash them first';
  }
  if (/(^|[\s;|&`(])crontab\s[^;|&\n]*-[a-z]*r/.test(command)) {
    return 'crontab -r wipes the crontab irreversibly; edit it with crontab -e instead';
  }
  if (/(^|[\s;|&`(])rsync\s[^;|&\n]*--delete/.test(command)) {
    return 'rsync --delete removes destination files permanently; run without it or trash them';
  }
  if (/(^|[\s;|&`(])find\s[^;|&\n]*\s-delete\b/.test(command)) {
    return 'find -delete deletes permanently; pipe the results to trash instead';
  }
  if (/(^|[\s;|&`(])(sudo|doas)\s[^;|&\n]*\brm\b/.test(command)) {
    return 'sudo rm bypasses the rm-to-trash shim; use trash';
  }
  if (/(^|[\s;|&`(])(env\s[^;|&\n]*)?\bPATH=/.test(command) && !/\$\{?PATH\b/.test(command) && /\brm\b/.test(command)) {
    return 'replacing PATH disables the rm-to-trash shim; keep $PATH in the assignment or use trash';
  }
  if (/(^|[\s;|&`(])env\s[^;|&\n]*\s-i\s[^;|&\n]*\brm\b/.test(command)) {
    return 'env -i bypasses the rm-to-trash shim; use plain rm or trash';
  }
  return undefined;
}

export async function checkBashCommand(command: string): Promise<string | undefined> {
  const direct = pathInvokedRm(command);
  if (direct) return direct;
  const parser = await loadParser();
  if (!parser) return fallbackCheck(command);
  try {
    return checkWithParser(parser, command, 0);
  } catch {
    return fallbackCheck(command);
  }
}

export function ensureShims(): void {
  for (const name of ['rm', 'trash']) {
    try {
      chmodSync(join(shimDirectory, name), 0o755);
    } catch {
      // Shim missing: the PATH entry is then inert and the parser checks remain.
    }
  }
  const pathKey = Object.keys(process.env).find((key) => key.toLowerCase() === 'path') ?? 'PATH';
  const entries = (process.env[pathKey] ?? '').split(delimiter).filter(Boolean);
  if (!entries.includes(shimDirectory)) {
    // pi's bash tool builds its child environment from process.env, so this
    // single in-process mutation routes every spawned command through the shims.
    process.env[pathKey] = [shimDirectory, ...entries].join(delimiter);
  }
}

function findMissingRuntimePackage(): string | undefined {
  for (const specifier of ['web-tree-sitter', 'tree-sitter-bash/tree-sitter-bash.wasm']) {
    try {
      localRequire.resolve(specifier);
    } catch {
      return specifier;
    }
  }
  return undefined;
}

export default function (pi: ExtensionAPI) {
  ensureShims();

  const missing = findMissingRuntimePackage();
  if (missing) {
    const message =
      `safe-trash: package "${missing}" is not installed; falling back to coarser regex checks. ` +
      `Run "npm install" in ${extensionDirectory}.`;
    pi.on('session_start', (_event, ctx) => {
      if (ctx.hasUI) ctx.ui.notify(message, 'warning');
      else console.warn(`Warning: ${message}`);
    });
  }

  pi.on('before_agent_start', (event) => ({
    systemPrompt: `${event.systemPrompt}\n\nFile deletion: rm and trash both move targets to the macOS Trash (recoverable); use them normally.`,
  }));

  pi.on('tool_call', async (event) => {
    if (!isToolCallEventType('bash', event)) return;
    const reason = await checkBashCommand(event.input.command);
    if (reason) return { block: true, reason: `safe-trash: ${reason}` };
  });
}
