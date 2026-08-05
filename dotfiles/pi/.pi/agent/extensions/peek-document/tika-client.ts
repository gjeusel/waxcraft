import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import { basename, extname } from 'node:path';
import { Readable } from 'node:stream';

export const DEFAULT_TIKA_URL = 'http://localhost:9998';
export const DEFAULT_MAX_FILE_BYTES = 100 * 1024 * 1024;
export const DEFAULT_TIMEOUT_MS = 120_000;

const OCR_LANGUAGES = 'fra+eng';

// Parsed via /rmeta/html so sheet/table structure survives, then converted to markdown.
const SPREADSHEET_EXTENSIONS = new Set(['.xlsx', '.xlsm', '.xlsb', '.xls', '.ods']);

// Shallow by default: headers + body + attachment names; contents only when recursive.
const EMAIL_EXTENSIONS = new Set(['.eml', '.msg']);

const CONNECT_HINT =
  'Failed to connect to Apache Tika. If no server is running, start one with:\n' +
  '> docker run -d -p 9998:9998 apache/tika:3.2.3.0-full';

export interface TikaClientOptions {
  /** Defaults to $TIKA_URL, then http://localhost:9998 */
  baseUrl?: string;
  maxFileBytes?: number;
  timeoutMs?: number;
}

export interface TikaParseOptions {
  /** For emails: also parse attachment contents (default false). */
  recursive?: boolean;
}

export interface TikaAttachment {
  name: string;
  contentType: string;
}

export interface SheetInfo {
  name: string;
  /** Non-empty table rows, header row included. */
  rows: number;
  cols: number;
  /** 1-based line range of the sheet (heading + table) within `content`. */
  startLine: number;
  endLine: number;
}

export interface TikaDocument {
  contentType: string;
  pages?: number;
  /** Extracted text of the container document and any embedded documents. */
  content: string;
  /** Metadata record of the container document (first /rmeta entry). */
  metadata: Record<string, unknown>;
  /** Direct attachments (emails only). */
  attachments?: TikaAttachment[];
  /** Worksheets (spreadsheets only). */
  sheets?: SheetInfo[];
}

export class TikaError extends Error {
  override name = 'TikaError';
}

export function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes}B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)}KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)}MB`;
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)}GB`;
}

