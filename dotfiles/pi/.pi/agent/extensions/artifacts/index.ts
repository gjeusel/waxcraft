import { access } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  copyToClipboard,
  type ExtensionAPI,
  type ExtensionContext,
  type SessionEntry,
} from '@earendil-works/pi-coding-agent';
import { Text } from '@earendil-works/pi-tui';
import { Type } from 'typebox';
import { isArtifactServer, startArtifactServer, type ArtifactServerHandle } from './server.ts';
import {
  defaultStoreDir,
  listArtifacts,
  publishArtifact,
  readArtifact,
  SOURCE_EXTENSIONS,
  storedSourcePath,
  type ArtifactMeta,
} from './store.ts';

const TOOL_NAME = 'publish_artifact';
const ATTACH_MESSAGE_TYPE = 'artifact';
const SKILL_PATH = join(dirname(fileURLToPath(import.meta.url)), 'artifact-design', 'SKILL.md');
const SCRATCH_DIR = join(tmpdir(), 'pi-artifacts');

const parametersSchema = Type.Object(
  {
    path: Type.String({ description: `Source file to publish (${SOURCE_EXTENSIONS.join(', ')}), UTF-8.` }),
    title: Type.Optional(
      Type.String({ description: 'Page title; defaults to the existing title, then <title> or the first # heading.' }),
    ),
    artifact_id: Type.Optional(
      Type.String({
        description:
          'Existing artifact to update. Omit to update the artifact previously published from the same file, or to create one.',
      }),
    ),
  },
  { additionalProperties: false },
);

interface PublishDetails {
  id: string;
  title: string;
  url: string;
  version: number;
  created: boolean;
}

/** Most recent artifact published or attached on the current branch. */
export function latestSessionArtifactId(entries: SessionEntry[]): string | undefined {
  for (const entry of [...entries].reverse()) {
    if (entry.type === 'message' && entry.message.role === 'toolResult') {
      const { toolName, isError, details } = entry.message;
      const id = (details as Partial<PublishDetails> | undefined)?.id;
      if (toolName === TOOL_NAME && !isError && typeof id === 'string') return id;
    }

    if (entry.type === 'custom_message' && entry.customType === ATTACH_MESSAGE_TYPE) {
      const id = (entry.details as { id?: unknown } | undefined)?.id;
      if (typeof id === 'string') return id;
    }
  }

  return undefined;
}

function formatAge(iso: string, now: Date): string {
  const minutes = Math.round((now.getTime() - Date.parse(iso)) / 60_000);
  if (minutes < 1) return 'just now';
  if (minutes < 60) return `${minutes}m ago`;
  if (minutes < 60 * 24) return `${Math.round(minutes / 60)}h ago`;

  return `${Math.round(minutes / (60 * 24))}d ago`;
}

