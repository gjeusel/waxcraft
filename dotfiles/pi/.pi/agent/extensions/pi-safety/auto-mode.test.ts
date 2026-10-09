import assert from 'node:assert/strict';
import test from 'node:test';
import type { SessionEntry } from '@earendil-works/pi-coding-agent';
import {
  adjudicate,
  buildTranscript,
  AUTO_MODE_SOURCES,
  classify,
  describeBashCall,
  VERDICT_QUESTIONS,
  VERDICTS,
  type AutoModeSource,
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

function responseFetch(body: unknown, status = 200): typeof fetch {
  return async () => new Response(typeof body === 'string' ? body : JSON.stringify(body), { status });
}

function decisionResponse(source: AutoModeSource, overrides: Record<string, unknown> = {}) {
  const probabilities = { allow: 0.9, ask: 0.08, deny: 0.02 };
  const answer = {
    type: 'choice',
    choice: 'allow',
    confidence: 0.85,
    probabilities: source === 'jev'
      ? probabilities
      : VERDICTS.map((value) => ({ value, probability: probabilities[value] })),
    ...overrides,
  };

  return source === 'jev' ? { answers: { verdict: answer } } : { answers: [{ name: 'verdict', ...answer }] };
}

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

for (const source of AUTO_MODE_SOURCES) {
  test(`${source}: posts the decisions request and normalizes the answer`, async () => {
    let captured: { url: string; init: RequestInit } | undefined;
    const fetcher: typeof fetch = async (url, init) => {
      captured = { url: String(url), init: init! };
      return new Response(JSON.stringify(decisionResponse(source)));
    };

    const state = 'User: hi\nbash: ls';
    const result = await classify(state, { source, apiKey: 'k', fetcher });

    assert.equal(captured?.url, source === 'jev' ? 'https://api.typesafe.ai/v1/systemone' : 'https://api.openai.com/v1/decisions');
    assert.equal(captured?.init.method, 'POST');
    assert.deepEqual(captured?.init.headers, { authorization: 'Bearer k', 'content-type': 'application/json' });
    assert.ok(captured?.init.signal instanceof AbortSignal);
    assert.deepEqual(JSON.parse(captured?.init.body as string), source === 'jev' ? {
      model: 'jev-latest', state, questions: VERDICT_QUESTIONS,
    } : {
      model: 'gpt-6-luna',
      input: state,
      questions: [{
        type: 'choice',
        name: 'verdict',
        instructions: VERDICT_QUESTIONS.verdict.instructions,
        choices: VERDICTS.map((value) => ({ value, description: VERDICT_QUESTIONS.verdict.criteria[value] })),
      }],
    });
    assert.deepEqual(result, { verdict: 'allow', confidence: 0.85, probabilities: { allow: 0.9, ask: 0.08, deny: 0.02 } });
  });

  test(`${source}: rejects HTTP errors, invalid JSON, and malformed answers`, async () => {
    await assert.rejects(classify('s', { source, apiKey: 'k', fetcher: responseFetch('nope', 401) }), new RegExp(`${source} 401`));
    await assert.rejects(classify('s', { source, apiKey: 'k', fetcher: responseFetch('not json') }), /malformed JSON/);

    for (const body of [null, [], {}, { answers: [] }, { answers: null }]) {
      const outcome = await adjudicate('s', { source, apiKey: 'k', fetcher: responseFetch(body) });
      assert.equal(outcome.source, 'fail-closed');
      assert.equal(outcome.verdict, 'deny');
    }

    for (const overrides of [
      { type: 'score' }, { choice: 'maybe' }, { confidence: undefined },
      { confidence: '0.9' }, { confidence: -0.1 }, { confidence: 1.1 }, { confidence: NaN },
      { probabilities: undefined }, { probabilities: { allow: 1, ask: 0 } },
    ]) {
      const outcome = await adjudicate('s', { source, apiKey: 'k', fetcher: responseFetch(decisionResponse(source, overrides)) });
      assert.equal(outcome.source, 'fail-closed', JSON.stringify(overrides));
      assert.equal(outcome.verdict, 'deny');
    }
  });

  test(`${source}: distinguishes a refusal from service failure without retrying`, async () => {
    let calls = 0;
    const fetcher: typeof fetch = async () => {
      calls += 1;
      return new Response(JSON.stringify(decisionResponse(source, { type: 'refusal' })), {
        headers: { 'x-request-id': 'req_example' },
      });
    };
    const outcome = await adjudicate('private transcript', { source, apiKey: 'k', fetcher });

    assert.deepEqual(outcome, {
      verdict: 'ask', source: 'refusal',
      reason: `classification refused (${source}; no reason supplied; request req_example)`,
    });
    assert.equal(calls, 1);
    assert.doesNotMatch(outcome.reason, /unavailable|private transcript/);
  });

  test(`${source}: honours timeout and caller cancellation`, async () => {
    const fetcher: typeof fetch = (_url, init) => new Promise((_resolve, reject) => {
      const signal = init!.signal!;
      signal.throwIfAborted();
      // Keep the test alive: AbortSignal.timeout's own timer is unref'ed.
      const timer = setTimeout(() => reject(new Error('timeout was not honoured')), 1000);
      signal.addEventListener('abort', () => {
        clearTimeout(timer);
        reject(signal.reason);
      }, { once: true });
    });
    await assert.rejects(classify('s', { source, apiKey: 'k', fetcher, timeoutMs: 20 }), /TimeoutError|timed out/i);

    const signal = AbortSignal.abort(new Error('caller cancelled'));
    await assert.rejects(classify('s', { source, apiKey: 'k', fetcher, signal }), /caller cancelled/);
  });

  test(`${source}: reports the backend and uses confidence, not the chosen probability`, async () => {
    const outcome = await adjudicate('s', { source, apiKey: 'k', fetcher: responseFetch(decisionResponse(source)) });
    assert.equal(outcome.verdict, 'allow');
    assert.equal(outcome.source, source);
    assert.equal(outcome.reason, `${source}: allow 90% (confidence 85%; ask 8%, deny 2%)`);

    for (const choice of ['allow', 'deny']) {
      const fetcher = responseFetch(decisionResponse(source, { choice, confidence: 0.29 }));
      const hesitant = await adjudicate('s', { source, apiKey: 'k', fetcher, minConfidence: 0.5 });
      assert.equal(hesitant.verdict, 'ask');
      assert.equal(hesitant.source, 'low-confidence');
      assert.match(hesitant.reason, /below confidence floor 50%/);

      const trusted = await adjudicate('s', { source, apiKey: 'k', fetcher, minConfidence: 0.29 });
      assert.equal(trusted.verdict, choice);
      assert.equal(trusted.source, source);
    }

    const ask = await adjudicate('s', {
      source, apiKey: 'k', fetcher: responseFetch(decisionResponse(source, { choice: 'ask', confidence: 0 })),
    });
    assert.equal(ask.verdict, 'ask');
    assert.equal(ask.source, source);
  });

  test(`${source}: default confidence policy preserves allow, ask, and deny even at zero confidence`, async () => {
    for (const choice of VERDICTS) {
      const outcome = await adjudicate('s', {
        source, apiKey: 'k', fetcher: responseFetch(decisionResponse(source, { choice, confidence: 0 })),
      });
      assert.equal(outcome.verdict, choice);
      assert.equal(outcome.source, source);
      assert.doesNotMatch(outcome.reason, /below confidence floor/);
    }
  });

  test(`${source}: fails closed without retrying or falling back to another backend`, async () => {
    let calls = 0;
    const fetcher: typeof fetch = async () => {
      calls += 1;
      throw new Error('ECONNREFUSED');
    };
    const outcome = await adjudicate('s', { source, apiKey: 'k', fetcher });
    assert.equal(outcome.verdict, 'deny');
    assert.equal(outcome.source, 'fail-closed');
    assert.match(outcome.reason, /classifier unavailable \(ECONNREFUSED\)/);
    assert.equal(calls, 1);
  });
}

test('refusal diagnostics omit unsafe request IDs', async () => {
  const outcome = await adjudicate('s', {
    apiKey: 'k', fetcher: async () => new Response(JSON.stringify({ answers: [{ type: 'refusal', name: 'verdict' }] }), {
      headers: { 'x-request-id': 'not an opaque identifier' },
    }),
  });
  assert.equal(outcome.reason, 'classification refused (openai; no reason supplied)');
});

test('OpenAI is the default source', async () => {
  const fetcher: typeof fetch = async (url) => {
    assert.equal(url, 'https://api.openai.com/v1/decisions');
    return new Response(JSON.stringify(decisionResponse('openai')));
  };
  const outcome = await adjudicate('s', { apiKey: 'k', fetcher });
  assert.equal(outcome.verdict, 'allow');
  assert.equal(outcome.source, 'openai');
});

test('OpenAI rejects misnamed, duplicate, and incomplete answers or probabilities', async () => {
  const valid = { name: 'verdict', type: 'choice', choice: 'allow', confidence: 0.9 };
  for (const answers of [
    [{ ...valid, name: 'other' }],
    [valid, valid],
    [{ ...valid, probabilities: [{ value: 'allow', probability: 1 }] }],
    [{ ...valid, probabilities: VERDICTS.map(() => ({ value: 'allow', probability: 1 })) }],
    [{ ...valid, probabilities: [{ value: 'other', probability: 1 }] }],
    ...[-1, 1.1, null, '0.9'].map((probability) => [{
      ...valid, probabilities: VERDICTS.map((value) => ({ value, probability })),
    }]),
  ]) {
    await assert.rejects(classify('s', { apiKey: 'k', fetcher: responseFetch({ answers }) }), /malformed/);
  }
});
