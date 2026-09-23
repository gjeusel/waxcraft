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

test('parses autoMode.minConfidence and rejects out-of-range values', () => {
  assert.equal(validateConfig({}).config.autoMode.minConfidence, 0.5);
  assert.equal(validateConfig({ autoMode: { minConfidence: 0.7 } }).config.autoMode.minConfidence, 0.7);
  assert.match(validateConfig({ autoMode: { minConfidence: 1.5 } }).errors.join('\n'), /between 0 and 1/);
  assert.match(validateConfig({ autoMode: { threshold: 0.5 } }).errors.join('\n'), /unknown property "threshold"/);
});

test('parses path rules and rejects unanchored patterns', () => {
  assert.deepEqual(validateConfig({}).config.paths, { deny: [], ask: [] });

  const valid = validateConfig({ paths: { deny: ['~/.ssh/**'], ask: ['**/.env', '/etc/hosts'] } });
  assert.deepEqual(valid.errors, []);
  assert.deepEqual(valid.config.paths, { deny: ['~/.ssh/**'], ask: ['**/.env', '/etc/hosts'] });

  assert.match(validateConfig({ paths: { ask: ['.env'] } }).errors.join('\n'), /paths\.ask\[0]: expected a pattern/);
  assert.match(validateConfig({ paths: { allow: [] } }).errors.join('\n'), /unknown property "allow"/);
  assert.match(validateConfig({ paths: { deny: '~/.ssh/**' } }).errors.join('\n'), /expected an array of strings/);
});
