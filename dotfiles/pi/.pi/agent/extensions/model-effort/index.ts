import { readFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join } from 'node:path';
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';

export type EffortLevel = 'off' | 'minimal' | 'low' | 'medium' | 'high' | 'xhigh' | 'max';
export type ModelEffortDefaults = Record<string, EffortLevel>;

const EFFORT_LEVELS = new Set<EffortLevel>(['off', 'minimal', 'low', 'medium', 'high', 'xhigh', 'max']);

export async function loadModelEffortDefaults(settingsPath: string): Promise<ModelEffortDefaults> {
  const settings = JSON.parse(await readFile(settingsPath, 'utf8')) as { modelEffortDefaults?: unknown };
  const defaults = settings.modelEffortDefaults;
  if (defaults === undefined) return {};
  if (defaults === null || typeof defaults !== 'object' || Array.isArray(defaults)) {
    throw new Error('settings.json modelEffortDefaults must be an object');
  }

  for (const [pattern, effort] of Object.entries(defaults)) {
    if (pattern.length === 0 || typeof effort !== 'string' || !EFFORT_LEVELS.has(effort as EffortLevel)) {
      throw new Error(`Invalid modelEffortDefaults entry: ${pattern || '<empty>'}`);
    }
  }
  return defaults as ModelEffortDefaults;
}

function matches(pattern: string, value: string): boolean {
  const expression = pattern.replace(/[.+?^${}()|[\]\\]/g, '\\$&').replaceAll('*', '.*');
  return new RegExp(`^${expression}$`).test(value);
}

export function effortForModel(
  provider: string,
  modelId: string,
  defaults: ModelEffortDefaults,
): EffortLevel | undefined {
  const qualifiedId = `${provider}/${modelId}`;
  const match = Object.entries(defaults).find(
    ([pattern]) => matches(pattern, modelId) || matches(pattern, qualifiedId),
  );
  return match?.[1];
}

export default async function modelEffort(
  pi: ExtensionAPI,
  settingsPath = join(homedir(), '.pi', 'agent', 'settings.json'),
): Promise<void> {
  const defaults = await loadModelEffortDefaults(settingsPath);
  pi.on('model_select', (event) => {
    const effort = effortForModel(event.model.provider, event.model.id, defaults);
    if (effort !== undefined) pi.setThinkingLevel(effort);
  });
}
