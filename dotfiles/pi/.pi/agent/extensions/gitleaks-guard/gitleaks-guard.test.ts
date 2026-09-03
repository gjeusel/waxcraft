import assert from 'node:assert/strict';
import test from 'node:test';
import guard, { redact, redactWithCount, scan, type Finding } from './index.ts';

// Built at runtime so the raw string never sits in the repo and cannot
// itself trip secret scanners on this test file.
const fakeSecret = ['9TLHZJ32', 'OTZ0OGxlaDRaOGo2M2IyMnktdDhLM1QwdzlYLVc0OTBMY3kzcS1CYjZhcjNSNWYt'].join('.');
const leakyText = `x = 1\npassword="${fakeSecret}"\ny = 2\n`;

function finding(overrides: Partial<Finding> = {}): Finding {
  return {
    RuleID: 'generic-api-key',
    StartLine: 1,
    EndLine: 1,
    StartColumn: 1,
    EndColumn: 1,
    Secret: fakeSecret,
    Tags: [],
    ...overrides,
  };
}

const encodedCases = [
  ['base64', (text: string) => Buffer.from(text, 'utf8').toString('base64')],
  ['hex', (text: string) => Buffer.from(text, 'utf8').toString('hex')],
  [
    'percent',
    (text: string) => [...Buffer.from(text, 'utf8')].map((byte) => `%${byte.toString(16).padStart(2, '0')}`).join(''),
  ],
] as const;

test('scan: clean text', () => {
  assert.deepEqual(scan('hello world, nothing to see here'), { status: 'clean' });
});

test('scan: detects a generic api key', () => {
  const result = scan(leakyText);
  assert.equal(result.status, 'leaks');
  assert.ok(result.status === 'leaks');
  assert.equal(result.findings[0].RuleID, 'generic-api-key');
  assert.equal(result.findings[0].Secret, fakeSecret);
  assert.ok(result.findings[0].EndLine >= result.findings[0].StartLine);
  assert.ok(result.findings[0].EndColumn >= result.findings[0].StartColumn);
  assert.deepEqual(result.findings[0].Tags, []);
});

test('scan and redact: detects a secret in a Python type-annotated default', () => {
  const annotatedSecret = ['k7R9_mN2', 'pQ4_vX8', 'zB6_hJ3', 'sW5_tC1'].join('-');
  const text = `client_secret: str = "${annotatedSecret}"`;
  const result = scan(text);
  assert.equal(result.status, 'leaks');
  assert.ok(result.status === 'leaks');
  assert.equal(result.findings[0].RuleID, 'python-annotated-secret');
  assert.equal(result.findings[0].Secret, annotatedSecret);
  assert.equal(redact(text, result.findings), 'client_secret: str = "[REDACTED:python-annotated-secret]"'); // gitleaks:allow
});

for (const [encoding, encode] of encodedCases) {
  test(`scan and redact: ${encoding}-encoded secret`, () => {
    const encoded = encode(leakyText);
    const result = scan(encoded);
    assert.equal(result.status, 'leaks');
    assert.ok(result.status === 'leaks');
    assert.ok(result.findings.some((item) => item.Tags.includes(`decoded:${encoding}`)));

    const redaction = redactWithCount(encoded, result.findings);
    assert.equal(redaction.suppressed, undefined);
    assert.ok(redaction.count > 0);
    assert.match(redaction.text, /\[REDACTED:generic-api-key]/);
    assert.equal(scan(redaction.text).status, 'clean');
  });
}

test('redact: replaces every occurrence, keeps the rest', () => {
  const out = redact(`${leakyText}again: ${fakeSecret}\n`, [finding({ StartLine: 2 })]);
  assert.ok(!out.includes(fakeSecret));
  assert.equal(out.split('[REDACTED:generic-api-key]').length, 3);
  assert.ok(out.includes('x = 1'));
  assert.ok(out.includes('y = 2'));
});

test('redactWithCount counts actual replacements instead of overlapping findings', () => {
  const text = 'token=abcdefghijk';
  const findings = [finding({ Secret: 'abcdefghijk' }), finding({ Secret: 'defgh' })];

  assert.deepEqual(redactWithCount(text, findings), {
    text: 'token=[REDACTED:generic-api-key]',
    count: 1,
  });
});

