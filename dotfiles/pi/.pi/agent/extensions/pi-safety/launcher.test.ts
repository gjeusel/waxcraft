import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, realpathSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const extensionDirectory = dirname(fileURLToPath(import.meta.url));
const agentDirectory = resolve(extensionDirectory, '../..');
const wrapper = resolve(extensionDirectory, '../../../../.local/bin/pi');
const canApplySeatbelt = process.platform === 'darwin' && process.env.PI_SAFETY_SANDBOXED !== '1';

function launch(configPath: string, script: string, args: string[] = [], envOverrides: NodeJS.ProcessEnv = {}) {
  const env = { ...process.env };
  delete env.PI_SAFETY_SANDBOXED;
  delete env.PI_SAFETY_DISABLE_FILESYSTEM_SANDBOX;
  delete env.PI_SAFETY_FS_POLICY_HASH;
  return spawnSync(wrapper, ['-c', script, 'sh', ...args], {
    encoding: 'utf8',
    env: {
      ...env,
      PI_CODING_AGENT_DIR: agentDirectory,
      PI_SAFETY_CONFIG: configPath,
      PI_REAL_PI: '/bin/sh',
      ...envOverrides,
    },
  });
}

test('wrapper removes ANTHROPIC_API_KEY for Claude Code OAuth', () => {
  const directory = realpathSync(mkdtempSync(join(tmpdir(), 'pi-safety-launcher-')));
  const configPath = join(directory, 'config.jsonc');
  writeFileSync(configPath, JSON.stringify({ filesystem: { denyRead: [], denyWrite: [] }, shell: { deny: [] } }));

  const result = launch(configPath, 'test -z "${ANTHROPIC_API_KEY+x}"', [], {
    ANTHROPIC_API_KEY: 'must-not-reach-pi',
    PI_SAFETY_DISABLE_FILESYSTEM_SANDBOX: '1',
  });
  assert.equal(result.status, 0, result.stderr);
});

test('PI_SAFETY_DISABLE_FILESYSTEM_SANDBOX bypasses only the Seatbelt launch', () => {
  const directory = realpathSync(mkdtempSync(join(tmpdir(), 'pi-safety-launcher-')));
  const secret = join(directory, 'secret.txt');
  const configPath = join(directory, 'config.jsonc');
  writeFileSync(secret, 'secret');
  writeFileSync(configPath, JSON.stringify({ filesystem: { denyRead: [secret], denyWrite: [] }, shell: { deny: [] } }));

  const result = launch(configPath, 'cat "$1" && test -z "${PI_SAFETY_SANDBOXED+x}"', [secret], {
    PI_SAFETY_DISABLE_FILESYSTEM_SANDBOX: '1',
  });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, 'secret');
});

test('launcher applies denyRead and implied denyWrite to the whole child process', { skip: !canApplySeatbelt }, () => {
  const directory = realpathSync(mkdtempSync(join(tmpdir(), 'pi-safety-launcher-')));
  const secret = join(directory, 'secret.txt');
  const allowed = join(directory, 'allowed.txt');
  const configPath = join(directory, 'config.jsonc');
  writeFileSync(secret, 'secret');
  writeFileSync(allowed, 'allowed');
  writeFileSync(configPath, JSON.stringify({ filesystem: { denyRead: [secret], denyWrite: [] }, shell: { deny: [] } }));

  const blockedRead = launch(configPath, 'cat "$1"', [secret]);
  assert.notEqual(blockedRead.status, 0);
  assert.match(blockedRead.stderr, /Operation not permitted/);

  const blockedWrite = launch(configPath, 'printf changed > "$1"', [secret]);
  assert.notEqual(blockedWrite.status, 0);
  assert.match(blockedWrite.stderr, /Operation not permitted/);

  const allowedRead = launch(configPath, 'cat "$1"', [allowed]);
  assert.equal(allowedRead.status, 0, allowedRead.stderr);
  assert.equal(allowedRead.stdout, 'allowed');

  const blockedPolicyWrite = launch(configPath, 'printf disabled > "$1"', [configPath]);
  assert.notEqual(blockedPolicyWrite.status, 0);
  assert.match(blockedPolicyWrite.stderr, /Operation not permitted/);
});

test('denyWrite leaves reads available', { skip: !canApplySeatbelt }, () => {
  const directory = realpathSync(mkdtempSync(join(tmpdir(), 'pi-safety-launcher-')));
  const immutable = join(directory, 'immutable.txt');
  const configPath = join(directory, 'config.jsonc');
  writeFileSync(immutable, 'readable');
  writeFileSync(
    configPath,
    JSON.stringify({ filesystem: { denyRead: [], denyWrite: [immutable] }, shell: { deny: [] } }),
  );

  const read = launch(configPath, 'cat "$1"', [immutable]);
  assert.equal(read.status, 0, read.stderr);
  assert.equal(read.stdout, 'readable');

  const write = launch(configPath, 'printf changed > "$1"', [immutable]);
  assert.notEqual(write.status, 0);
  assert.match(write.stderr, /Operation not permitted/);
});

test('glob rules and hardlink attempts are enforced by Seatbelt', { skip: !canApplySeatbelt }, () => {
  const directory = realpathSync(mkdtempSync(join(tmpdir(), 'pi-safety-launcher-')));
  const protectedDirectory = join(directory, 'private');
  const secret = join(protectedDirectory, 'secret.txt');
  const link = join(directory, 'link.txt');
  const configPath = join(directory, 'config.jsonc');
  mkdirSync(protectedDirectory);
  writeFileSync(secret, 'secret');
  writeFileSync(
    configPath,
    JSON.stringify({ filesystem: { denyRead: [`${protectedDirectory}/**`], denyWrite: [] }, shell: { deny: [] } }),
  );

  const blockedRead = launch(configPath, 'cat "$1"', [secret]);
  assert.notEqual(blockedRead.status, 0);
  assert.match(blockedRead.stderr, /Operation not permitted/);

  const blockedLink = launch(configPath, 'ln "$1" "$2"', [secret, link]);
  assert.notEqual(blockedLink.status, 0);
  assert.match(blockedLink.stderr, /Operation not permitted/);
});
