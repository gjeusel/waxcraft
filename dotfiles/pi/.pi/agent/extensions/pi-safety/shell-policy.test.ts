import assert from 'node:assert/strict';
import test, { after } from 'node:test';
import type { ShellDenyRule } from './config.ts';
import { createBashParser, inspectBashCommand, type ShellDenialRule } from './shell-policy.ts';

const parser = await createBashParser();
after(() => parser.delete());

const configuredRules: ShellDenyRule[] = [
  { command: 'kubectl', argv: { containsAny: ['exec', 'apply', 'delete'] }, reason: 'kubectl denied' },
  {
    command: 'kubectl',
    argv: { contains: ['rollout'], containsAny: ['pause', 'restart', 'resume', 'undo'] },
    reason: 'kubectl rollout denied',
  },
  { command: 'sudo', reason: 'sudo denied' },
  { command: 'env', argv: { empty: true }, reason: 'environment listing denied' },
  { command: 'security', argv: { startsWithAny: ['find-', 'dump-', 'export'] }, reason: 'keychain denied' },
  {
    command: 'gws',
    argv: {
      contains: ['gmail'],
      containsAny: ['+send', '+reply', '+reply-all', '+forward', 'send', 'delete', 'batchDelete', 'trash'],
    },
    reason: 'Gmail sending or deletion denied',
  },
];