test('redactWithCount counts repeated occurrences of one finding', () => {
  assert.deepEqual(redactWithCount('abcdefghijk and abcdefghijk', [finding({ Secret: 'abcdefghijk' })]), {
    text: '[REDACTED:generic-api-key] and [REDACTED:generic-api-key]',
    count: 2,
  });
});

test('redactWithCount maps byte-based source spans across lines and Unicode', () => {
  const text = 'prefix\né🙂 encoded suffix\ntail';
  const result = redactWithCount(text, [
    finding({
      RuleID: 'decoded-rule',
      StartLine: 2,
      EndLine: 2,
      StartColumn: 9,
      EndColumn: 15,
      Secret: 'decoded value absent from source',
      Tags: ['decoded:base64', 'decode-depth:1'],
    }),
  ]);

  assert.deepEqual(result, {
    text: 'prefix\né🙂 [REDACTED:decoded-rule] suffix\ntail',
    count: 1,
  });
});

test('redactWithCount merges overlapping source spans', () => {
  const result = redactWithCount('0123456789', [
    finding({ RuleID: 'first', StartColumn: 3, EndColumn: 7, Secret: 'absent-first' }),
    finding({ RuleID: 'second', StartColumn: 5, EndColumn: 9, Secret: 'absent-second' }),
  ]);

  assert.deepEqual(result, {
    text: '01[REDACTED:first+second]9',
    count: 1,
  });
});

test('redactWithCount suppresses the whole block when a finding cannot be mapped', () => {
  assert.deepEqual(
    redactWithCount('safe-looking source', [
      finding({ StartLine: 99, EndLine: 99, Secret: 'decoded value absent from source' }),
    ]),
    {
      text: '[REDACTED:gitleaks-unmappable-finding]',
      count: 1,
      suppressed: true,
    },
  );
});

type Handler = (event: any, ctx: any) => Promise<any>;

function setup() {
  const handlers = new Map<string, Handler>();
  const notifications: string[] = [];
  const pi = { on: (event: string, handler: Handler) => handlers.set(event, handler) };
  const ctx = { ui: { notify: (msg: string) => notifications.push(msg) } };
  guard(pi as any);
  return { handlers, notifications, ctx };
}

test('input handler: blocks secrets, verbatim resubmit bypasses', async () => {
  const { handlers, notifications, ctx } = setup();
  const input = handlers.get('input')!;

  assert.deepEqual(await input({ text: 'benign prompt' }, ctx), { action: 'continue' });
  assert.deepEqual(await input({ text: leakyText }, ctx), { action: 'handled' });
  assert.match(notifications.at(-1)!, /BLOCKED/);
  assert.ok(!notifications.at(-1)!.includes(fakeSecret));
  assert.deepEqual(await input({ text: leakyText }, ctx), { action: 'continue' });
  assert.match(notifications.at(-1)!, /bypassed/);
});

test('tool_result handler: redacts secrets in text blocks', async () => {
  const { handlers, notifications, ctx } = setup();
  const toolResult = handlers.get('tool_result')!;

  const event = {
    toolName: 'read',
    content: [
      { type: 'text', text: leakyText },
      { type: 'image', data: 'abc' },
    ],
  };
  const result = await toolResult(event, ctx);
  assert.ok(result);
  assert.ok(!result.content[0].text.includes(fakeSecret));
  assert.match(result.content[0].text, /\[REDACTED:[^\]]*generic-api-key/);
  assert.deepEqual(result.content[1], { type: 'image', data: 'abc' });
  assert.match(notifications.at(-1)!, /redacted 1 secret/);
});

test('tool_result handler: redacts an encoded secret through its source span', async () => {
  const { handlers, notifications, ctx } = setup();
  const toolResult = handlers.get('tool_result')!;
  const encoded = Buffer.from(leakyText, 'utf8').toString('base64');

  const result = await toolResult({ toolName: 'bash', content: [{ type: 'text', text: encoded }] }, ctx);
  assert.ok(result);
  assert.ok(!result.content[0].text.includes(encoded));
  assert.match(result.content[0].text, /\[REDACTED:generic-api-key]/);
  assert.equal(scan(result.content[0].text).status, 'clean');
  assert.match(notifications.at(-1)!, /redacted 1 secret/);
});

test('tool_result handler: clean output passes through untouched', async () => {
  const { handlers, ctx } = setup();
  const toolResult = handlers.get('tool_result')!;
  const event = { toolName: 'bash', content: [{ type: 'text', text: 'all good' }] };
  assert.equal(await toolResult(event, ctx), undefined);
});
