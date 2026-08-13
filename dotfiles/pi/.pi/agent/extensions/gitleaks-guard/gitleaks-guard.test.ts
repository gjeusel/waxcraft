import assert from 'node:assert/strict';
import test from 'node:test';
import guard, { redact, scan, type Finding } from './index.ts';

// Built at runtime so the raw string never sits in the repo and cannot
// itself trip secret scanners on this test file.
const fakeSecret = ['9TLHZJ32', 'OTZ0OGxlaDRaOGo2M2IyMnktdDhLM1QwdzlYLVc0OTBMY3kzcS1CYjZhcjNSNWYt'].join('.');
const leakyText = `x = 1\npassword="${fakeSecret}"\ny = 2\n`;

test('scan: clean text', () => {
  assert.deepEqual(scan('hello world, nothing to see here'), { status: 'clean' });
});

test('scan: detects a generic api key', () => {
  const result = scan(leakyText);
  assert.equal(result.status, 'leaks');
  assert.ok(result.status === 'leaks');
  assert.equal(result.findings[0].RuleID, 'generic-api-key');
  assert.equal(result.findings[0].Secret, fakeSecret);
});

test('redact: replaces every occurrence, keeps the rest', () => {
  const findings: Finding[] = [{ RuleID: 'generic-api-key', StartLine: 2, Secret: fakeSecret }];
  const out = redact(`${leakyText}again: ${fakeSecret}\n`, findings);
  assert.ok(!out.includes(fakeSecret));
  assert.equal(out.split('[REDACTED:generic-api-key]').length, 3);
  assert.ok(out.includes('x = 1'));
  assert.ok(out.includes('y = 2'));
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
  assert.ok(result.content[0].text.includes('[REDACTED:generic-api-key]'));
  assert.deepEqual(result.content[1], { type: 'image', data: 'abc' });
  assert.match(notifications.at(-1)!, /redacted 1 secret/);
});

test('tool_result handler: clean output passes through untouched', async () => {
  const { handlers, ctx } = setup();
  const toolResult = handlers.get('tool_result')!;
  const event = { toolName: 'bash', content: [{ type: 'text', text: 'all good' }] };
  assert.equal(await toolResult(event, ctx), undefined);
});