const blockedCommands: Array<[command: string, rule: ShellDenialRule]> = [
  ['/bin/rm file.txt', 'removal-path-bypass'],
  ['/usr/bin/rm -rf build', 'removal-path-bypass'],
  ['/bin/rmdir empty', 'removal-path-bypass'],
  ['xargs /usr/bin/rmdir', 'removal-path-bypass'],
  ['PATH=/bin rmdir empty', 'removal-environment-bypass'],
  ['xargs /bin/rm', 'removal-path-bypass'],
  [`xargs sh -c '/bin/rm "$1"' _`, 'removal-path-bypass'],
  ['find . -exec /bin/rm {} +', 'removal-path-bypass'],
  ['bash -c "/bin/rm x"', 'removal-path-bypass'],
  ['echo $(/bin/rm x)', 'removal-path-bypass'],
  ['git rm tracked.txt', 'git-rm'],
  ['git -C repo rm tracked.txt', 'git-rm'],
  ['bash -c "git rm tracked.txt"', 'git-rm'],
  ['find . -delete', 'find-delete'],
  ['env -i rm x', 'removal-environment-bypass'],
  ['env PATH=/bin rm x', 'removal-environment-bypass'],
  ['env -u PATH rm x', 'removal-environment-bypass'],
  ['env -uPATH rm x', 'removal-environment-bypass'],
  ['env -P/bin rm x', 'removal-environment-bypass'],
  ['PATH=/bin rm x', 'removal-environment-bypass'],
  ['export PATH=/bin; rm x', 'removal-environment-bypass'],
  ['PATH=/bin:$PATH rm x', 'removal-environment-bypass'],
  ['PATH=$PATHY:/bin rm x', 'removal-environment-bypass'],
  ['command -p rm x', 'removal-environment-bypass'],
  ['git clean -fd', 'git-clean'],
  ['git clean --force', 'git-clean'],
  ['env -uXS git clean -fd', 'git-clean'],
  ['git reset --hard', 'git-reset-hard'],
  ['git checkout -- file.txt', 'git-checkout-path'],
  ['git checkout .', 'git-checkout-path'],
  ['git restore file.txt', 'git-restore'],
  ['git restore --staged --worktree file.txt', 'git-restore'],
  ['git stash drop', 'git-stash-delete'],
  ['git stash clear', 'git-stash-delete'],
  ["git -c 'alias.d=!/bin/rm -rf .' d", 'git-shell-alias'],
  ["git config alias.d '!/bin/rm -rf .'", 'git-shell-alias'],
  ['git --config-env=alias.d=ENV d', 'git-shell-alias'],
  ['shred file.txt', 'permanent-delete'],
  ['srm file.txt', 'permanent-delete'],
  ['unlink file.txt', 'permanent-delete'],
  ['crontab -r', 'crontab-delete'],
  ['rsync -av --delete src/ dst/', 'rsync-delete'],
  ['rsync --del src/ dst/', 'rsync-delete'],
  ['rsync --remove-source-files src/ dst/', 'rsync-delete'],
  ['rsync --remove-sent-files src/ dst/', 'rsync-delete'],
  ['dd if=disk.img of=/dev/disk2', 'device-write'],
  ['diskutil eraseDisk APFS Blank disk2', 'diskutil-destructive'],
  ['diskutil apfs deleteContainer disk3', 'diskutil-destructive'],
  ['diskutil secureErase 0 disk2', 'diskutil-destructive'],
  ['mkfs.ext4 /dev/sda1', 'filesystem-create'],
  ['newfs_apfs /dev/disk2', 'filesystem-create'],
  ['tmutil deletelocalsnapshots /', 'tmutil-delete'],
  ['xargs kubectl delete pod doomed', 'configured'],
  ['xargs -n 1 kubectl delete pod doomed', 'configured'],
  ['xargs -J replacement kubectl delete pod doomed', 'configured'],
  ['xargs -R 2 kubectl delete pod doomed', 'configured'],
  ['timeout 10 kubectl delete pod doomed', 'configured'],
  ['nice -n 5 kubectl delete pod doomed', 'configured'],
  ['nohup nice kubectl delete pod doomed', 'configured'],
  ['caffeinate kubectl delete pod doomed', 'configured'],
  ['sudo echo ok', 'configured'],
  ['env', 'configured'],
  ['command kubectl exec pod -- sh', 'configured'],
  ['kubectl rollout restart deployment/pdf-tika', 'configured'],
  ['kubectl rollout undo deployment/pdf-tika', 'configured'],
  ["kubectl exec pod -- python - <<'PY'\nprint('ok')\nPY", 'configured'],
  ['security find-generic-password -a user', 'configured'],
  ['security dump-keychain', 'configured'],
  ['gws gmail +send --to recipient@example.com --subject Hello --body Hi', 'configured'],
  ['gws gmail +reply --message-id abc --body Hi', 'configured'],
  ['gws gmail +reply-all --message-id abc --body Hi', 'configured'],
  ['gws gmail +forward --message-id abc --to recipient@example.com', 'configured'],
  ['gws gmail users messages send --params userId=me', 'configured'],
  ['gws gmail users drafts send --params userId=me,id=abc', 'configured'],
  ['gws gmail users messages batchDelete --params userId=me', 'configured'],
  ['gws gmail users messages delete --params userId=me,id=abc', 'configured'],
  ['gws gmail users messages trash --params userId=me,id=abc', 'configured'],
  ['gws gmail users threads delete --params userId=me,id=abc', 'configured'],
  ['gws gmail users drafts delete --params userId=me,id=abc', 'configured'],
  ['eval /bin/rm x', 'removal-path-bypass'],
  ["bash <<'EOF'\n/bin/rm x\nEOF", 'removal-path-bypass'],
  ["bash <<< '/bin/rm x'", 'removal-path-bypass'],
  ["env -S '/bin/rm x'", 'removal-path-bypass'],
  ["env -vS'/bin/rm x'", 'removal-path-bypass'],
  [String.raw`kubectl ex\ec pod -- sh`, 'configured'],
  [String.raw`ku\bectl exec pod -- sh`, 'configured'],
  [String.raw`bash -c $'kubectl ex\x65c pod -- sh'`, 'configured'],
  ['eval "$SCRIPT"', 'dynamic-script'],
  ['bash -c "$SCRIPT"', 'dynamic-script'],
  ['env -S "$SCRIPT"', 'dynamic-script'],
  ["echo '/bin/rm x' | bash", 'dynamic-script'],
  ['bash evil.sh', 'dynamic-script'],
  ['bash evil.sh --version', 'dynamic-script'],
  ['bash -- -c script', 'dynamic-script'],
  ['sh < evil.sh', 'dynamic-script'],
  ["bash <(echo '/bin/rm x')", 'dynamic-script'],
  ['kubectl "$(echo exec)" pod', 'dynamic-arguments'],
  ['git reset "$mode"', 'dynamic-arguments'],
  ['git "$verb" tracked.txt', 'dynamic-arguments'],
  ['git config alias.d "$payload"', 'dynamic-arguments'],
  ['find . "$predicate"', 'dynamic-arguments'],
];

