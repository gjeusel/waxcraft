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

/** System prompt section (XML tag) holding the active model's directives. */
export const PROMPT_SECTION = 'model-directives';

export default function (pi: ExtensionAPI, promptDir = join(homedir(), '.pi', 'agent', 'per-model-prompt')) {
  // A section, not a returned systemPrompt: Pi patches only changed sections in place (keeping the
  // cached prefix), whereas a returned prompt force-replaces the whole prompt for the run.
  pi.on('before_agent_start', async (event, ctx) => {
    const modelId = ctx.model?.id;
    if (!modelId) return;

    const prompt = await loadModelPrompt(promptDir, modelId);
    if (!prompt) return;

    event.systemPromptOptions.sections[PROMPT_SECTION] = prompt;
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

      ctx.ui.notify(`Rephrasing feedback for ${model.id}...`, 'info');

      // The registry resolves request-time auth and routes through the configured provider, so
      // extension overrides (e.g. Pi Black's OAuth compatibility wrapper) are preserved.
      let response: Awaited<ReturnType<typeof ctx.modelRegistry.complete>>;
      try {
        response = await ctx.modelRegistry.complete(model, {
          messages: [
            {
              role: 'user',
              content: [{ type: 'text', text: buildRephrasePrompt(feedback) }],
              timestamp: Date.now(),
            },
          ],
        });
      } catch (error) {
        ctx.ui.notify(`Rephrasing failed: ${error instanceof Error ? error.message : String(error)}`, 'error');
        return;
      }

      if (response.stopReason === 'error' || response.stopReason === 'aborted') {
        ctx.ui.notify(`Rephrasing failed: ${response.errorMessage ?? response.stopReason}`, 'error');
        return;
      }

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
