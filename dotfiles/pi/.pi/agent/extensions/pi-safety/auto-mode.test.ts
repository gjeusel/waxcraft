import assert from 'node:assert/strict';
import test from 'node:test';
import type { SessionEntry } from '@earendil-works/pi-coding-agent';
import {
  adjudicate,
  buildTranscript,
  classifyWithJev,
  describeBashCall,
  JEV_MODEL,
  JEV_URL,
  VERDICT_QUESTIONS,
} from './auto-mode.ts';

function userEntry(text: string): SessionEntry {
  return { type: 'message', id: 'u', parentId: null, timestamp: '', message: { role: 'user', content: text, timestamp: 0 } };
}

function toolCallEntry(name: string, args: Record<string, string>): SessionEntry {
  return {
    type: 'message',
    id: 'a',
    parentId: null,
    timestamp: '',
    message: {
      role: 'assistant',
      content: [
        { type: 'text', text: 'narration that must not appear' },
        { type: 'toolCall', id: 't', name, arguments: args },
      ],
      api: 'openai-responses',
      provider: 'openai',
      model: 'm',
      usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } },
      stopReason: 'toolUse',
      timestamp: 0,
    },
  };
}

function jevResponse(body: unknown, status = 200): typeof fetch {
  return async () => new Response(typeof body === 'string' ? body : JSON.stringify(body), { status });
}

const allowAnswer = {
  model: 'jev-1.13.0',
  answers: { verdict: { type: 'choice', choice: 'allow', probabilities: { allow: 0.9, ask: 0.08, deny: 0.02 }, confidence: 0.85 } },
  usage: { input_tokens: 10, output_tokens: 1 },
};

test('buildTranscript keeps user messages and tool calls, escapes line breaks, and ends with the action', () => {
  const entries = [
    userEntry('run the tests\nplease'),
    toolCallEntry('read', { path: '/tmp/x' }),
    toolCallEntry('bash', { command: 'echo hi' }),
  ];
  const action = describeBashCall('npm test');
  const transcript = buildTranscript(entries, action);

  assert.deepEqual(transcript.split('\n'), ['User: run the tests\\nplease', 'read: /tmp/x', 'bash: echo hi', 'bash: npm test']);
});

test('buildTranscript drops the reviewed call when already recorded, and caps history', () => {
  const entries: SessionEntry[] = [];
  for (let index = 0; index < 8; index += 1) entries.push(userEntry(`message ${index}`));
  for (let index = 0; index < 15; index += 1) entries.push(toolCallEntry('bash', { command: `cmd ${index}` }));
  entries.push(toolCallEntry('bash', { command: 'npm test' }));
  const lines = buildTranscript(entries, describeBashCall('npm test')).split('\n');

  assert.equal(lines.filter((line) => line.startsWith('User:')).length, 5);
  assert.equal(lines[0], 'User: message 3');
  assert.equal(lines.filter((line) => line === 'bash: npm test').length, 1);
  assert.equal(lines.length, 5 + 10 + 1);
  assert.equal(lines.at(-1), 'bash: npm test');
});

test('buildTranscript truncates long entries and strips zero-width characters', () => {
  const lines = buildTranscript([userEntry(`a\u200Bb${'x'.repeat(2000)}`)], 'bash: ls').split('\n');
  assert.match(lines[0], /^User: abx+…\[truncated\]…x+$/);
  assert.ok(lines[0].length < 1100);
});

test('classifyWithJev posts the decisions request and parses the answer', async () => {
  let captured: { url: string; init: RequestInit } | undefined;
  const fetcher: typeof fetch = async (url, init) => {
    captured = { url: String(url), init: init! };
    return new Response(JSON.stringify(allowAnswer));
  };

  const result = await classifyWithJev('User: hi\nbash: ls', { apiKey: 'k', fetcher });

  assert.equal(captured?.url, JEV_URL);
  assert.equal((captured?.init.headers as Record<string, string>).authorization, 'Bearer k');
  assert.deepEqual(JSON.parse(captured?.init.body as string), {
    model: JEV_MODEL,
    state: 'User: hi\nbash: ls',
    questions: VERDICT_QUESTIONS,
  });
  assert.deepEqual(result, { verdict: 'allow', confidence: 0.85, probabilities: { allow: 0.9, ask: 0.08, deny: 0.02 } });
});

test('classifyWithJev throws on HTTP errors and malformed shapes', async () => {
  await assert.rejects(classifyWithJev('s', { apiKey: 'k', fetcher: jevResponse({ error: 'nope' }, 401) }), /jev 401/);
  await assert.rejects(classifyWithJev('s', { apiKey: 'k', fetcher: jevResponse('not json') }), /malformed JSON/);
  await assert.rejects(
    classifyWithJev('s', { apiKey: 'k', fetcher: jevResponse({ answers: { verdict: { choice: 'maybe', confidence: 1 } } }) }),
    /malformed verdict \(choice/,
  );
  await assert.rejects(
    classifyWithJev('s', { apiKey: 'k', fetcher: jevResponse({ answers: { verdict: { choice: 'allow' } } }) }),
    /malformed verdict \(confidence/,
  );
});

test('classifyWithJev honours the timeout', async () => {
  const fetcher: typeof fetch = (_url, init) =>
    new Promise((_resolve, reject) => {
      init!.signal!.addEventListener('abort', () => reject(init!.signal!.reason));
    });
  await assert.rejects(classifyWithJev('s', { apiKey: 'k', fetcher, timeoutMs: 20 }), /TimeoutError|timed out/i);
});

test('adjudicate trusts confident verdicts and reports probabilities', async () => {
  const outcome = await adjudicate('s', { apiKey: 'k', fetcher: jevResponse(allowAnswer) });
  assert.equal(outcome.verdict, 'allow');
  assert.equal(outcome.source, 'jev');
  assert.equal(outcome.reason, 'jev: allow 90% (confidence 85%; ask 8%, deny 2%)');
});

test('adjudicate demotes low-confidence allow/deny to ask', async () => {
  const hesitantDeny = {
    answers: { verdict: { choice: 'deny', probabilities: { deny: 0.64, allow: 0.36, ask: 0 }, confidence: 0.29 } },
  };
  const outcome = await adjudicate('s', { apiKey: 'k', fetcher: jevResponse(hesitantDeny) });
  assert.equal(outcome.verdict, 'ask');
  assert.equal(outcome.source, 'low-confidence');
  assert.match(outcome.reason, /jev: deny 64% \(confidence 29%; allow 36%, ask 0%\); below confidence floor 50%/);

  const trusted = await adjudicate('s', { apiKey: 'k', fetcher: jevResponse(hesitantDeny), minConfidence: 0.2 });
  assert.equal(trusted.verdict, 'deny');
  assert.equal(trusted.source, 'jev');
});

test('adjudicate fails closed when the classifier is unreachable', async () => {
  const fetcher: typeof fetch = async () => {
    throw new Error('ECONNREFUSED');
  };
  const outcome = await adjudicate('s', { apiKey: 'k', fetcher });
  assert.equal(outcome.verdict, 'deny');
  assert.equal(outcome.source, 'fail-closed');
  assert.match(outcome.reason, /classifier unavailable \(ECONNREFUSED\)/);
});
