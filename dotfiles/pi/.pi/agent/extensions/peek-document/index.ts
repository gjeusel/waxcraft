import { stat } from 'node:fs/promises';
import { homedir } from 'node:os';
import { isAbsolute, join, resolve } from 'node:path';
import { DEFAULT_MAX_BYTES, truncateHead, type ExtensionAPI } from '@earendil-works/pi-coding-agent';
import { Text } from '@earendil-works/pi-tui';
import { Type } from 'typebox';
import { TikaClient, type TikaDocument } from './tika-client.ts';

export const DEFAULT_PEEK_LINES = 500;

const parametersSchema = Type.Object(
  {
    path: Type.String({ description: 'Path to the document (absolute, ~/..., or relative to cwd).' }),
    // No schema defaults: an omitted offset/limit triggers the spreadsheet preview mode.
    offset: Type.Optional(
      Type.Number({
        description: '1-based line number of the extracted text to start reading from (default 1).',
        minimum: 1,
      }),
    ),
    limit: Type.Optional(
      Type.Number({
        description: `Maximum number of lines to return (default ${DEFAULT_PEEK_LINES}).`,
        minimum: 1,
      }),
    ),
    recursive: Type.Optional(
      Type.Boolean({
        description:
          'For emails (.eml, .msg): also parse attachment contents (slower). Default false: headers, body, and attachment names only.',
        default: false,
      }),
    ),
  },
  { additionalProperties: false },
);

export function stripNewlines(text: string): string {
  return text.replace(/\s*\n\s*/g, ' ').trim();
}

export function expandPath(path: string, cwd: string): string {
  if (path === '~' || path.startsWith('~/')) return join(homedir(), path.slice(1));
  return isAbsolute(path) ? path : resolve(cwd, path);
}

export interface DocumentSlice {
  text: string;
  startLine: number;
  endLine: number;
  totalLines: number;
  nextOffset?: number;
}

export function renderDocumentSlice(
  doc: Pick<TikaDocument, 'contentType' | 'pages' | 'content' | 'attachments' | 'sheets'>,
  offset = 1,
  limit?: number,
  maxBytes: number = DEFAULT_MAX_BYTES,
): DocumentSlice {
  const lines = doc.content.split('\n');
  const totalLines = lines.length;
  if (offset > totalLines) {
    throw new Error(`offset ${offset} is beyond the end of the document (${totalLines} lines total)`);
  }

  const truncation = truncateHead(lines.slice(offset - 1).join('\n'), {
    maxLines: limit ?? DEFAULT_PEEK_LINES,
    maxBytes,
  });
  const endLine = offset - 1 + truncation.outputLines;
  const nextOffset = truncation.truncated ? endLine + 1 : undefined;

  const fmt = (n: number) => n.toLocaleString('en-US');
  const headerParts = [doc.contentType];
  if (doc.pages !== undefined) headerParts.push(`${fmt(doc.pages)} page${doc.pages === 1 ? '' : 's'}`);
  if (doc.attachments !== undefined && doc.attachments.length > 0) {
    headerParts.push(`${doc.attachments.length} attachment${doc.attachments.length === 1 ? '' : 's'}`);
  }
  if (doc.sheets !== undefined && doc.sheets.length > 0) {
    headerParts.push(`${doc.sheets.length} sheet${doc.sheets.length === 1 ? '' : 's'}`);
  }
  headerParts.push(`${fmt(totalLines)} line${totalLines === 1 ? '' : 's'} total`);

  const header = [`[${headerParts.join(' | ')}]`];
  if (nextOffset !== undefined) {
    header.push(`[showing lines ${fmt(offset)}-${fmt(endLine)} — continue with offset=${nextOffset}]`);
  } else if (offset > 1) {
    header.push(`[showing lines ${fmt(offset)}-${fmt(endLine)}]`);
  }

  return {
    text: `${header.join('\n')}\n\n${truncation.content}`,
    startLine: offset,
    endLine,
    totalLines,
    nextOffset,
  };
}

