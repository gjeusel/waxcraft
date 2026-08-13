import { realpath } from 'node:fs/promises';
import { homedir } from 'node:os';
import { basename, dirname, isAbsolute, normalize, resolve } from 'node:path';
import { type ExtensionAPI, isToolCallEventType } from '@earendil-works/pi-coding-agent';

const SAFE_PREFIXES = ['/tmp', '/private/tmp', '/var/tmp', '/private/var/tmp', '/var/folders', '/private/var/folders'];

const SYSTEM_PREFIXES = [
  '/System',
  '/Library',
  '/Applications',
  '/usr',
  '/bin',
  '/sbin',
  '/etc',
  '/private/etc',
  '/opt',
  '/nix',
  '/Volumes',
];

const HOME_PROTECTED = ['.ssh', '.gnupg', '.aws', '.kube', '.config', '.claude'];
const CONTROL_PREFIXES = new Set(['if', 'then', 'elif', 'else', 'while', 'until', 'do', '!', 'time']);
const COMMAND_WRAPPERS = new Set(['command', 'builtin', 'exec', 'noglob', 'sudo']);
const GLOB_CHARACTER = /[*?[]/;

interface CommandInfo {
  executable: string;
  args: string[];
  wrapped: boolean;
}

function isUnder(path: string, prefix: string): boolean {
  return path === prefix || path.startsWith(`${prefix}/`);
}

function splitSegments(command: string): string[] {
  return command
    .replaceAll('$(', ';')
    .replaceAll('`', ';')
    .split(/&&|\|\||[;|&\n()]/)
    .map((segment) => segment.trim())
    .filter(Boolean);
}

function commandInfo(segment: string): CommandInfo | undefined {
  const words = segment.split(/\s+/).filter(Boolean);
  let index = 0;
  let wrapped = false;

  while (CONTROL_PREFIXES.has(words[index] ?? '')) index += 1;
  while (/^[A-Za-z_][A-Za-z0-9_]*=/.test(words[index] ?? '')) index += 1;

  while (COMMAND_WRAPPERS.has(basename(words[index] ?? ''))) {
    wrapped = true;
    index += 1;
    while (/^-/.test(words[index] ?? '')) index += 1;
  }

  if (basename(words[index] ?? '') === 'env') {
    wrapped = true;
    index += 1;
    while (/^-/.test(words[index] ?? '') || /^[A-Za-z_][A-Za-z0-9_]*=/.test(words[index] ?? '')) {
      index += 1;
    }
  }

  const executable = words[index];
  if (!executable) return undefined;
  return { executable: basename(executable), args: words.slice(index + 1), wrapped };
}

function judgePath(path: string, home: string): string | undefined {
  for (const prefix of SAFE_PREFIXES) {
    if (isUnder(path, prefix)) return undefined;
  }

  if (path === '/') return 'refusing to trash /';
  if (/^\/[^/]+$/.test(path)) return `refusing to trash top-level path ${path}`;

  for (const prefix of SYSTEM_PREFIXES) {
    if (isUnder(path, prefix)) return `refusing to trash system path ${path}`;
  }

  if (path === home) return 'refusing to trash the home directory';
  if (isUnder(path, home)) {
    const relative = path.slice(home.length + 1);
    if (!relative.includes('/')) return `refusing to trash top-level home path ~/${relative}`;
    for (const protectedName of HOME_PROTECTED) {
      if (isUnder(relative, protectedName)) {
        return `refusing to trash path under protected ~/${protectedName}`;
      }
    }
  }

  return undefined;
}

async function checkPath(rawPath: string, cwd: string, home: string): Promise<string | undefined> {
  let path = rawPath;
  if (path === '~' || path.startsWith('~/')) path = `${home}${path.slice(1)}`;
  else if (path.startsWith('~'))
    return `cannot resolve tilde expansion in '${rawPath}'; use ~ or a literal absolute path`;
  if (path === '$HOME' || path.startsWith('$HOME/')) path = `${home}${path.slice(5)}`;
  if (path.includes('$')) return `cannot resolve shell variable in '${rawPath}'; use a literal path`;
  if (path.split('/').includes('..')) return `refusing '..' path traversal in '${rawPath}'; use an absolute path`;

  const globIndex = path.search(GLOB_CHARACTER);
  if (globIndex >= 0) {
    path = path.slice(0, globIndex);
    if (!path.endsWith('/')) path = dirname(path);
  }

  path = normalize(isAbsolute(path) ? path : resolve(cwd, path || '.'));
  const lexicalError = judgePath(path, home);
  if (lexicalError) return lexicalError;

  try {
    const resolvedPath = await realpath(path);
    return judgePath(resolvedPath, home);
  } catch {
    return undefined;
  }
}

function gitSubcommand(args: string[]): string | undefined {
  const optionsWithValues = new Set([
    '-C',
    '-c',
    '--git-dir',
    '--work-tree',
    '--namespace',
    '--super-prefix',
    '--config-env',
  ]);
  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    if (argument === '--') return args[index + 1];
    if (optionsWithValues.has(argument)) {
      index += 1;
      continue;
    }
    if (!argument.startsWith('-')) return argument;
  }
  return undefined;
}

