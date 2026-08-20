import assert from 'node:assert/strict';
import { mkdtempSync, realpathSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { effectiveDenyWrite, filesystemPolicyHash, loadSafetyConfig, validateConfig } from './config.ts';
import { buildSandboxProfile } from './profile.ts';

test('loads JSONC with comments and trailing commas', () => {
  const directory = mkdtempSync(join(tmpdir(), 'pi-safety-config-'));
  const configPath = join(directory, 'pi-safety.jsonc');
  writeFileSync(
    configPath,
    `{
      // confidential material
      "filesystem": { "denyRead": ["${directory}/secret/**",], "denyWrite": [] },
      "shell": { "deny": [{ "command": "kubectl", "argv": { "containsAny": ["exec"] } }] }
    }`,
  );

  const loaded = loadSafetyConfig(configPath);
  assert.equal(loaded.status, 'loaded');
  assert.deepEqual(loaded.config.filesystem.denyRead, [`${realpathSync(directory)}/secret/**`]);
  assert.equal(loaded.config.shell.deny[0].command, 'kubectl');
  assert.ok(loaded.config.filesystem.denyWrite.includes(realpathSync(configPath)));
});

test('rejects the complete user layer on schema errors', () => {
  const directory = mkdtempSync(join(tmpdir(), 'pi-safety-config-'));
  const configPath = join(directory, 'pi-safety.jsonc');
  writeFileSync(configPath, '{ "filesystem": { "denyReads": ["/secret"] } }');

  const loaded = loadSafetyConfig(configPath);
  assert.equal(loaded.status, 'invalid');
  assert.deepEqual(loaded.config.filesystem.denyRead, []);
  assert.match(loaded.errors.join('\n'), /denyReads/);
});

test('requires rooted path globs', () => {
  const result = validateConfig({ filesystem: { denyRead: ['**/*.pem'] } });
  assert.match(result.errors.join('\n'), /must start with/);
});
test('rejects ambiguous globstars and control characters', () => {
  const ambiguous = validateConfig({ filesystem: { denyRead: ['/secret/**suffix'] } });
  assert.match(ambiguous.errors.join('\n'), /complete path segment/);

  const control = validateConfig({ filesystem: { denyRead: ['/secret/line\nbreak'] } });
  assert.match(control.errors.join('\n'), /control characters/);
});
test('rejects empty argv token predicates', () => {
  for (const predicate of ['contains', 'containsAny', 'ordered', 'startsWithAny']) {
    const result = validateConfig({ shell: { deny: [{ command: 'example', argv: { [predicate]: [] } }] } });
    assert.match(result.errors.join('\n'), /expected at least one token/);
  }
});

test('denyRead always implies denyWrite', () => {
  const config = {
    filesystem: { denyRead: ['/secret'], denyWrite: ['/immutable'] },
    shell: { deny: [] },
  };
  assert.deepEqual(effectiveDenyWrite(config), ['/secret', '/immutable']);
});

test('filesystem hash ignores rule ordering', () => {
  const first = {
    filesystem: { denyRead: ['/a', '/b'], denyWrite: ['/c'] },
    shell: { deny: [] },
  };
  const second = {
    filesystem: { denyRead: ['/b', '/a'], denyWrite: ['/c'] },
    shell: { deny: [] },
  };
  assert.equal(filesystemPolicyHash(first), filesystemPolicyHash(second));
});

test('profile is deny-only and compiles literals and globs', () => {
  const profile = buildSandboxProfile({
    filesystem: { denyRead: ['/secret', '/history/**'], denyWrite: ['/immutable'] },
    shell: { deny: [] },
  });
  assert.match(profile, /\(allow default\)/);
  assert.match(profile, /\(deny file-read\* \(subpath "\/secret"\)\)/);
  assert.match(profile, /\(deny file-read\* \(regex "\^\/history/);
  assert.match(profile, /\(deny file-write\* \(subpath "\/secret"\)\)/);
  assert.match(profile, /\(deny file-write\* \(subpath "\/immutable"\)\)/);
});