export const PREVIEW_MAX_DATA_ROWS = 15;
/** Spreadsheets whose full content fits below this many lines are shown in full. */
export const PREVIEW_MIN_LINES = 200;

/**
 * Compact per-sheet preview for large spreadsheets: sheet map (name, dimensions, line
 * range) plus the first rows of each sheet. Returns undefined when a plain slice is
 * just as cheap.
 */
export function renderSpreadsheetPreview(
  doc: Pick<TikaDocument, 'contentType' | 'content' | 'sheets'>,
  maxBytes: number = DEFAULT_MAX_BYTES,
): DocumentSlice | undefined {
  const sheets = doc.sheets;
  if (!sheets || sheets.length === 0) return undefined;
  const lines = doc.content.split('\n');
  const totalLines = lines.length;
  if (totalLines <= PREVIEW_MIN_LINES) return undefined;

  const fmt = (n: number) => n.toLocaleString('en-US');
  const parts: string[] = [];
  for (const sheet of sheets) {
    const heading = `## ${sheet.name} (${fmt(sheet.rows)} rows × ${sheet.cols} cols, lines ${fmt(sheet.startLine)}-${fmt(sheet.endLine)})`;
    // Sheet block layout: heading at startLine, blank line, then table rows.
    const tableStart = sheet.startLine + 2;
    const tableLines = lines.slice(tableStart - 1, sheet.endLine);
    const shownCount = Math.min(tableLines.length, 2 + PREVIEW_MAX_DATA_ROWS); // header + separator + data rows
    const shown = tableLines.slice(0, shownCount);
    const hidden = tableLines.length - shownCount;
    let block = [heading, ...shown].join('\n');
    if (hidden > 0) {
      block += `\n… (${fmt(hidden)} more rows — continue with offset=${tableStart + shownCount})`;
    }
    parts.push(block);
  }

  const truncation = truncateHead(parts.join('\n\n'), { maxBytes });
  const header = [
    `[${doc.contentType} | ${sheets.length} sheet${sheets.length === 1 ? '' : 's'} | ${fmt(totalLines)} lines total]`,
    '[preview — first rows of each sheet; use offset/limit to read full data]',
  ];
  return {
    text: `${header.join('\n')}\n\n${truncation.content}`,
    startLine: 1,
    endLine: totalLines,
    totalLines,
  };
}

export class DocumentCache {
  private readonly entries = new Map<string, TikaDocument>();
  private readonly maxEntries: number;

  constructor(maxEntries = 5) {
    this.maxEntries = maxEntries;
  }

  get(key: string): TikaDocument | undefined {
    const value = this.entries.get(key);
    if (value !== undefined) {
      this.entries.delete(key);
      this.entries.set(key, value);
    }
    return value;
  }

  set(key: string, value: TikaDocument): void {
    this.entries.delete(key);
    this.entries.set(key, value);
    if (this.entries.size > this.maxEntries) {
      this.entries.delete(this.entries.keys().next().value as string);
    }
  }
}

interface PeekDocumentDetails {
  path: string;
  contentType: string;
  pages?: number;
  startLine: number;
  endLine: number;
  totalLines: number;
  cached: boolean;
  preview?: boolean;
}