const allowedCommands = [
  'rm file.txt',
  'rm -rf build',
  "rm 'file with spaces.txt'",
  'rm -f *.pyc',
  'rmdir empty',
  'bash -c "rmdir empty"',
  'xargs rmdir',
  'echo rm',
  'mv old new',
  'git mv old new',
  'git rm --cached file.txt',
  'trash file.txt',
  'bash -c "rm x"',
  'xargs rm',
  'find . -name "*.pyc" -exec rm {} +',
  'echo $(rm x)',
  'export PATH="$PATH:/opt/tool/bin"; rm x',
  'git clean -n',
  'git checkout main',
  'git checkout -b feature',
  'git reset HEAD~1',
  'git reset --soft HEAD~1',
  'git restore --staged file.txt',
  'git restore -s HEAD --staged file.txt',
  'git stash',
  'git stash pop',
  'git stash push -m drop',
  'git stash -m drop',
  'crontab -l',
  'rsync -av src/ dst/',
  'rsync --delay-updates src/ dst/',
  'dd if=/dev/zero of=disk.img bs=1m count=10',
  'diskutil list',
  'diskutil apfs list',
  'tmutil listlocalsnapshots /',
  'git status',
  'git push origin main',
  'git push "$remote" main',
  'git -C "$directory" push origin main',
  'git -c alias.p=push p origin main',
  'git config alias.p push',
  'git commit -m "alias.p=push shortcut"',
  'git commit -m "$message"',
  'kubectl get pods',
  'kubectl rollout status deployment/pdf-tika --namespace default --timeout=3m',
  'kubectl rollout history deployment/pdf-tika',
  'env FOO=bar printenv FOO',
  'env echo PATH=/bin',
  'security help',
  'gws gmail users drafts create --params userId=me',
  'gws gmail users drafts update --params userId=me,id=abc',
  'gws gmail users drafts get --params userId=me,id=abc',
  'gws gmail users messages get --params userId=me,id=abc',
  'gws drive files delete --params fileId=abc',
  'find src/rm -type f',
  'timeout --preserve-status 5 git status',
  'command -v rm',
  'command -pv rm',
  'rm "$file"',
  'bash --version',
  'bash --version evil.sh',
  'env -uXS echo ok',
  '"$command" exec pod',
];

for (const [command, expectedRule] of blockedCommands) {
  test(`blocks [${expectedRule}]: ${command.split('\n')[0]}`, () => {
    const denial = inspectBashCommand(parser, command, configuredRules);
    assert.equal(denial?.rule, expectedRule, denial?.reason);
    assert.ok(denial?.reason);
  });
}

for (const command of allowedCommands) {
  test(`allows: ${command}`, () => {
    assert.equal(inspectBashCommand(parser, command, configuredRules), undefined);
  });
}

test('sudo path-like arguments do not look like a removal command', () => {
  assert.equal(inspectBashCommand(parser, 'sudo ls tools/rm', []), undefined);
});

test('sudo removal is blocked when no configured sudo rule masks the built-in reason', () => {
  assert.equal(inspectBashCommand(parser, 'sudo rm file.txt', [])?.rule, 'removal-environment-bypass');
});

test('fails closed at the nested-script depth limit', () => {
  const quote = (value: string) => `'${value.replaceAll("'", `'"'"'`)}'`;
  let command = 'echo ok';
  for (let depth = 0; depth < 5; depth += 1) command = `bash -c ${quote(command)}`;
  assert.equal(inspectBashCommand(parser, command, [])?.rule, 'nesting-limit');
});

test('fails closed at the command-wrapper depth limit', () => {
  const command = `${'nohup '.repeat(10)}echo ok`;
  assert.equal(inspectBashCommand(parser, command, [])?.rule, 'wrapper-limit');
});

test('blocks scripts with syntax errors instead of degrading to regex checks', () => {
  const denial = inspectBashCommand(parser, "echo 'unterminated", configuredRules);
  assert.equal(denial?.rule, 'parse-error');
  assert.match(denial?.reason ?? '', /could not parse/);
});
