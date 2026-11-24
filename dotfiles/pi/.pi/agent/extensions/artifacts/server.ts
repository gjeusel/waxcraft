import { readFile } from 'node:fs/promises';
import { createServer, type Server } from 'node:http';
import type { AddressInfo } from 'node:net';
import { escapeHtml, isArtifactId, listArtifacts, pagePath, readArtifact } from './store.ts';

export const DEFAULT_PORT = 7424;

const HOST = '127.0.0.1';
const IDENTITY_PATH = '/__pi_artifacts';
const FAVICON_PATH = '/favicon.svg';
const FAVICON_LINK = `<link rel="icon" type="image/svg+xml" href="${FAVICON_PATH}">`;

/** A page with a π, drawn to stay legible at 16px. */
const FAVICON_SVG = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
<stop offset="0" stop-color="#7c5cff"/><stop offset="1" stop-color="#2f6bff"/></linearGradient></defs>
<rect width="64" height="64" rx="14" fill="url(#g)"/>
<path d="M18 12h20l10 10v30a2 2 0 0 1-2 2H18a2 2 0 0 1-2-2V14a2 2 0 0 1 2-2z" fill="#fff"/>
<path d="M38 12v8a2 2 0 0 0 2 2h8z" fill="#c9d4ff"/>
<path d="M23 30h18M28 30v15M36 30v12q0 3 3 3" fill="none" stroke="#3b5bff" stroke-width="4" stroke-linecap="round"/>
</svg>
`;

/** Adds the artifacts favicon to a page that does not declare its own icon. */
export function injectFavicon(html: string): string {
  if (/<link\b[^>]*\brel\s*=\s*["']?[^"'>]*\bicon\b/i.test(html)) return html;

  const headStart = /<head\b[^>]*>/i.exec(html);
  if (!headStart) return `${FAVICON_LINK}\n${html}`;

  const insertAt = headStart.index + headStart[0].length;

  return `${html.slice(0, insertAt)}\n${FAVICON_LINK}${html.slice(insertAt)}`;
}

/**
 * Reloads the page when the artifact is republished, keeping the scroll position.
 *
 * The version is polled, not pushed: a stream held open by each tab uses up the 6 connections a
 * browser allows per origin, and the next artifact tab then never loads.
 */
function liveReloadScript(version: number): string {
  return `<script>(() => {
  const key = 'pi-artifact-scroll:' + location.pathname;
  const saved = sessionStorage.getItem(key);
  if (saved !== null) {
    sessionStorage.removeItem(key);
    addEventListener('load', () => scrollTo(0, Number(saved)));
  }
  const check = async () => {
    if (document.hidden) return;
    const response = await fetch('version', { cache: 'no-store' }).catch(() => undefined);
    if (!response?.ok || (await response.text()) === '${version}') return;
    sessionStorage.setItem(key, String(scrollY));
    location.reload();
  };
  setInterval(check, 1000);
  document.addEventListener('visibilitychange', check);
})();</script>`;
}

export function injectLiveReload(html: string, version: number): string {
  const script = liveReloadScript(version);
  const bodyEnd = html.search(/<\/body>(?![\s\S]*<\/body>)/i);

  return bodyEnd === -1 ? `${html}\n${script}` : `${html.slice(0, bodyEnd)}${script}\n${html.slice(bodyEnd)}`;
}

async function renderGallery(storeDir: string): Promise<string> {
  const artifacts = await listArtifacts(storeDir);
  const rows = artifacts.map(
    (meta) =>
      `<li><a href="/${meta.id}/">${escapeHtml(meta.title)}</a>` +
      `<span>v${meta.version} · ${escapeHtml(meta.updatedAt.slice(0, 16).replace('T', ' '))}</span></li>`,
  );

  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><title>pi artifacts</title>${FAVICON_LINK}<style>
  :root { color-scheme: light dark; } body { font: 15px/1.5 ui-sans-serif, -apple-system, sans-serif; max-width: 760px;
  margin: 48px auto; padding: 0 24px; } ul { list-style: none; padding: 0; } li { display: flex; justify-content:
  space-between; gap: 16px; padding: 10px 0; border-bottom: 1px solid color-mix(in srgb, currentColor 15%, transparent); }
  span { opacity: 0.6; font-variant-numeric: tabular-nums; white-space: nowrap; }
  </style></head><body><h1>pi artifacts</h1><ul>${rows.join('') || '<li>No artifacts yet.</li>'}</ul></body></html>`;
}

