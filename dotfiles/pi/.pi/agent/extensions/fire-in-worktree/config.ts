import { readFileSync } from 'node:fs';

const MODEL_REF = /^[^/]+\/./;

export type Review = 'standard' | 'thorough' | 'none';

export interface Reviewers {
  standard: string;
  thorough: string;
}

/**
 * fire.json: the agent's default model (the launching session's when absent), the default model of
 * the subagents it delegates implementation to (no delegation when absent), and the reviewer models
 * by the agent's provider, `default` for the others, so that the review runs on another provider
 * than the agent.
 */
export interface FireConfig {
  model?: string;
  workerModel?: string;
  reviewers: Record<string, Reviewers>;
}

/** Throws on a missing file, invalid JSON, or a malformed value. */
export function loadConfig(path: string): FireConfig {
  const parsed = JSON.parse(readFileSync(path, 'utf8')) as Record<string, unknown> | null;
  for (const key of ['model', 'workerModel'] as const) {
    const model = parsed?.[key];
    if (model !== undefined && (typeof model !== 'string' || !MODEL_REF.test(model))) {
      throw new Error(`${path}: ${key} must be "provider/modelId"`);
    }
  }

  const reviewers = parsed?.reviewers;
  if (typeof reviewers !== 'object' || reviewers === null || Array.isArray(reviewers)) {
    throw new Error(`${path}: expected {"reviewers": {"<provider>" | "default": {"standard", "thorough"}}}`);
  }

  for (const [provider, models] of Object.entries(reviewers)) {
    for (const review of ['standard', 'thorough'] as const) {
      const model = (models as Record<string, unknown> | null)?.[review];
      if (typeof model !== 'string' || !MODEL_REF.test(model)) {
        throw new Error(`${path}: reviewers.${provider}.${review} must be "provider/modelId"`);
      }
    }
  }

  return {
    model: parsed?.model as string | undefined,
    workerModel: parsed?.workerModel as string | undefined,
    reviewers: reviewers as Record<string, Reviewers>,
  };
}

export function reviewersFor(config: FireConfig, provider: string): Reviewers {
  const reviewers = config.reviewers[provider] ?? config.reviewers.default;
  if (!reviewers) throw new Error(`fire.json has no reviewers for provider ${provider}, nor a default`);

  return reviewers;
}
