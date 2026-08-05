import assert from 'node:assert/strict';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { homedir, tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { DocumentCache, expandPath, renderDocumentSlice, renderSpreadsheetPreview, stripNewlines } from './index.ts';
import {
  cleanContent,
  convertSpreadsheetHtml,
  DEFAULT_TIKA_URL,
  spreadsheetHtmlToMarkdown,
  TikaClient,
  TikaError,
} from './tika-client.ts';

// --- pure helpers ---

test('expandPath resolves ~, absolute, and relative paths', () => {
  assert.equal(expandPath('~/doc.pdf', '/cwd'), join(homedir(), 'doc.pdf'));
  assert.equal(expandPath('/abs/doc.pdf', '/cwd'), '/abs/doc.pdf');
  assert.equal(expandPath('doc.pdf', '/cwd'), '/cwd/doc.pdf');
});

test('cleanContent collapses blank-line runs and trims', () => {
  assert.equal(cleanContent('\n\n\na\n   \n\n\n\nb\n\n'), 'a\n\nb');
  assert.equal(cleanContent('a\r\n\r\n\r\n\r\nb\r\n'), 'a\n\nb', 'CRLF emails must collapse too');
});

test('renderDocumentSlice shows full document without truncation notice', () => {
  const slice = renderDocumentSlice({ contentType: 'application/pdf', pages: 1, content: 'line1\nline2' });
  assert.equal(slice.text, '[application/pdf | 1 page | 2 lines total]\n\nline1\nline2');
  assert.equal(slice.nextOffset, undefined);
});

test('renderDocumentSlice paginates with continue offset when line limit hit', () => {
  const content = Array.from({ length: 10 }, (_, i) => `line${i + 1}`).join('\n');
  const slice = renderDocumentSlice({ contentType: 'text/csv', content }, 1, 4);
  assert.ok(slice.text.startsWith('[text/csv | 10 lines total]\n[showing lines 1-4 — continue with offset=5]\n\n'));
  assert.ok(slice.text.endsWith('line1\nline2\nline3\nline4'));
  assert.equal(slice.nextOffset, 5);

  const rest = renderDocumentSlice({ contentType: 'text/csv', content }, 5);
  assert.ok(rest.text.includes('[showing lines 5-10]'));
  assert.equal(rest.nextOffset, undefined);
  assert.ok(rest.text.endsWith('line10'));
});

test('renderDocumentSlice defaults to 500 lines', () => {
  const content = Array.from({ length: 600 }, (_, i) => `line${i + 1}`).join('\n');
  const slice = renderDocumentSlice({ contentType: 'text/plain', content });
  assert.equal(slice.endLine, 500);
  assert.equal(slice.nextOffset, 501);
});

test('renderDocumentSlice truncates on byte limit too', () => {
  const content = Array.from({ length: 100 }, () => 'x'.repeat(100)).join('\n');
  const slice = renderDocumentSlice({ contentType: 'text/plain', content }, 1, undefined, 1000);
  assert.ok(slice.endLine < 100);
  assert.equal(slice.nextOffset, slice.endLine + 1);
});

test('renderDocumentSlice rejects an offset beyond the end', () => {
  assert.throws(
    () => renderDocumentSlice({ contentType: 'text/plain', content: 'one line' }, 5),
    /offset 5 is beyond the end/,
  );
});

test('stripNewlines flattens extracted text for display', () => {
  assert.equal(stripNewlines('Facture n° 42\n\n  Total :\n1250.5 MWh  '), 'Facture n° 42 Total : 1250.5 MWh');
});

test('spreadsheetHtmlToMarkdown converts sheets to markdown tables', () => {
  const html = `<html><body>
<div class="sheet"><h1>Forecast</h1>
<table><tbody><tr>\t<td>Month</td>\t<td>Sales &amp; Fees</td></tr>
<tr>\t<td>Jan</td>\t<td>120</td>\t<td></td>\t<td>offset|pipe</td></tr>
</tbody></table>
</div>
<div class="sheet"><h1>Sites</h1>
<table><tbody><tr>\t<td>eolienne-nord</td></tr></tbody></table>
<p>OCR of an embedded image</p>
</div>
</body></html>`;
  assert.equal(
    spreadsheetHtmlToMarkdown(html),
    [
      '## Forecast',
      '',
      '| Month | Sales & Fees |  |  |',
      '| --- | --- | --- | --- |',
      '| Jan | 120 |  | offset\\|pipe |',
      '',
      '## Sites',
      '',
      '| eolienne-nord |',
      '| --- |',
      '',
      'OCR of an embedded image',
    ].join('\n'),
  );
});

test('convertSpreadsheetHtml tracks sheet dimensions and line ranges', () => {
  const dataRows = Array.from({ length: 300 }, (_, i) => `<tr><td>site-${i}</td><td>${i}</td></tr>`).join('');
  const html = `<html><body><div class="sheet"><h1>Big</h1><table><tbody><tr><td>site</td><td>mwh</td></tr>${dataRows}</tbody></table></div></body></html>`;
  const { content, sheets } = convertSpreadsheetHtml(html);
  assert.deepEqual(sheets, [{ name: 'Big', rows: 301, cols: 2, startLine: 1, endLine: 304 }]);
  const lines = content.split('\n');
  assert.equal(lines.length, 304);
  assert.equal(lines[0], '## Big');
  assert.equal(lines[303], '| site-299 | 299 |');
});

test('renderSpreadsheetPreview shows the first rows of each sheet with aligned offsets', () => {
  const dataRows = Array.from({ length: 300 }, (_, i) => `<tr><td>site-${i}</td><td>${i}</td></tr>`).join('');
  const html = `<html><body><div class="sheet"><h1>Big</h1><table><tbody><tr><td>site</td><td>mwh</td></tr>${dataRows}</tbody></table></div></body></html>`;
  const doc = { contentType: 'application/vnd.test', ...convertSpreadsheetHtml(html) };

  const preview = renderSpreadsheetPreview(doc);
  assert.ok(preview);
  assert.ok(preview.text.startsWith('[application/vnd.test | 1 sheet | 304 lines total]\n[preview —'));
  assert.ok(preview.text.includes('## Big (301 rows × 2 cols, lines 1-304)'));
  assert.ok(preview.text.includes('| site-0 | 0 |'));
  assert.ok(preview.text.includes('| site-14 | 14 |'), 'shows 15 data rows');
  assert.ok(!preview.text.includes('| site-15 | 15 |'));
  assert.ok(preview.text.includes('… (285 more rows — continue with offset=20)'));
  // the suggested offset must land exactly on the first hidden row
  assert.equal(doc.content.split('\n')[19], '| site-15 | 15 |');
});

test('renderSpreadsheetPreview declines small spreadsheets and non-spreadsheets', () => {
  const small = {
    contentType: 'x',
    ...convertSpreadsheetHtml('<body><h1>S</h1><table><tr><td>a</td></tr></table></body>'),
  };
  assert.equal(renderSpreadsheetPreview(small), undefined);
  assert.equal(renderSpreadsheetPreview({ contentType: 'x', content: 'text', sheets: undefined }), undefined);
});

test('DocumentCache evicts the least recently used entry', () => {
  const cache = new DocumentCache(2);
  const doc = (name: string) => ({ contentType: name, content: '', metadata: {} });
  cache.set('a', doc('a'));
  cache.set('b', doc('b'));
  cache.get('a'); // refresh a → b becomes LRU
  cache.set('c', doc('c'));
  assert.equal(cache.get('b'), undefined);
  assert.equal(cache.get('a')?.contentType, 'a');
  assert.equal(cache.get('c')?.contentType, 'c');
});

// --- client guards (no server needed) ---

test('TikaClient rejects a missing file', async () => {
  await assert.rejects(new TikaClient().parse('/nonexistent/file.pdf'), (error: unknown) => {
    assert.ok(error instanceof TikaError);
    assert.match(error.message, /File not found/);
    return true;
  });
});

test('TikaClient enforces the file size cap', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'peek-document-test-'));
  try {
    const path = join(dir, 'big.bin');
    await writeFile(path, Buffer.alloc(2048));
    await assert.rejects(
      new TikaClient({ maxFileBytes: 1024 }).parse(path),
      /File too large: 2\.0KB exceeds the 1\.0KB limit/,
    );
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

// --- integration against a live Tika server ---

const tikaUrl = process.env.TIKA_URL ?? DEFAULT_TIKA_URL;
const tikaAvailable = await fetch(`${tikaUrl}/version`, { signal: AbortSignal.timeout(1500) })
  .then((response) => response.ok)
  .catch(() => false);

test('parses a PDF via live Tika', { skip: !tikaAvailable && `no Tika server at ${tikaUrl}` }, async () => {
  const doc = await new TikaClient().parse(join(import.meta.dirname, 'data', 'sample.pdf'));
  assert.equal(doc.contentType, 'application/pdf');
  assert.equal(doc.pages, 1);
  assert.ok(doc.content.includes('Bonjour Tika smoke test'));
  assert.ok(!doc.content.includes('\n\n\n'), 'blank-line runs should be collapsed');
});

test('parses a CSV via live Tika', { skip: !tikaAvailable && `no Tika server at ${tikaUrl}` }, async () => {
  const doc = await new TikaClient().parse(join(import.meta.dirname, 'data', 'sample.csv'));
  assert.ok(doc.contentType.startsWith('text/'));
  assert.ok(doc.content.includes('eolienne-nord'));
});

test(
  'parses an EML shallow: headers, body, attachment names only',
  { skip: !tikaAvailable && `no Tika server at ${tikaUrl}` },
  async () => {
    const doc = await new TikaClient().parse(join(import.meta.dirname, 'data', 'sample.eml'));
    assert.equal(doc.contentType, 'message/rfc822');
    assert.ok(doc.content.includes('From: Alice Dupont <alice@example.com>'));
    assert.ok(doc.content.includes('To: Bob Martin <bob@example.com>'));
    assert.ok(doc.content.includes('Subject: Rapport mensuel production'));
    assert.ok(doc.content.includes('Veuillez trouver ci-joint'));
    assert.ok(doc.content.includes('- production.csv ('));
    assert.ok(doc.content.includes('recursive=true'));
    assert.ok(!doc.content.includes('eolienne-nord'), 'attachment contents must not be parsed by default');
    assert.equal(doc.attachments?.length, 1);
    assert.equal(doc.attachments?.[0].name, 'production.csv');
  },
);

test(
  'parses an EML recursively including attachment contents',
  { skip: !tikaAvailable && `no Tika server at ${tikaUrl}` },
  async () => {
    const doc = await new TikaClient().parse(join(import.meta.dirname, 'data', 'sample.eml'), { recursive: true });
    assert.ok(doc.content.includes('=== Attachment: production.csv ('));
    assert.ok(doc.content.includes('eolienne-nord'));
    assert.ok(!doc.content.includes('recursive=true'), 'no deeper-peek hint when already recursive');
  },
);

test(
  'parses an XLSX into markdown tables via live Tika',
  { skip: !tikaAvailable && `no Tika server at ${tikaUrl}` },
  async () => {
    const doc = await new TikaClient().parse(join(import.meta.dirname, 'data', 'sample.xlsx'));
    assert.ok(doc.contentType.includes('spreadsheet'));
    assert.ok(doc.content.includes('## Forecast'));
    assert.ok(doc.content.includes('## Sites \\| régions') || doc.content.includes('## Sites | régions'));
    assert.ok(doc.content.includes('| Month | Sales | Cumulative |'));
    // sparse row: D2 empty, E2 populated → column boundaries preserved
    assert.ok(doc.content.includes('| Jan | 120 | 120 |  | offset cell |'));
    assert.ok(doc.content.includes('| eolienne-nord | 12.5 |'));
  },
);
