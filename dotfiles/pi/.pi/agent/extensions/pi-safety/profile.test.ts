import assert from 'node:assert/strict';
import test from 'node:test';
import { pathGlobToSeatbeltRegex } from './profile.ts';

function matches(glob: string, path: string): boolean {
  return new RegExp(pathGlobToSeatbeltRegex(glob)).test(path);
}

test('single star stays within one path segment and includes dotfiles', () => {
  assert.equal(matches('/a/*.pem', '/a/key.pem'), true);
  assert.equal(matches('/a/*.pem', '/a/.hidden.pem'), true);
  assert.equal(matches('/a/*.pem', '/a/nested/key.pem'), false);
});

test('trailing globstar includes the directory inode and descendants', () => {
  assert.equal(pathGlobToSeatbeltRegex('/a/**'), '^/a(/.*)?$');
  assert.equal(matches('/a/**', '/a'), true);
  assert.equal(matches('/a/**', '/a/child/deep'), true);
  assert.equal(matches('/a/**', '/ab'), false);
});

test('middle globstar matches zero or multiple directories', () => {
  assert.equal(pathGlobToSeatbeltRegex('/a/**/target'), '^/a/(.*/)?target$');
  assert.equal(matches('/a/**/target', '/a/target'), true);
  assert.equal(matches('/a/**/target', '/a/one/two/target'), true);
  assert.equal(matches('/a/**/target', '/a/one/other'), false);
});

test('regex metacharacters in literal path text are escaped', () => {
  const glob = '/dir (1)/a+b.[x]/*.log';
  assert.equal(pathGlobToSeatbeltRegex(glob), '^/dir \\(1\\)/a\\+b\\.\\[x\\]/[^/]*\\.log$');
  assert.equal(matches(glob, '/dir (1)/a+b.[x]/today.log'), true);
});

test('compiler emits only the conservative regex subset supported by Seatbelt', () => {
  for (const glob of ['/a/*', '/a/**', '/a/**/target', '/dir (1)/*.log']) {
    const source = pathGlobToSeatbeltRegex(glob);
    assert.doesNotMatch(source, /\(\?:|\(\?[=!<]|[*+?]\?/);
  }
});
