import { randomBytes } from 'node:crypto';
import { copyFile, mkdir, readdir, readFile, rename, writeFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { basename, extname, join, resolve } from 'node:path';
import { marked } from 'marked';

export const SOURCE_EXTENSIONS = ['.html', '.htm', '.md'] as const;

const ID_PATTERN = /^[a-z0-9][a-z0-9-]{0,80}$/;

export interface ArtifactMeta {
  id: string;
  title: string;
  /** File the artifact was last published from. */
  source: string;
  cwd: string;
  sessionId?: string;
  createdAt: string;
  updatedAt: string;
  version: number;
}

export interface PublishRequest {
  sourcePath: string;
  title?: string;
  id?: string;
  cwd: string;
  sessionId?: string;
  now?: Date;
}

export interface PublishResult {
  meta: ArtifactMeta;
  created: boolean;
  pagePath: string;
}

export function defaultStoreDir(): string {
  return join(homedir(), '.pi', 'agent', 'artifacts');
}

export function isArtifactId(id: string): boolean {
  return ID_PATTERN.test(id);
}

export function artifactDir(storeDir: string, id: string): string {
  if (!isArtifactId(id)) throw new Error(`Invalid artifact id: ${id}`);

  return join(storeDir, id);
}

export function pagePath(storeDir: string, id: string): string {
  return join(artifactDir(storeDir, id), 'index.html');
}

/** Stored copy of the last published source, used when the original file is gone. */
export function storedSourcePath(storeDir: string, meta: ArtifactMeta): string {
  const extension = extname(meta.source).toLowerCase() === '.md' ? '.md' : '.html';

  return join(artifactDir(storeDir, meta.id), `source${extension}`);
}

export function escapeHtml(text: string): string {
  return text.replace(/[&<>"']/g, (char) => `&#${char.charCodeAt(0)};`);
}

export function slugify(text: string): string {
  const slug = text
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 48)
    .replace(/-+$/, '');

  return slug || 'artifact';
}

export function inferTitle(source: string, extension: string, sourcePath: string): string {
  const match =
    extension === '.md' ? /^#\s+(.+?)\s*#*\s*$/m.exec(source) : /<title[^>]*>([\s\S]*?)<\/title>/i.exec(source);
  const title = match?.[1]?.replace(/\s+/g, ' ').trim();

  return title || basename(sourcePath, extname(sourcePath));
}

const MARKDOWN_STYLE = `
  :root { color-scheme: light dark; --fg: #1f2328; --muted: #59636e; --bg: #ffffff; --line: #d1d9e0; --code: #f6f8fa; }
  @media (prefers-color-scheme: dark) {
    :root { --fg: #e6edf3; --muted: #9198a1; --bg: #0d1117; --line: #3d444d; --code: #151b23; }
  }
  body { margin: 0; background: var(--bg); color: var(--fg);
    font: 16px/1.6 ui-sans-serif, -apple-system, "Segoe UI", Helvetica, Arial, sans-serif; }
  main { max-width: 860px; margin: 0 auto; padding: 48px 24px 96px; }
  h1, h2, h3 { line-height: 1.25; margin: 1.6em 0 0.6em; }
  h1 { font-size: 2em; margin-top: 0; } h2 { padding-bottom: 0.3em; border-bottom: 1px solid var(--line); }
  a { color: #0969da; } @media (prefers-color-scheme: dark) { a { color: #4493f8; } }
  code, pre { font: 0.9em/1.5 ui-monospace, SFMono-Regular, Menlo, monospace; }
  :not(pre) > code { background: var(--code); padding: 0.15em 0.35em; border-radius: 6px; }
  pre { background: var(--code); padding: 16px; border-radius: 8px; overflow-x: auto; }
  pre code.hljs { background: transparent; padding: 0; }
  blockquote { margin: 0; padding: 0 1em; color: var(--muted); border-left: 4px solid var(--line); }
  table { border-collapse: collapse; display: block; overflow-x: auto; }
  th, td { border: 1px solid var(--line); padding: 6px 13px; }
  img { max-width: 100%; } hr { border: 0; border-top: 1px solid var(--line); }
`;

const HIGHLIGHT_CDN = 'https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.11.1';

function documentShell(title: string, head: string, body: string): string {
  return [
    '<!doctype html>',
    '<html lang="en">',
    '<head>',
    '<meta charset="utf-8">',
    '<meta name="viewport" content="width=device-width, initial-scale=1">',
    `<title>${escapeHtml(title)}</title>`,
    head,
    '</head>',
    '<body>',
    body,
    '</body>',
    '</html>',
    '',
  ].join('\n');
}

/** Turn a source file into a standalone page: Markdown is rendered, HTML fragments get a document shell. */
export function renderPage(source: string, extension: string, title: string): string {
  if (extension === '.md') {
    const html = marked.parse(source, { async: false, gfm: true });
    const head = [
      `<style>${MARKDOWN_STYLE}</style>`,
      `<link rel="stylesheet" href="${HIGHLIGHT_CDN}/styles/github.min.css" media="(prefers-color-scheme: light)">`,
      `<link rel="stylesheet" href="${HIGHLIGHT_CDN}/styles/github-dark.min.css" media="(prefers-color-scheme: dark)">`,
      `<script src="${HIGHLIGHT_CDN}/highlight.min.js" defer onload="hljs.highlightAll()"></script>`,
    ].join('\n');

    return documentShell(title, head, `<main>\n${html}</main>`);
  }

  const isFullDocument = /<!doctype\s|<html[\s>]/i.test(source);

  return isFullDocument ? source : documentShell(title, '', source);
}

export async function readArtifact(storeDir: string, id: string): Promise<ArtifactMeta | undefined> {
  try {
    return JSON.parse(await readFile(join(artifactDir(storeDir, id), 'meta.json'), 'utf8')) as ArtifactMeta;
  } catch (error: unknown) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') return undefined;
    throw error;
  }
}

/** Artifacts in the store, most recently updated first. */
export async function listArtifacts(storeDir: string): Promise<ArtifactMeta[]> {
  let names: string[];
  try {
    names = await readdir(storeDir);
  } catch (error: unknown) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') return [];
    throw error;
  }

  const metas = await Promise.all(names.filter(isArtifactId).map((name) => readArtifact(storeDir, name)));

  return metas
    .filter((meta): meta is ArtifactMeta => meta !== undefined)
    .sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
}