function nestedRemoval(info: CommandInfo): string | undefined {
  if (['bash', 'sh', 'zsh', 'fish'].includes(info.executable) && info.args.includes('-c')) {
    if (/(?:^|[^A-Za-z0-9_-])(rm|mv)(?=$|[^A-Za-z0-9_-])/.test(info.args.join(' '))) {
      return `${info.executable} -c cannot invoke rm or mv`;
    }
  }

  if (info.executable === 'xargs') {
    const executable = info.args.find((argument) => ['rm', 'mv'].includes(basename(argument)));
    if (executable) return `xargs ${basename(executable)} is disabled`;
  }

  if (info.executable === 'find') {
    for (let index = 0; index < info.args.length; index += 1) {
      if (info.args[index] === '-delete') return 'find -delete is disabled; use trash for deletions';
      if (['-exec', '-execdir', '-ok', '-okdir'].includes(info.args[index] ?? '')) {
        const executable = basename(info.args[index + 1] ?? '');
        if (executable === 'rm' || executable === 'mv') return `find ${info.args[index]} ${executable} is disabled`;
      }
    }
  }

  return undefined;
}

export async function checkBashCommand(command: string, cwd: string, home = homedir()): Promise<string | undefined> {
  const sensitiveWord = /(?:^|[^A-Za-z0-9_.-])(rm|mv|trash)(?=$|[^A-Za-z0-9_.-])/;
  if (/[\'"\\]/.test(command) && sensitiveWord.test(command)) {
    return 'quotes and escapes around rm, mv, or trash fail closed; use a simple direct trash command';
  }
  const complexSubshell = (command.includes('$(') || command.includes('`')) && sensitiveWord.test(command);
  if (complexSubshell) return 'rm, mv, and trash are not allowed inside command substitutions';

  let changedDirectory = false;
  for (const segment of splitSegments(command)) {
    const info = commandInfo(segment);
    if (!info) continue;

    if (info.executable === 'cd') {
      changedDirectory = true;
      continue;
    }
    if (info.executable === 'rm' || info.executable === 'mv') {
      return `${info.executable} is disabled; use trash for deletions`;
    }
    if (info.executable === 'git') {
      const subcommand = gitSubcommand(info.args);
      if (subcommand === 'rm' || subcommand === 'mv') return `git ${subcommand} is disabled; use trash for deletions`;
    }
    const nestedError = nestedRemoval(info);
    if (nestedError) return nestedError;
    if (info.executable !== 'trash') continue;
    if (changedDirectory) return 'trash must run in a separate Bash call after cd so its targets can be validated';
    if (info.wrapped) return 'invoke trash directly without command, env, sudo, or other wrappers';
    if (/[\'"\\{}]/.test(segment))
      return 'quotes, escapes, and braces in a trash command are not allowed; use simple unquoted paths';

    let options = true;
    for (const argument of info.args) {
      if (options && argument === '--') {
        options = false;
        continue;
      }
      if (options && argument.startsWith('-')) continue;
      const pathError = await checkPath(argument, cwd, home);
      if (pathError) return pathError;
    }
  }

  return undefined;
}

export default function (pi: ExtensionAPI) {
  pi.on('before_agent_start', (event) => ({
    systemPrompt: `${event.systemPrompt}\n\nFile deletion policy:\n- Never run rm, mv, git rm, or git mv.\n- Use trash <path> to delete files or directories; trash handles directories without -r.\n- For a rename or relocation, use file tools or copy the target and trash the original only when appropriate.`,
  }));

  pi.on('tool_call', async (event, ctx) => {
    if (!isToolCallEventType('bash', event)) return;
    const reason = await checkBashCommand(event.input.command, ctx.cwd);
    if (reason) return { block: true, reason: `safe-trash: ${reason}` };
  });
}
