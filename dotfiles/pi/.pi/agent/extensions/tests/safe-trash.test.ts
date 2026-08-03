import { mkdtemp, symlink } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import assert from 'node:assert/strict';
import test from 'node:test';
import { checkBashCommand } from '../safe-trash.ts';

const home = '/Users/test';
const cwd = '/Users/test/src/project';

const blockedCommands = [
  'rm file.txt',
  '/bin/rm -rf build',
  "'rm' file.txt",
  '"/bin/rm" file.txt',
  'command -- rm file.txt',
  '/usr/bin/env rm file.txt',
  'cd /tmp && mv old new',
  'git rm tracked.txt',
  'git mv old new',
  'git -C repo rm tracked.txt',
  'git -c user.name=test mv old new',
  'bash -c "rm file.txt"',
  'find . -exec rm {} +',
  'find . -delete',
  'xargs -n 1 rm',
  'trash /System/file.txt',
  'trash ~/.ssh/id_ed25519',
  'trash ~/.config/*.json',
  'trash ~/src',
  'trash ../project',
  'trash "$HOME/file.txt"',
  'trash $OTHER/file.txt',
  'trash ~-/file.txt',
  'trash ~root/file.txt',
  'trash {/Applications/MyApp.app,/tmp/x}',
  'command trash /tmp/file.txt',
  'cd / && trash Applications/MyApp.app',
  'echo $(rm file.txt)',
];

const allowedCommands = ['echo rm', 'trash /tmp/file.txt', 'trash ~/src/project/file.txt'];

for (const command of blockedCommands) {
  test(`blocks: ${command}`, async () => {
    assert.ok(await checkBashCommand(command, cwd, home));
  });
}

for (const command of allowedCommands) {
  test(`allows: ${command}`, async () => {
    assert.equal(await checkBashCommand(command, cwd, home), undefined);
  });
}

test('blocks a temp-path symlink resolving to a protected path', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'safe-trash-test-'));
  const link = join(directory, 'system-link');
  await symlink('/System', link);
  assert.ok(await checkBashCommand(`trash ${link}`, cwd, home));
});
