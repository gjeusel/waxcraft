import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const shimDirectory = join(dirname(fileURLToPath(import.meta.url)), 'bin');

interface Sandbox {
  root: string;
  home: string;
  logFile: string;
  env: NodeJS.ProcessEnv;
}

function makeSandbox(): Sandbox {
  const root = realpathSync(mkdtempSync(join(tmpdir(), 'safe-trash-test-')));
  const home = join(root, 'home');
  const fakeBin = join(root, 'fakebin');
  const logFile = join(root, 'trash.log');
  mkdirSync(home, { recursive: true });
  mkdirSync(fakeBin, { recursive: true });
  const fakeTrash = join(fakeBin, 'trash');
  writeFileSync(fakeTrash, `#!/bin/bash\nprintf '%s\\n' "$@" >> "$TRASH_LOG"\n`);
  chmodSync(fakeTrash, 0o755);
  return {
    root,
    home,
    logFile,
    env: {
      PATH: `${shimDirectory}:${fakeBin}:/usr/bin:/bin`,
      HOME: home,
      TRASH_LOG: logFile,
    },
  };
}

function run(sandbox: Sandbox, shim: 'rm' | 'rmdir' | 'trash', args: string[], cwd?: string) {
  const result = spawnSync(join(shimDirectory, shim), args, {
    cwd: cwd ?? sandbox.root,
    env: sandbox.env,
    encoding: 'utf8',
  });
  return { status: result.status, stderr: result.stderr };
}

function trashedPaths(sandbox: Sandbox): string[] {
  try {
    return readFileSync(sandbox.logFile, 'utf8').split('\n').filter(Boolean);
  } catch {
    return [];
  }
}

test('rm without -f fails on a missing file', () => {
  const sandbox = makeSandbox();
  const { status, stderr } = run(sandbox, 'rm', ['missing.txt']);
  assert.equal(status, 1);
  assert.match(stderr, /No such file or directory/);
  assert.deepEqual(trashedPaths(sandbox), []);
});

test('rm -f on a missing file succeeds silently', () => {
  const sandbox = makeSandbox();
  const { status, stderr } = run(sandbox, 'rm', ['-f', 'missing.txt']);
  assert.equal(status, 0);
  assert.equal(stderr, '');
});

test('rm -rf redirects an existing directory to trash', () => {
  const sandbox = makeSandbox();
  mkdirSync(join(sandbox.root, 'build'));
  const { status } = run(sandbox, 'rm', ['-rf', 'build']);
  assert.equal(status, 0);
  assert.deepEqual(trashedPaths(sandbox), ['build']);
});

test('rm handles paths with spaces from argv', () => {
  const sandbox = makeSandbox();
  writeFileSync(join(sandbox.root, 'a b.txt'), '');
  const { status } = run(sandbox, 'rm', ['a b.txt']);
  assert.equal(status, 0);
  assert.deepEqual(trashedPaths(sandbox), ['a b.txt']);
});

test('rm strips long options and passes only paths', () => {
  const sandbox = makeSandbox();
  writeFileSync(join(sandbox.root, 'file.txt'), '');
  const { status } = run(sandbox, 'rm', ['-v', '--recursive', 'file.txt']);
  assert.equal(status, 0);
  assert.deepEqual(trashedPaths(sandbox), ['file.txt']);
});

test('rm supports -- separator', () => {
  const sandbox = makeSandbox();
  writeFileSync(join(sandbox.root, 'file.txt'), '');
  const { status } = run(sandbox, 'rm', ['--', 'file.txt']);
  assert.equal(status, 0);
  assert.deepEqual(trashedPaths(sandbox), ['file.txt']);
});

test('rm mixes trashed and missing operands like rm does', () => {
  const sandbox = makeSandbox();
  writeFileSync(join(sandbox.root, 'present.txt'), '');
  const { status, stderr } = run(sandbox, 'rm', ['present.txt', 'absent.txt']);
  assert.equal(status, 1);
  assert.match(stderr, /absent\.txt/);
  assert.deepEqual(trashedPaths(sandbox), ['present.txt']);
});

test('trash refuses the home directory', () => {
  const sandbox = makeSandbox();
  const { status, stderr } = run(sandbox, 'trash', [sandbox.home]);
  assert.equal(status, 1);
  assert.match(stderr, /refusing to trash the home directory/);
});

test('trash refuses direct children of home', () => {
  const sandbox = makeSandbox();
  const { status, stderr } = run(sandbox, 'trash', [join(sandbox.home, 'Documents')]);
  assert.equal(status, 1);
  assert.match(stderr, /top-level home path/);
});