export default function (pi: ExtensionAPI) {
  const storeDir = defaultStoreDir();
  let server: ArtifactServerHandle | undefined;

  async function baseUrl(): Promise<string> {
    const reusable = server && (server.owned || (await isArtifactServer(server.baseUrl, storeDir)));
    if (!server || !reusable) server = await startArtifactServer(storeDir);

    return server.baseUrl;
  }

  async function artifactUrl(id: string): Promise<string> {
    return `${await baseUrl()}/${id}/`;
  }

  async function openInBrowser(url: string): Promise<void> {
    const result = await pi.exec('open', [url]);
    if (result.code !== 0) throw new Error(`open ${url} failed: ${result.stderr.trim() || `exit ${result.code}`}`);
  }

  /** The file to edit when updating an artifact: its original source, or the stored copy once that is gone. */
  async function editableSource(meta: ArtifactMeta): Promise<string> {
    try {
      await access(meta.source);
      return meta.source;
    } catch {
      return storedSourcePath(storeDir, meta);
    }
  }

  async function reopenLatest(ctx: ExtensionContext): Promise<void> {
    const sessionId = latestSessionArtifactId(ctx.sessionManager.getBranch());
    const id = sessionId ?? (await listArtifacts(storeDir))[0]?.id;
    if (!id) {
      ctx.ui.notify('No artifact to reopen yet.', 'info');
      return;
    }

    await openInBrowser(await artifactUrl(id));
  }

  pi.on('resources_discover', () => ({ skillPaths: [SKILL_PATH] }));

  pi.on('session_shutdown', () => {
    server?.close();
    server = undefined;
  });

  pi.registerTool({
    name: TOOL_NAME,
    label: 'publish artifact',
    description:
      'Publish a self-contained HTML or Markdown file as a local artifact page at a stable localhost URL. Republishing the same file or artifact_id updates the page in place; open tabs live-reload.',
    promptSnippet: 'Publish an HTML/Markdown page as a live local artifact',
    promptGuidelines: [
      `${TOOL_NAME}: Use when output is easier to see than read as terminal text (annotated diffs, charts, dashboards, side-by-side options, timelines, interactive controls) or when the user asks for an artifact or page. Read the artifact-design skill before building the page.`,
      `${TOOL_NAME}: Unless the user names a location, write the source under ${SCRATCH_DIR}/ (outside the project), then publish it. To revise, edit that same file and publish again: the URL stays the same.`,
      `${TOOL_NAME}: To update an artifact from another session, pass its artifact_id (from /artifacts or an attached artifact message) and edit the source file it names.`,
    ],
    parameters: parametersSchema,
    executionMode: 'sequential',

    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      const { meta, created, pagePath } = await publishArtifact(storeDir, {
        sourcePath: params.path,
        title: params.title,
        id: params.artifact_id,
        cwd: ctx.cwd,
        sessionId: ctx.sessionManager.getSessionId(),
      });
      const url = await artifactUrl(meta.id);

      const shouldOpen = created && ctx.hasUI && process.env.PI_ARTIFACT_AUTO_OPEN !== '0';
      if (shouldOpen) await openInBrowser(url);

      const action = created ? 'Published' : `Updated (v${meta.version})`;
      const details: PublishDetails = { id: meta.id, title: meta.title, url, version: meta.version, created };

      return {
        content: [
          {
            type: 'text' as const,
            text: `${action} artifact "${meta.title}" (artifact_id: ${meta.id}) at ${url}\nRendered page: ${pagePath}`,
          },
        ],
        details,
      };
    },

    renderCall(args, theme, _context) {
      const path = typeof args?.path === 'string' ? ` ${args.path}` : '';
      return new Text(`${theme.fg('toolTitle', theme.bold('publish artifact'))}${theme.fg('muted', path)}`, 0, 0);
    },

    renderResult(result, _options, theme) {
      const details = result.details as PublishDetails | undefined;
      if (!details?.url) return new Text(theme.fg('success', '✓ published'), 0, 0);

      const version = details.created ? 'new' : `v${details.version}`;
      return new Text(
        `${theme.fg('success', '✓')} ${details.title} ${theme.fg('dim', version)} ${theme.fg('accent', details.url)}`,
        0,
        0,
      );
    },
  });

  pi.registerCommand('artifacts', {
    description: 'List artifacts: open, copy the link, or attach one to the session',
    handler: async (_args, ctx) => {
      const artifacts = await listArtifacts(storeDir);
      if (artifacts.length === 0) {
        ctx.ui.notify(`No artifacts in ${storeDir}.`, 'info');
        return;
      }

      const now = new Date();
      const labels = artifacts.map((meta) => `${meta.title} · v${meta.version} · ${formatAge(meta.updatedAt, now)}`);
      const choice = await ctx.ui.select('Artifacts', labels);
      const meta = artifacts[labels.indexOf(choice ?? '')];
      if (!meta) return;

      const action = await ctx.ui.select(meta.title, ['Open in browser', 'Copy link', 'Attach to session']);
      const url = await artifactUrl(meta.id);

      if (action === 'Open in browser') {
        await openInBrowser(url);
      } else if (action === 'Copy link') {
        await copyToClipboard(url);
        ctx.ui.notify(`Copied ${url}`, 'info');
      } else if (action === 'Attach to session') {
        // Re-read so a concurrent publish from another session is reflected.
        const current = (await readArtifact(storeDir, meta.id)) ?? meta;
        const source = await editableSource(current);
        pi.sendMessage({
          customType: ATTACH_MESSAGE_TYPE,
          content: `Attached artifact "${current.title}" (artifact_id: ${current.id}, v${current.version}) at ${url}. Its source is ${source}: to update it, edit that file and call ${TOOL_NAME} with artifact_id "${current.id}".`,
          display: true,
          details: { id: current.id },
        });
      }
    },
  });

  pi.registerShortcut('ctrl+]', {
    description: "Reopen the session's latest artifact",
    handler: async (ctx) => {
      await reopenLatest(ctx);
    },
  });
}