async function writeFileAtomic(path: string, content: string): Promise<void> {
  const temporary = `${path}.${randomBytes(4).toString('hex')}.tmp`;
  await writeFile(temporary, content, 'utf8');
  await rename(temporary, path);
}

/**
 * Resolve which artifact a publish targets: an explicit id, else the artifact already published from
 * this file (or from its stored source copy), else a new one.
 */
async function findTarget(storeDir: string, sourcePath: string, id?: string): Promise<ArtifactMeta | undefined> {
  if (id !== undefined) {
    const meta = await readArtifact(storeDir, id);
    if (!meta) throw new Error(`Unknown artifact id "${id}". Run /artifacts to list existing artifacts.`);

    return meta;
  }

  const artifacts = await listArtifacts(storeDir);

  return artifacts.find((meta) => meta.source === sourcePath || storedSourcePath(storeDir, meta) === sourcePath);
}

export async function publishArtifact(storeDir: string, request: PublishRequest): Promise<PublishResult> {
  const sourcePath = resolve(request.cwd, request.sourcePath);
  const extension = extname(sourcePath).toLowerCase();
  if (!(SOURCE_EXTENSIONS as readonly string[]).includes(extension)) {
    throw new Error(`Unsupported artifact source "${basename(sourcePath)}": use ${SOURCE_EXTENSIONS.join(', ')}.`);
  }

  const source = await readFile(sourcePath, 'utf8');
  const existing = await findTarget(storeDir, sourcePath, request.id);
  const now = (request.now ?? new Date()).toISOString();
  const title = request.title?.trim() || existing?.title || inferTitle(source, extension, sourcePath);
  const id = existing?.id ?? `${slugify(title)}-${randomBytes(2).toString('hex')}`;

  const meta: ArtifactMeta = {
    id,
    title,
    source: sourcePath,
    cwd: request.cwd,
    sessionId: request.sessionId ?? existing?.sessionId,
    createdAt: existing?.createdAt ?? now,
    updatedAt: now,
    version: (existing?.version ?? 0) + 1,
  };

  const dir = artifactDir(storeDir, id);
  await mkdir(dir, { recursive: true });

  const sourceCopy = storedSourcePath(storeDir, meta);
  if (sourceCopy !== sourcePath) await copyFile(sourcePath, sourceCopy);

  // meta.json is written last: the live-reload watcher treats its change as "new version ready".
  await writeFileAtomic(pagePath(storeDir, id), renderPage(source, extension, title));
  await writeFileAtomic(join(dir, 'meta.json'), `${JSON.stringify(meta, null, 2)}\n`);

  return { meta, created: existing === undefined, pagePath: pagePath(storeDir, id) };
}
