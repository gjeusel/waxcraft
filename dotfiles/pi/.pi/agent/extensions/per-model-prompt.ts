import { appendFile, readFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join } from 'node:path';
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';

// Model ids may contain slashes (e.g. openrouter "qwen/qwen3-coder"); flatten
// them so every model maps to a single file in the prompt directory.
export function promptFileName(modelId: string): string {
  return `${modelId.replaceAll('/', '--')}.md`;
}

export async function loadModelPrompt(promptDir: string, modelId: string): Promise<string | undefined> {
  let content: string;
  try {
    content = await readFile(join(promptDir, promptFileName(modelId)), 'utf8');
  } catch (error: unknown) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') return undefined;
    throw error;
  }
  const trimmed = content.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

export function buildRephrasePrompt(feedback: string): string {
  return [
    'You maintain a file of per-model system-prompt directives.',
    'Rewrite the feedback below as a single concise imperative directive suitable for a system prompt.',
    'Address the assistant directly (e.g. "Always ...", "Never ...", "Before ...").',
    'Preserve the original intent; do not add rules that were not given.',
    'Return only the directive text — no quotes, bullets, or commentary.',
    '',
    'Feedback:',
    feedback,
  ].join('\n');
}

export async function appendDirective(promptDir: string, modelId: string, directive: string): Promise<string> {
  const file = join(promptDir, promptFileName(modelId));
  let existing = '';
  try {
    existing = await readFile(file, 'utf8');
  } catch (error: unknown) {
    if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
  }
  const separator = existing.length === 0 || existing.endsWith('\n') ? '' : '\n';
  await appendFile(file, `${separator}- ${directive.trim()}\n`, 'utf8');
  return file;
}

export default function (pi: ExtensionAPI, promptDir = join(homedir(), '.pi', 'agent', 'per-model-prompt')) {
  pi.on('before_agent_start', async (event, ctx) => {
    const modelId = ctx.model?.id;
    if (!modelId) return;

    const prompt = await loadModelPrompt(promptDir, modelId);
    if (!prompt) return;

    return { systemPrompt: `${event.systemPrompt}\n\n${prompt}` };
  });

  pi.registerCommand('mfb', {
    description: 'Model feedback: rephrase as a directive and append to the current model prompt file',
    handler: async (args, ctx) => {
      const feedback = args?.trim();
      if (!feedback) {
        ctx.ui.notify('Usage: /mfb <feedback>', 'warning');
        return;
      }

      const model = ctx.model;
      if (!model) {
        ctx.ui.notify('No active model to attach feedback to', 'warning');
        return;
      }

      // Stream through the registry provider: extension-registered providers
      // (e.g. claude-bridge) are unknown to pi-ai's standalone complete().
      const provider = ctx.modelRegistry.getProvider(model.provider);
      if (!provider) {
        ctx.ui.notify(`No provider registered for ${model.provider}`, 'error');
        return;
      }
      const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
      if (!auth.ok) {
        ctx.ui.notify(auth.error, 'error');
        return;
      }

      ctx.ui.notify(`Rephrasing feedback for ${model.id}...`, 'info');
      const response = await provider
        .stream(
          model,
          {
            messages: [
              {
                role: 'user',
                content: [{ type: 'text', text: buildRephrasePrompt(feedback) }],
                timestamp: Date.now(),
              },
            ],
          },
          { apiKey: auth.apiKey, headers: auth.headers, env: auth.env },
        )
        .result();

      const directive = response.content
        .filter((c): c is { type: 'text'; text: string } => c.type === 'text')
        .map((c) => c.text)
        .join('\n')
        .trim();
      if (!directive) {
        ctx.ui.notify('Model returned no directive; nothing written', 'error');
        return;
      }

      const file = await appendDirective(promptDir, model.id, directive);
      ctx.ui.notify(`Added to ${file}:\n- ${directive}`, 'info');
    },
  });
}