test('trash refuses protected home config directories', () => {
  const sandbox = makeSandbox();
  mkdirSync(join(sandbox.home, '.ssh'), { recursive: true });
  const { status, stderr } = run(sandbox, 'trash', [join(sandbox.home, '.ssh', 'id_ed25519')]);
  assert.equal(status, 1);
  assert.match(stderr, /protected ~\/\.ssh/);
});

test('trash refuses .. traversal into refused paths', () => {
  const sandbox = makeSandbox();
  const nested = join(sandbox.home, 'src', 'project');
  mkdirSync(nested, { recursive: true });
  const { status, stderr } = run(sandbox, 'trash', ['../../Documents'], nested);
  assert.equal(status, 1);
  assert.match(stderr, /top-level home path/);
});

test('trash allows nested home paths', () => {
  const sandbox = makeSandbox();
  mkdirSync(join(sandbox.home, 'src', 'project'), { recursive: true });
  const target = join(sandbox.home, 'src', 'project', 'file.txt');
  const { status } = run(sandbox, 'trash', [target]);
  assert.equal(status, 0);
  assert.deepEqual(trashedPaths(sandbox), [target]);
});

test('trash refuses / and system paths', () => {
  const sandbox = makeSandbox();
  assert.match(run(sandbox, 'trash', ['/']).stderr, /refusing to trash \//);
  assert.match(run(sandbox, 'trash', ['/System/foo']).stderr, /system path/);
  assert.match(run(sandbox, 'trash', ['/usr/local']).stderr, /system path/);
});

test('trash refuses top-level paths', () => {
  const sandbox = makeSandbox();
  const { status, stderr } = run(sandbox, 'trash', ['/data']);
  assert.equal(status, 1);
  assert.match(stderr, /top-level path/);
});

test('trash drops rm-style flags instead of failing', () => {
  const sandbox = makeSandbox();
  writeFileSync(join(sandbox.root, 'file.txt'), '');
  const { status } = run(sandbox, 'trash', ['-rf', 'file.txt']);
  assert.equal(status, 0);
  assert.deepEqual(trashedPaths(sandbox), ['file.txt']);
});

test('rm is shimmed through nested invocations (bash -c, find -exec, xargs)', () => {
  const sandbox = makeSandbox();
  const script = [
    'set -e',
    'touch a.txt b.pyc "c d.txt" f.txt',
    'rm a.txt',
    'bash -c \'rm "c d.txt"\'',
    "find . -name '*.pyc' -exec rm {} +",
    'printf "f.txt\\n" | xargs rm',
  ].join('\n');
  const result = spawnSync('/bin/bash', ['-c', script], { cwd: sandbox.root, env: sandbox.env, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  const logged = trashedPaths(sandbox);
  assert.ok(logged.includes('a.txt'));
  assert.ok(logged.includes('c d.txt'));
  assert.ok(logged.includes('f.txt'));
  assert.ok(logged.some((path) => path.endsWith('b.pyc')));
});

test('trash on a symlink targets the link, not its destination', () => {
  const sandbox = makeSandbox();
  const link = join(sandbox.root, 'system-link');
  symlinkSync('/System', link);
  const { status } = run(sandbox, 'trash', [link]);
  assert.equal(status, 0);
  assert.deepEqual(trashedPaths(sandbox), [link]);
});

test('rmdir redirects an empty directory to trash', () => {
  const sandbox = makeSandbox();
  mkdirSync(join(sandbox.root, 'empty'));
  const { status } = run(sandbox, 'rmdir', ['empty']);
  assert.equal(status, 0);
  assert.deepEqual(trashedPaths(sandbox), ['empty']);
});

test('rmdir retains the empty-directory requirement', () => {
  const sandbox = makeSandbox();
  mkdirSync(join(sandbox.root, 'nonempty'));
  writeFileSync(join(sandbox.root, 'nonempty', 'file.txt'), 'content');
  const { status, stderr } = run(sandbox, 'rmdir', ['nonempty']);
  assert.equal(status, 1);
  assert.match(stderr, /Directory not empty/);
  assert.deepEqual(trashedPaths(sandbox), []);
});

test('rmdir refuses --parents rather than deleting extra ancestors', () => {
  const sandbox = makeSandbox();
  mkdirSync(join(sandbox.root, 'parent', 'empty'), { recursive: true });
  const { status, stderr } = run(sandbox, 'rmdir', ['--parents', 'parent/empty']);
  assert.equal(status, 1);
  assert.match(stderr, /--parents is not supported/);
  assert.deepEqual(trashedPaths(sandbox), []);
});