export default function (pi: ExtensionAPI) {
  const client = new TikaClient();
  const cache = new DocumentCache();

  pi.registerTool<typeof parametersSchema, PeekDocumentDetails>({
    name: 'peek_document',
    label: 'peek_document',
    description:
      'Peek into binary documents (PDF, Word, Excel, PowerPoint, ODF, images with text, and most other formats): ' +
      'extracts readable text via a local Apache Tika server, including OCR of embedded images. Strongly preferred ' +
      'as a first step on any document: call it with just the path — the defaults (spreadsheet preview, first ' +
      `${DEFAULT_PEEK_LINES} lines) are tuned to give a good understanding at low cost — then decide whether it is ` +
      'worth reading further. Read-only. Output is paginated; when truncated, call again with the given offset. ' +
      'For plain-text and source files, prefer the regular read tool.',
    promptSnippet: 'Peek into binary documents (PDF, Office, ...) to quickly grasp their content.',
    promptGuidelines: [
      'peek_document: Use for binary document formats (pdf, docx, xlsx, pptx, odt, ...) that the plain read tool cannot handle; keep using read for text and source files.',
      'peek_document: Reach for it eagerly and with default parameters: on any unknown document, call it with just the path — the defaults return a compact view that is usually enough to judge what it contains.',
      'peek_document: When the response says it is truncated, continue with the suggested offset instead of re-reading from the start.',
      'peek_document: Parsing includes OCR of embedded images; near-empty output usually means the document genuinely has little text.',
      'peek_document: Spreadsheets (xlsx, xls, ods, ...) are rendered as one markdown table per sheet under a "## <sheet name>" heading, with empty cells preserving column positions.',
      'peek_document: On large spreadsheets, the first call (no offset/limit) returns a per-sheet preview with row/column counts and line ranges — that is usually enough; use the shown line ranges for targeted offset reads instead of scanning the whole file.',
      'peek_document: Emails (.eml, .msg) return headers, body, and attachment names only; call again with recursive=true when the attachment contents matter.',
    ],
    parameters: parametersSchema,
    executionMode: 'parallel',

    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      const filePath = expandPath(params.path, ctx.cwd);

      const info = await stat(filePath).catch((error: NodeJS.ErrnoException) => {
        throw error.code === 'ENOENT' ? new Error(`File not found: ${filePath}`) : error;
      });
      const recursive = params.recursive ?? false;
      const cacheKey = `${filePath}:${info.mtimeMs}:${info.size}:${recursive}`;

      let doc = cache.get(cacheKey);
      const cached = doc !== undefined;
      if (doc === undefined) {
        doc = await client.parse(filePath, { recursive });
        cache.set(cacheKey, doc);
      }

      const preview =
        params.offset === undefined && params.limit === undefined ? renderSpreadsheetPreview(doc) : undefined;
      const slice = preview ?? renderDocumentSlice(doc, params.offset ?? 1, params.limit ?? DEFAULT_PEEK_LINES);
      return {
        content: [{ type: 'text' as const, text: slice.text }],
        details: {
          path: filePath,
          contentType: doc.contentType,
          pages: doc.pages,
          startLine: slice.startLine,
          endLine: slice.endLine,
          totalLines: slice.totalLines,
          cached,
          preview: preview !== undefined,
        },
      };
    },

    renderCall(args, theme) {
      const path = typeof args?.path === 'string' ? args.path : '';
      const offset = typeof args?.offset === 'number' ? theme.fg('muted', ` offset=${args.offset}`) : '';
      return new Text(
        `${theme.fg('toolTitle', theme.bold('peek_document'))} ${theme.fg('accent', path)}${offset}`,
        0,
        0,
      );
    },

    renderResult(result, { expanded }, theme) {
      const details = result.details as PeekDocumentDetails | undefined;
      if (!details) return new Text(theme.fg('error', 'peek_document failed'), 0, 0);

      const pages = details.pages !== undefined ? ` ${details.pages}p` : '';
      const range = details.preview
        ? `preview · ${details.totalLines} lines`
        : `lines ${details.startLine}-${details.endLine}/${details.totalLines}`;
      let text =
        `${theme.fg('success', '✓')} ${theme.fg('accent', details.path)} ` +
        theme.fg('muted', `${details.contentType}${pages} · ${range}`);
      if (details.cached) text += theme.fg('dim', ' (cached)');

      const first = result.content?.find((c) => c.type === 'text');
      if (first && 'text' in first) {
        // Drop the bracketed header (already summarized above) and flatten newlines.
        const separator = first.text.indexOf('\n\n');
        const body = stripNewlines(separator === -1 ? first.text : first.text.slice(separator + 2));
        if (expanded) {
          text += `\n\n${body}`;
        } else if (body) {
          text += `\n  ${theme.fg('dim', body.length > 120 ? `${body.slice(0, 120)}…` : body)}`;
        }
      }
      return new Text(text, 0, 0);
    },
  });
}
