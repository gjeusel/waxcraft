import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { loadSafetyConfig, validateConfig } from './config.ts';

test('loads shell rules from JSONC with comments and trailing commas', () => {
  const directory = mkdtempSync(join(tmpdir(), 'pi-safety-config-'));
  const configPath = join(directory, 'pi-safety.jsonc');
  writeFileSync(
    configPath,
    `{
      // Command policy
      "shell": { "deny": [{ "command": "kubectl", "argv": { "containsAny": ["exec",] } }] }
    }`,
  );

  const loaded = loadSafetyConfig(configPath);
  assert.equal(loaded.status, 'loaded');
  assert.equal(loaded.config.shell.deny[0].command, 'kubectl');
});

test('rejects the complete config on schema errors', () => {
  const directory = mkdtempSync(join(tmpdir(), 'pi-safety-config-'));
  const configPath = join(directory, 'pi-safety.jsonc');
  writeFileSync(configPath, '{ "unknown": true }');

  const loaded = loadSafetyConfig(configPath);
  assert.equal(loaded.status, 'invalid');
  assert.deepEqual(loaded.config.shell.deny, []);
  assert.match(loaded.errors.join('\n'), /unknown/);
});

test('rejects empty argv token predicates', () => {
  for (const predicate of ['contains', 'containsAny', 'ordered', 'startsWithAny']) {
    const result = validateConfig({ shell: { deny: [{ command: 'example', argv: { [predicate]: [] } }] } });
    assert.match(result.errors.join('\n'), /expected at least one token/);
  }
});