/** Tika swamps extracted text with blank lines (page layout); keep at most two in a row. */
export function cleanContent(raw: string): string {
  return raw
    .replace(/\r\n?/g, '\n')
    .replace(/[ \t\u00a0]+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function decodeEntities(text: string): string {
  const named: Record<string, string> = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ' };
  return text.replace(/&(#x?[0-9a-f]+|[a-z]+);/gi, (all, code: string) => {
    if (code.startsWith('#')) {
      const n = code[1]?.toLowerCase() === 'x' ? parseInt(code.slice(2), 16) : parseInt(code.slice(1), 10);
      return Number.isFinite(n) ? String.fromCodePoint(n) : all;
    }
    return named[code.toLowerCase()] ?? all;
  });
}

function flattenHtml(html: string): string {
  return decodeEntities(html.replace(/<[^>]+>/g, ' '))
    .replace(/\s+/g, ' ')
    .trim();
}

function tableToMarkdown(inner: string): { markdown: string; rows: number; cols: number } {
  const rows: string[][] = [];
  const rowRe = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
  for (let row; (row = rowRe.exec(inner));) {
    const cells: string[] = [];
    const cellRe = /<t[dh][^>]*>([\s\S]*?)<\/t[dh]>/gi;
    for (let cell; (cell = cellRe.exec(row[1]));) {
      cells.push(flattenHtml(cell[1]).replace(/\|/g, '\\|'));
    }
    rows.push(cells);
  }
  if (rows.length === 0) return { markdown: '', rows: 0, cols: 0 };

  const width = Math.max(...rows.map((row) => row.length));
  const line = (row: string[]) => `| ${Array.from({ length: width }, (_, i) => row[i] ?? '').join(' | ')} |`;
  return {
    markdown: [line(rows[0]), `|${' --- |'.repeat(width)}`, ...rows.slice(1).map(line)].join('\n'),
    rows: rows.length,
    cols: width,
  };
}

/**
 * Convert Tika's XHTML spreadsheet output (one <div class="sheet"> per sheet, with an <h1>
 * name and a <table>) into markdown, preserving column boundaries and tracking each sheet's
 * dimensions and 1-based line range. Text outside tables (e.g. OCR of embedded images) is
 * kept as flattened plain text.
 */
export function convertSpreadsheetHtml(html: string): { content: string; sheets: SheetInfo[] } {
  const body = /<body[^>]*>([\s\S]*)<\/body>/i.exec(html)?.[1] ?? html;
  const blocks: string[] = [];
  const sheets: SheetInfo[] = [];
  let line = 1;

  const pushBlock = (text: string): { startLine: number; endLine: number } => {
    blocks.push(text);
    const startLine = line;
    const endLine = line + text.split('\n').length - 1;
    line = endLine + 2; // blank separator between blocks
    return { startLine, endLine };
  };
  const pushText = (segment: string) => {
    const text = flattenHtml(segment);
    if (text) pushBlock(text);
  };

  let pendingName: string | undefined;
  const flushBareSheet = () => {
    if (pendingName === undefined) return;
    const range = pushBlock(`## ${pendingName}`);
    sheets.push({ name: pendingName, rows: 0, cols: 0, ...range });
    pendingName = undefined;
  };

  const blockRe = /<h1[^>]*>([\s\S]*?)<\/h1>|<table[^>]*>([\s\S]*?)<\/table>/gi;
  let last = 0;
  for (let match; (match = blockRe.exec(body));) {
    pushText(body.slice(last, match.index));
    if (match[1] !== undefined) {
      flushBareSheet();
      pendingName = flattenHtml(match[1]);
    } else {
      const { markdown, rows, cols } = tableToMarkdown(match[2]);
      if (markdown) {
        const name = pendingName ?? 'Sheet';
        pendingName = undefined;
        const range = pushBlock(`## ${name}\n\n${markdown}`);
        sheets.push({ name, rows, cols, ...range });
      }
    }
    last = match.index + match[0].length;
  }
  flushBareSheet();
  pushText(body.slice(last));
  return { content: blocks.join('\n\n'), sheets };
}

export function spreadsheetHtmlToMarkdown(html: string): string {
  return convertSpreadsheetHtml(html).content;
}

function metaValues(record: Record<string, unknown>, key: string): string[] {
  const value = record[key];
  if (typeof value === 'string') return [value];
  if (Array.isArray(value)) return value.filter((v): v is string => typeof v === 'string');
  return [];
}

function formatEmailHeaders(metadata: Record<string, unknown>): string {
  const lines: string[] = [];
  const push = (label: string, key: string) => {
    const values = metaValues(metadata, key).map((v) => v.trim());
    if (values.length > 0) lines.push(`${label}: ${values.join(', ')}`);
  };
  push('From', 'dc:creator');
  push('To', 'Message-To');
  push('Cc', 'Message-Cc');
  push('Date', 'dcterms:created');
  push('Subject', 'dc:subject');
  return lines.join('\n');
}

function recordName(record: Record<string, unknown>): string {
  return typeof record.resourceName === 'string' ? record.resourceName : 'unnamed';
}

function recordContentType(record: Record<string, unknown>): string {
  return typeof record['Content-Type'] === 'string' ? record['Content-Type'] : 'unknown';
}

function buildEmailContent(
  records: Record<string, unknown>[],
  recursive: boolean,
): {
  content: string;
  attachments: TikaAttachment[];
} {
  const metadata = records[0];
  const embedded = records.slice(1);
  const attachments = embedded
    .filter((record) => (record['X-TIKA:embedded_depth'] ?? '1') === '1')
    .map((record) => ({ name: recordName(record), contentType: recordContentType(record) }));

  const body = metadata['X-TIKA:content'];
  const parts = [formatEmailHeaders(metadata), typeof body === 'string' ? cleanContent(body) : ''];

  if (attachments.length > 0) {
    const list = attachments.map((a) => `- ${a.name} (${a.contentType})`).join('\n');
    parts.push(`Attachments (${attachments.length}):\n${list}`);
    if (!recursive) {
      parts.push('(attachment contents not parsed — pass recursive=true to include them)');
    }
  }

  if (recursive) {
    for (const record of embedded) {
      const text = record['X-TIKA:content'];
      const heading = `=== Attachment: ${recordName(record)} (${recordContentType(record)}) ===`;
      const cleaned = typeof text === 'string' ? cleanContent(text) : '';
      parts.push(cleaned ? `${heading}\n${cleaned}` : heading);
    }
  }

  return { content: parts.filter(Boolean).join('\n\n'), attachments };
}

/**
 * Minimal client for the Apache Tika server REST API (PUT /rmeta/text).
 * https://cwiki.apache.org/confluence/display/TIKA/TikaServer
 */
export class TikaClient {
  readonly baseUrl: string;
  readonly maxFileBytes: number;
  readonly timeoutMs: number;

  constructor(options: TikaClientOptions = {}) {
    this.baseUrl = (options.baseUrl ?? process.env.TIKA_URL ?? DEFAULT_TIKA_URL).replace(/\/+$/, '');
    this.maxFileBytes = options.maxFileBytes ?? DEFAULT_MAX_FILE_BYTES;
    this.timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  }

  private buildHeaders(filePath: string, ocr: boolean): Record<string, string> {
    const headers: Record<string, string> = {
      Accept: 'application/json',
      'Content-Type': 'application/octet-stream',
      'X-Tika-ParseTimeoutMillis': String(this.timeoutMs),
      'X-Tika-OCRLanguage': OCR_LANGUAGES,
      'X-Tika-PDFEnableAutoSpace': 'true',
      'X-Tika-PDFSortByPosition': 'true',
      'X-Tika-OfficeIncludeSheetNames': 'true',
    };

    if (ocr) {
      // OCR inline images too (matches rnx-tika-client "partial" mode)
      headers['X-Tika-PDFextractInlineImages'] = 'true';
    } else {
      // Shallow email peek discards attachment text anyway; skip the expensive OCR pass.
      headers['X-Tika-PDFOcrStrategy'] = 'no_ocr';
    }

    // Filename improves type detection; only send when header-value safe.
    const name = basename(filePath);
    if (/^[\x20-\x7e]+$/.test(name) && !name.includes('"')) {
      headers['Content-Disposition'] = `attachment; filename="${name}"`;
    }

    return headers;
  }

  async parse(filePath: string, options: TikaParseOptions = {}): Promise<TikaDocument> {
    let info;
    try {
      info = await stat(filePath);
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === 'ENOENT') {
        throw new TikaError(`File not found: ${filePath}`);
      }
      throw error;
    }
    if (!info.isFile()) throw new TikaError(`Not a file: ${filePath}`);
    if (info.size > this.maxFileBytes) {
      throw new TikaError(
        `File too large: ${formatBytes(info.size)} exceeds the ${formatBytes(this.maxFileBytes)} limit (${filePath})`,
      );
    }

    const ext = extname(filePath).toLowerCase();
    const spreadsheet = SPREADSHEET_EXTENSIONS.has(ext);
    const email = EMAIL_EXTENSIONS.has(ext);
    const recursive = options.recursive ?? false;

    let response: Response;
    try {
      response = await fetch(`${this.baseUrl}/rmeta/${spreadsheet ? 'html' : 'text'}`, {
        method: 'PUT',
        headers: this.buildHeaders(filePath, !email || recursive),
        body: Readable.toWeb(createReadStream(filePath)) as ReadableStream,
        duplex: 'half',
        signal: AbortSignal.timeout(this.timeoutMs),
      } as RequestInit);
    } catch (error) {
      if (error instanceof Error && error.name === 'TimeoutError') {
        throw new TikaError(`Tika parse timed out after ${this.timeoutMs / 1000}s (${filePath})`);
      }
      throw new TikaError(`${CONNECT_HINT}\n(base url: ${this.baseUrl}, cause: ${(error as Error)?.cause ?? error})`);
    }

    if (!response.ok) {
      const body = (await response.text().catch(() => '')).slice(0, 500);
      throw new TikaError(`Tika returned HTTP ${response.status} for ${filePath}${body ? `: ${body}` : ''}`);
    }

    const records = (await response.json()) as Record<string, unknown>[];
    if (!Array.isArray(records) || records.length === 0) {
      throw new TikaError(`Tika returned an empty response for ${filePath}`);
    }

    const metadata = records[0];
    const contentType = typeof metadata['Content-Type'] === 'string' ? metadata['Content-Type'] : 'unknown';

    const rawPages = metadata['xmpTPg:NPages'];
    const pages = typeof rawPages === 'string' || typeof rawPages === 'number' ? Number(rawPages) : undefined;

    if (email) {
      const { content, attachments } = buildEmailContent(records, recursive);
      return { contentType, content, metadata, attachments };
    }

    const texts = records
      .map((record) => record['X-TIKA:content'])
      .filter((text): text is string => typeof text === 'string');

    if (spreadsheet) {
      // Assembled without cleanContent: generated markdown is already clean, and the
      // sheets' line ranges must stay aligned with the final content.
      let content = '';
      const sheets: SheetInfo[] = [];
      for (const text of texts) {
        const converted = convertSpreadsheetHtml(text);
        if (!converted.content) continue;
        const shift = content === '' ? 0 : content.split('\n').length + 1;
        for (const sheet of converted.sheets) {
          sheets.push({ ...sheet, startLine: sheet.startLine + shift, endLine: sheet.endLine + shift });
        }
        content = content === '' ? converted.content : `${content}\n\n${converted.content}`;
      }
      return { contentType, content, metadata, sheets };
    }

    const content = cleanContent(texts.join('\n\n'));
    return { contentType, pages: Number.isFinite(pages) ? pages : undefined, content, metadata };
  }
}
