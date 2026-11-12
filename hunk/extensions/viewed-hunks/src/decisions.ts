// OpenAI Decisions API: one shared input, many typed questions, a number for each.
import type { HunkAnswers, NoiseRequest } from "./noise.ts";

const DECISIONS_URL = "https://api.openai.com/v1/decisions";
const MODEL = "gpt-6-luna";
const TIMEOUT_MS = 30_000;

export interface DecisionsOptions {
  apiKey: string;
  /** Aborted when the user cancels the run. */
  signal: AbortSignal;
  fetch?: typeof fetch;
}

/** The answers about each hunk, by hunk key; a question the model refused is left out. */
export async function askQuestions(
  request: NoiseRequest,
  options: DecisionsOptions,
): Promise<Map<string, HunkAnswers>> {
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
      questions: request.questions.map(({ name, body }) => ({ name, ...body })),
    }),
    signal: AbortSignal.any([options.signal, AbortSignal.timeout(TIMEOUT_MS)]),
  });

  const body = (await response.json().catch(() => null)) as {
    answers?: { type?: unknown; name?: unknown; probability?: unknown; score?: unknown }[];
    error?: { message?: unknown };
  } | null;

  if (!response.ok || !Array.isArray(body?.answers)) {
    const reason = body?.error?.message ?? "unexpected response";

    throw new Error(`OpenAI answered ${response.status}: ${String(reason)}`);
  }

  const questionByName = new Map(request.questions.map((question) => [question.name, question]));
  const answersByKey = new Map<string, HunkAnswers>();
  for (const answer of body.answers) {
    const question = questionByName.get(String(answer.name));
    const value = answer.type === "score" ? answer.score : answer.probability;
    if (!question || answer.type === "refusal" || typeof value !== "number") continue;

    const answers = answersByKey.get(question.key) ?? {};
    answers[question.kind] = value;
    answersByKey.set(question.key, answers);
  }

  return answersByKey;
}
