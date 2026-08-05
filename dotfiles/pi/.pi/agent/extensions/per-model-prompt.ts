import { readFile } from 'node:fs/promises';
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

export default function (pi: ExtensionAPI, promptDir = join(homedir(), '.pi', 'agent', 'per-model-prompt')) {
  pi.on('before_agent_start', async (event, ctx) => {
    const modelId = ctx.model?.id;
    if (!modelId) return;

    const prompt = await loadModelPrompt(promptDir, modelId);
    if (!prompt) return;

    return { systemPrompt: `${event.systemPrompt}\n\n${prompt}` };
  });
}