export function createArtifactServer(storeDir: string): Server {
  const server = createServer(async (request, response) => {
    const path = new URL(request.url ?? '/', `http://${HOST}`).pathname;

    try {
      if (path === IDENTITY_PATH) {
        response.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify({ storeDir }));
        return;
      }

      if (path === FAVICON_PATH) {
        response
          .writeHead(200, { 'content-type': 'image/svg+xml', 'cache-control': 'max-age=86400' })
          .end(FAVICON_SVG);
        return;
      }

      if (path === '/') {
        response.writeHead(200, { 'content-type': 'text/html; charset=utf-8' }).end(await renderGallery(storeDir));
        return;
      }

      const [, id, rest] = /^\/([^/]+)(\/.*)?$/.exec(path) ?? [];
      if (!id || !isArtifactId(id)) {
        response.writeHead(404).end('Not found');
        return;
      }

      if (rest === undefined) {
        response.writeHead(308, { location: `/${id}/` }).end();
        return;
      }

      if (rest === '/version' || rest === '/') {
        const meta = await readArtifact(storeDir, id);
        if (!meta) {
          response.writeHead(404).end('Artifact not found');
          return;
        }

        if (rest === '/version') {
          response
            .writeHead(200, { 'content-type': 'text/plain', 'cache-control': 'no-store' })
            .end(String(meta.version));
          return;
        }

        // meta.json is written last on publish: a page newer than its version reloads once more.
        const html = await readFile(pagePath(storeDir, id), 'utf8');
        response
          .writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' })
          .end(injectLiveReload(injectFavicon(html), meta.version));
        return;
      }

      response.writeHead(404).end('Not found');
    } catch (error: unknown) {
      const missing = (error as NodeJS.ErrnoException).code === 'ENOENT';
      if (!response.headersSent) response.writeHead(missing ? 404 : 500);
      response.end(missing ? 'Artifact not found' : String(error));
    }
  });

  return server;
}

function listen(server: Server, port: number): Promise<number> {
  return new Promise((resolvePort, reject) => {
    const onError = (error: Error) => reject(error);
    server.once('error', onError);
    server.listen(port, HOST, () => {
      server.off('error', onError);
      resolvePort((server.address() as AddressInfo).port);
    });
  });
}

/** True when the URL serves an artifact server for the same store, e.g. from another pi session. */
export async function isArtifactServer(baseUrl: string, storeDir: string): Promise<boolean> {
  try {
    const response = await fetch(`${baseUrl}${IDENTITY_PATH}`, { signal: AbortSignal.timeout(1000) });
    const body = (await response.json()) as { storeDir?: unknown };

    return body.storeDir === storeDir;
  } catch {
    return false;
  }
}

export interface ArtifactServerHandle {
  baseUrl: string;
  /** False when reusing a server owned by another process, which may exit at any time. */
  owned: boolean;
  close(): void;
}

/**
 * Serve the store on the default port so URLs stay stable across sessions. Reuse another session's
 * server when it already holds the port, and fall back to a random port when something else does.
 */
export async function startArtifactServer(storeDir: string, port = DEFAULT_PORT): Promise<ArtifactServerHandle> {
  const server = createArtifactServer(storeDir);
  // The server must not keep print-mode or RPC processes alive once pi is done.
  server.unref();

  let boundPort: number;
  try {
    boundPort = await listen(server, port);
  } catch (error: unknown) {
    if ((error as NodeJS.ErrnoException).code !== 'EADDRINUSE') throw error;

    const sharedUrl = `http://${HOST}:${port}`;
    if (await isArtifactServer(sharedUrl, storeDir)) return { baseUrl: sharedUrl, owned: false, close: () => {} };

    boundPort = await listen(server, 0);
  }

  return {
    baseUrl: `http://${HOST}:${boundPort}`,
    owned: true,
    close: () => {
      server.close();
      server.closeAllConnections();
    },
  };
}
