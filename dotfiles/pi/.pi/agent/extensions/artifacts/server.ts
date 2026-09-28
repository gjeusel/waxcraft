import { watch, type FSWatcher } from 'node:fs';
import { readFile } from 'node:fs/promises';
import { createServer, type Server } from 'node:http';
import type { AddressInfo } from 'node:net';
import { artifactDir, escapeHtml, isArtifactId, listArtifacts, pagePath } from './store.ts';

export const DEFAULT_PORT = 7424;

const HOST = '127.0.0.1';
const IDENTITY_PATH = '/__pi_artifacts';

/** Reloads the page when the artifact is republished, keeping the scroll position. */
const LIVE_RELOAD_SCRIPT = `<script>(() => {
  const key = 'pi-artifact-scroll:' + location.pathname;
  const saved = sessionStorage.getItem(key);
  if (saved !== null) {
    sessionStorage.removeItem(key);
    addEventListener('load', () => scrollTo(0, Number(saved)));
  }
  new EventSource('events').onmessage = () => {
    sessionStorage.setItem(key, String(scrollY));
    location.reload();
  };
})();</script>`;

export function injectLiveReload(html: string): string {
  const bodyEnd = html.search(/<\/body>(?![\s\S]*<\/body>)/i);

  return bodyEnd === -1
    ? `${html}\n${LIVE_RELOAD_SCRIPT}`
    : `${html.slice(0, bodyEnd)}${LIVE_RELOAD_SCRIPT}\n${html.slice(bodyEnd)}`;
}

async function renderGallery(storeDir: string): Promise<string> {
  const artifacts = await listArtifacts(storeDir);
  const rows = artifacts.map(
    (meta) =>
      `<li><a href="/${meta.id}/">${escapeHtml(meta.title)}</a>` +
      `<span>v${meta.version} · ${escapeHtml(meta.updatedAt.slice(0, 16).replace('T', ' '))}</span></li>`,
  );

  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><title>pi artifacts</title><style>
  :root { color-scheme: light dark; } body { font: 15px/1.5 ui-sans-serif, -apple-system, sans-serif; max-width: 760px;
  margin: 48px auto; padding: 0 24px; } ul { list-style: none; padding: 0; } li { display: flex; justify-content:
  space-between; gap: 16px; padding: 10px 0; border-bottom: 1px solid color-mix(in srgb, currentColor 15%, transparent); }
  span { opacity: 0.6; font-variant-numeric: tabular-nums; white-space: nowrap; }
  </style></head><body><h1>pi artifacts</h1><ul>${rows.join('') || '<li>No artifacts yet.</li>'}</ul></body></html>`;
}

export function createArtifactServer(storeDir: string): Server {
  const watchers = new Set<FSWatcher>();

  const server = createServer(async (request, response) => {
    const path = new URL(request.url ?? '/', `http://${HOST}`).pathname;

    try {
      if (path === IDENTITY_PATH) {
        response.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify({ storeDir }));
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

      if (rest === '/events') {
        response.writeHead(200, { 'content-type': 'text/event-stream', 'cache-control': 'no-cache' });
        response.write(': connected\n\n');

        // Watch the directory: meta.json is replaced atomically on each publish, which breaks file watchers.
        let debounce: NodeJS.Timeout | undefined;
        const watcher = watch(artifactDir(storeDir, id), (_event, filename) => {
          if (filename !== 'meta.json') return;

          clearTimeout(debounce);
          debounce = setTimeout(() => response.write('data: reload\n\n'), 100);
        });
        watchers.add(watcher);
        request.on('close', () => {
          clearTimeout(debounce);
          watcher.close();
          watchers.delete(watcher);
        });
        return;
      }

      if (rest === '/') {
        const html = await readFile(pagePath(storeDir, id), 'utf8');
        response
          .writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' })
          .end(injectLiveReload(html));
        return;
      }

      response.writeHead(404).end('Not found');
    } catch (error: unknown) {
      const missing = (error as NodeJS.ErrnoException).code === 'ENOENT';
      if (!response.headersSent) response.writeHead(missing ? 404 : 500);
      response.end(missing ? 'Artifact not found' : String(error));
    }
  });

  server.on('close', () => {
    for (const watcher of watchers) watcher.close();
    watchers.clear();
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
