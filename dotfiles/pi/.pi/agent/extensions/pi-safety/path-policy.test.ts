import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, realpathSync, symlinkSync, writeFileSync } from 'node:fs';
import { homedir, tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { globToRegExp, inspectPath, isAnchoredPattern, targetPaths } from './path-policy.ts';

test('globs: ** spans directories, * and ? stay within one segment', () => {
  assert.ok(globToRegExp('/a/**').test('/a/b/c.txt'));
  assert.ok(globToRegExp('/a/*.txt').test('/a/c.txt'));
  assert.ok(!globToRegExp('/a/*.txt').test('/a/b/c.txt'));
  assert.ok(globToRegExp('/a/?.txt').test('/a/c.txt'));
  assert.ok(globToRegExp('**/.env').test('/project/.env'));
  assert.ok(globToRegExp('**/.env').test('/project/nested/.env'));
  assert.ok(!globToRegExp('**/.env').test('/project/.env.example'));
  assert.ok(globToRegExp('/a/**/b').test('/a/b'));
  assert.ok(!globToRegExp('/a.b').test('/aXb'));
  assert.ok(globToRegExp('~/.ssh/**').test(join(homedir(), '.ssh', 'config')));
});

test('globs match case-insensitively on macOS', { skip: process.platform !== 'darwin' }, () => {
  assert.ok(globToRegExp('~/.ssh/**').test(join(homedir(), '.SSH', 'config')));
});

test('patterns must be anchored', () => {
  assert.ok(isAnchoredPattern('/etc/**'));
  assert.ok(isAnchoredPattern('~/.ssh/**'));
  assert.ok(isAnchoredPattern('**/.env'));
  assert.ok(!isAnchoredPattern('.env'));
  assert.ok(!isAnchoredPattern('src/**'));
});

test('targets resolve like Pi tools: @ prefix, ~, and cwd-relative paths', () => {
  assert.deepEqual(targetPaths('@notes.md', '/nonexistent-root'), ['/nonexistent-root/notes.md']);
  assert.deepEqual(targetPaths('sub/file', '/nonexistent-root'), ['/nonexistent-root/sub/file']);
  assert.equal(targetPaths('~/x/y', '/')[0], join(homedir(), 'x', 'y'));
});

test('a rule matches through a symlinked directory, including for new files', () => {
  const root = realpathSync(mkdtempSync(join(tmpdir(), 'pi-safety-paths-')));
  const repository = join(root, 'repo', 'agent');
  mkdirSync(repository, { recursive: true });
  writeFileSync(join(repository, 'pi-safety.jsonc'), '{}');
  const link = join(root, 'home-agent');
  symlinkSync(repository, link);

  const rules = { deny: [], ask: [`${repository}/**`] };
  assert.deepEqual(inspectPath(join(link, 'pi-safety.jsonc'), '/', rules), {
    action: 'ask',
    path: join(repository, 'pi-safety.jsonc'),
    pattern: `${repository}/**`,
  });
  assert.equal(inspectPath(join(link, 'new', 'file.txt'), '/', rules)?.path, join(repository, 'new', 'file.txt'));

  // The lexical spelling matches too, so a rule on the link path cannot be bypassed via the target.
  const linkRules = { deny: [`${link}/**`], ask: [] };
  assert.equal(inspectPath(join(link, 'pi-safety.jsonc'), '/', linkRules)?.action, 'deny');
});

test('deny rules take precedence over ask rules; unmatched paths pass', () => {
  const rules = { deny: ['/protected/**'], ask: ['/protected/**', '**/.env'] };
  assert.equal(inspectPath('/protected/key', '/', rules)?.action, 'deny');
  assert.equal(inspectPath('.env', '/project', rules)?.action, 'ask');
  assert.equal(inspectPath('src/index.ts', '/project', rules), undefined);
});
