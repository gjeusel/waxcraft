import assert from 'node:assert/strict';
import test from 'node:test';
import { checkBashCommand } from './index.ts';

// Only bypasses of the rm-to-trash PATH shim are blocked statically. Everything
// else (including plain rm and trash with any quoting) is validated at
// execution time by the shims in bin/.
const blockedCommands = [
  '/bin/rm file.txt',
  '/usr/bin/rm -rf build',
  'xargs /bin/rm',
  'find . -exec /bin/rm {} +',
  'bash -c "/bin/rm x"',
  'echo $(/bin/rm x)',
  'git rm tracked.txt',
  'git -C repo rm tracked.txt',
  'bash -c "git rm tracked.txt"',
  'find . -delete',
  'find build -name "*.o" -delete',
  'sudo rm x',
  'env -i rm x',
  'env PATH=/bin rm x',
  'PATH=/bin rm x',
  'export PATH=/bin; rm x',
  'git clean -fd',
  'git clean --force',
  'git reset --hard',
  'git reset --hard HEAD~1',
  'git checkout -- file.txt',
  'git checkout .',
  'git restore file.txt',
  'git restore --staged --worktree file.txt',
  'git stash drop',
  'git stash clear',
  'bash -c "git reset --hard"',
  'shred file.txt',
  'srm file.txt',
  'unlink file.txt',
  '/usr/bin/shred file.txt',
  'crontab -r',
  'rsync -av --delete src/ dst/',
  'dd if=disk.img of=/dev/disk2',
  'diskutil eraseDisk APFS Blank disk2',
  'mkfs.ext4 /dev/sda1',
  'newfs_apfs /dev/disk2',
  'tmutil deletelocalsnapshots /',
];

const allowedCommands = [
  'rm file.txt',
  'rm -rf build',
  "rm 'file with spaces.txt'",
  'rm -f *.pyc',
  'echo rm',
  'mv old new',
  'git mv old new',
  'git rm --cached file.txt',
  'trash file.txt',
  'trash "file with spaces.txt"',
  'trash ~/.ssh/id_ed25519',
  'cd /tmp && trash file',
  'bash -c "rm x"',
  'xargs rm',
  'find . -name "*.pyc" -exec rm {} +',
  'echo $(rm x)',
  'export PATH="/opt/tool/bin:$PATH"; rm x',
  'rmdir empty-dir',
  'git clean -n',
  'git checkout main',
  'git checkout -b feature',
  'git -C . checkout main',
  'git reset HEAD~1',
  'git reset --soft HEAD~1',
  'git restore --staged file.txt',
  'git stash',
  'git stash pop',
  'git stash push -m "drop old files"',
  'crontab -l',
  'crontab -e',
  'rsync -av src/ dst/',
  'dd if=/dev/zero of=disk.img bs=1m count=10',
  'diskutil list',
  'diskutil info disk2',
  'tmutil listlocalsnapshots /',
];

for (const command of blockedCommands) {
  test(`blocks: ${command}`, async () => {
    assert.ok(await checkBashCommand(command));
  });
}

for (const command of allowedCommands) {
  test(`allows: ${command}`, async () => {
    assert.equal(await checkBashCommand(command), undefined);
  });
}
