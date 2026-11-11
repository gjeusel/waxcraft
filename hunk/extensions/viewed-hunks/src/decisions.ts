// OpenAI Decisions API: one shared input, many yes/no questions, a probability for each.
import type { NoiseRequest } from "./noise.ts";

const DECISIONS_URL = "https://api.openai.com/v1/decisions";
const MODEL = "gpt-6-luna";
const TIMEOUT_MS = 30_000;

export interface DecisionsOptions {
  apiKey: string;
  /** Aborted when the user cancels the run. */
  signal: AbortSignal;
  fetch?: typeof fetch;
}

/** The probability that each hunk is noise, by hunk key; a hunk the model refused is left out. */
export async function askNoise(
  request: NoiseRequest,
  options: DecisionsOptions,
): Promise<Map<string, number>> {
  const send = options.fetch ?? fetch;
  const response = await send(DECISIONS_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${options.apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: MODEL,
      input: request.input,
      questions: request.questions.map(({ name, instructions }) => ({
        type: "predicate",
        name,
        instructions,
      })),
    }),
    signal: AbortSignal.any([options.signal, AbortSignal.timeout(TIMEOUT_MS)]),
  });

  const body = (await response.json().catch(() => null)) as {
    answers?: { type?: unknown; name?: unknown; probability?: unknown }[];
    error?: { message?: unknown };
  } | null;

  if (!response.ok || !Array.isArray(body?.answers)) {
    const reason = body?.error?.message ?? "unexpected response";

    throw new Error(`OpenAI answered ${response.status}: ${String(reason)}`);
  }

  const keyByName = new Map(request.questions.map(({ name, key }) => [name, key]));
  const probabilities = new Map<string, number>();
  for (const answer of body.answers) {
    const key = keyByName.get(String(answer.name));
    const isUsable = answer.type === "predicate" && typeof answer.probability === "number";
    if (key !== undefined && isUsable) probabilities.set(key, answer.probability as number);
  }

  return probabilities;
}
