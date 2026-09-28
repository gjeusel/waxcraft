import assert from 'node:assert/strict';
import { mkdtemp, readFile, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import type { SessionEntry } from '@earendil-works/pi-coding-agent';
import { latestSessionArtifactId } from './index.ts';
import { injectLiveReload, startArtifactServer } from './server.ts';
import { inferTitle, listArtifacts, publishArtifact, renderPage, slugify, storedSourcePath } from './store.ts';

async function tempDirs(): Promise<{ storeDir: string; workDir: string }> {
  const root = await mkdtemp(join(tmpdir(), 'pi-artifacts-test-'));

  return { storeDir: join(root, 'store'), workDir: root };
}

test('slugify keeps ascii words and falls back when empty', () => {
  assert.equal(slugify('Déploiement: échecs par service!'), 'deploiement-echecs-par-service');
  assert.equal(slugify('!!!'), 'artifact');
});

test('inferTitle reads <title>, then the first heading, then the filename', () => {
  assert.equal(inferTitle('<title> Q3\n Report </title>', '.html', '/tmp/x.html'), 'Q3 Report');
  assert.equal(inferTitle('intro\n# Deploy failures\n', '.md', '/tmp/x.md'), 'Deploy failures');
  assert.equal(inferTitle('<p>hi</p>', '.html', '/tmp/pr-review.html'), 'pr-review');
});

test('renderPage keeps full documents and wraps fragments and Markdown', () => {
  const full = '<!DOCTYPE html><html><body>x</body></html>';
  assert.equal(renderPage(full, '.html', 'T'), full);

  const fragment = renderPage('<p>x</p>', '.html', 'A & B');
  assert.match(fragment, /^<!doctype html>/);
  assert.match(fragment, /<title>A &#38; B<\/title>/);
  assert.match(fragment, /<body>\n<p>x<\/p>\n<\/body>/);

  assert.match(renderPage('# Hi\n\n| a |\n|---|\n| 1 |\n', '.md', 'Hi'), /<main>\n<h1>Hi<\/h1>[\s\S]*<table>/);
});

test('publishing the same file updates the same artifact', async () => {
  const { storeDir, workDir } = await tempDirs();
  const source = join(workDir, 'report.md');
  await writeFile(source, '# Report\n\nv1\n');

  const first = await publishArtifact(storeDir, { sourcePath: 'report.md', cwd: workDir });
  assert.equal(first.created, true);
  assert.equal(first.meta.title, 'Report');
  assert.equal(first.meta.version, 1);
  assert.match(first.meta.id, /^report-[0-9a-f]{4}$/);

  await writeFile(source, '# Renamed\n\nv2\n');
  const second = await publishArtifact(storeDir, { sourcePath: source, cwd: '/elsewhere' });
  assert.equal(second.created, false);
  assert.equal(second.meta.id, first.meta.id);
  assert.equal(second.meta.version, 2);
  assert.equal(second.meta.title, 'Report', 'keeps the existing title');
  assert.equal(second.meta.createdAt, first.meta.createdAt);
  assert.match(await readFile(second.pagePath, 'utf8'), /v2/);

  const copy = storedSourcePath(storeDir, second.meta);
  assert.equal(await readFile(copy, 'utf8'), '# Renamed\n\nv2\n');

  const fromCopy = await publishArtifact(storeDir, { sourcePath: copy, cwd: workDir, title: 'Final' });
  assert.equal(fromCopy.meta.id, first.meta.id, 'the stored source copy maps back to its artifact');
  assert.equal(fromCopy.meta.title, 'Final');

  assert.deepEqual(
    (await listArtifacts(storeDir)).map((meta) => meta.id),
    [first.meta.id],
  );
});

test('publishing rejects unknown ids and unsupported files', async () => {
  const { storeDir, workDir } = await tempDirs();
  await writeFile(join(workDir, 'page.html'), '<p>x</p>');
  await writeFile(join(workDir, 'data.json'), '{}');

  await assert.rejects(
    publishArtifact(storeDir, { sourcePath: 'page.html', id: 'nope-0000', cwd: workDir }),
    /Unknown/,
  );
  await assert.rejects(publishArtifact(storeDir, { sourcePath: 'data.json', cwd: workDir }), /Unsupported/);
});

test('listArtifacts sorts by last update', async () => {
  const { storeDir, workDir } = await tempDirs();
  await writeFile(join(workDir, 'a.html'), '<p>a</p>');
  await writeFile(join(workDir, 'b.html'), '<p>b</p>');

  const a = await publishArtifact(storeDir, { sourcePath: 'a.html', cwd: workDir, now: new Date('2026-01-01') });
  const b = await publishArtifact(storeDir, { sourcePath: 'b.html', cwd: workDir, now: new Date('2026-01-02') });
  await publishArtifact(storeDir, { sourcePath: 'a.html', cwd: workDir, now: new Date('2026-01-03') });

  assert.deepEqual(
    (await listArtifacts(storeDir)).map((meta) => meta.id),
    [a.meta.id, b.meta.id],
  );
});

test('injectLiveReload inserts before the last </body>, or appends', () => {
  assert.match(injectLiveReload('<body>x</body></html>'), /^<body>x<script>[\s\S]*<\/script>\n<\/body><\/html>$/);
  assert.match(injectLiveReload('<p>x</p>'), /^<p>x<\/p>\n<script>/);
});

test('latestSessionArtifactId prefers the newest publish or attach on the branch', () => {
  const publish = (id: string, isError = false) =>
    ({
      type: 'message',
      message: { role: 'toolResult', toolName: 'publish_artifact', isError, details: { id } },
    }) as unknown as SessionEntry;
  const attach = (id: string) =>
    ({ type: 'custom_message', customType: 'artifact', details: { id } }) as unknown as SessionEntry;

  assert.equal(latestSessionArtifactId([publish('a'), attach('b')]), 'b');
  assert.equal(latestSessionArtifactId([attach('b'), publish('a'), publish('c', true)]), 'a');
  assert.equal(latestSessionArtifactId([]), undefined);
});

test('server serves pages with live reload and notifies on republish', async (t) => {
  const { storeDir, workDir } = await tempDirs();
  const source = join(workDir, 'live.html');
  await writeFile(source, '<p>one</p>');
  const { meta } = await publishArtifact(storeDir, { sourcePath: source, cwd: workDir });

  const server = await startArtifactServer(storeDir, 0);
  t.after(() => server.close());
  assert.equal(server.owned, true);

  const page = await (await fetch(`${server.baseUrl}/${meta.id}/`)).text();
  assert.match(page, /<p>one<\/p>/);
  assert.match(page, /new EventSource\('events'\)/);

  const gallery = await (await fetch(`${server.baseUrl}/`)).text();
  assert.match(gallery, new RegExp(`href="/${meta.id}/"`));

  assert.equal((await fetch(`${server.baseUrl}/..%2Fetc/`)).status, 404);
  assert.equal((await fetch(`${server.baseUrl}/${meta.id}`, { redirect: 'manual' })).status, 308);

  const events = await fetch(`${server.baseUrl}/${meta.id}/events`);
  const reader = events.body!.getReader();
  await reader.read(); // ': connected' comment

  await writeFile(source, '<p>two</p>');
  await publishArtifact(storeDir, { sourcePath: source, cwd: workDir });
  const { value } = await reader.read();
  assert.match(new TextDecoder().decode(value), /data: reload/);
  await reader.cancel();

  const shared = await startArtifactServer(storeDir, Number(new URL(server.baseUrl).port));
  assert.equal(shared.owned, false, 'reuses the server already bound to the port');
  assert.equal(shared.baseUrl, server.baseUrl);
});
