import assert from 'node:assert/strict';
import { createHash, webcrypto } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { homedir, tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import test from 'node:test';
import { runInNewContext } from 'node:vm';

const require = createRequire(new URL('../extensions/package.json', import.meta.url));
const ts = require('typescript');
const agentDir = process.env.PI_CODING_AGENT_DIR || join(homedir(), '.pi/agent');
const packagePath = 'git/github.com/paoloanzn/pi-black';
const sourcePath = join(agentDir, packagePath, 'src/claude-code-protocol.ts');
const source = readFileSync(sourcePath, 'utf8');
const { outputText } = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
});
const exports = {};
runInNewContext(outputText, {
  exports, require, crypto: webcrypto, TextEncoder, Headers, Request, structuredClone,
}, { filename: sourcePath });

const messages = [{ role: 'user', content: 'Reply with exactly: PROBE_OK', timestamp: 1 }];

test('Pi Black advertises 2.1.280 consistently in headers and prompt fingerprints', async () => {
  assert.equal(exports.CLAUDE_CODE_VERSION, '2.1.280');
  assert.equal(exports.claudeCodeHeaders()['user-agent'], 'claude-cli/2.1.280 (external, sdk-cli)');

  const selected = [4, 7, 20].map(index => messages[0].content[index]).join('');
  const expected = createHash('sha256').update(`59cf53e54c78${selected}2.1.280`)
    .digest('hex').slice(0, 3);
  assert.equal(expected, '022');
  assert.equal(await exports.claudeCodeVersionFingerprint(messages), expected);
  assert.equal(await exports.buildClaudeCodeBillingHeader(messages),
    `x-anthropic-billing-header: cc_version=2.1.280.${expected}; cc_entrypoint=sdk-cli; cch=00000;`);
});

test('the patched billing block survives final request checksum generation', async () => {
  const payload = await exports.transformClaudeCodePayload({
    model: 'claude-opus-5-5', max_tokens: 128, messages: [],
  }, { messages }, undefined, undefined);
  const body = exports.patchClaudeCodeCch(JSON.stringify(payload));
  assert.match(JSON.parse(body).system[0].text, /cc_version=2\.1\.280\.022;.*cch=[0-9a-f]{5};$/);
  assert.doesNotMatch(JSON.parse(body).system[0].text, /cch=00000/);
  assert.equal(exports.patchClaudeCodeCch(body), body);
});

test('Fast mode survives native Anthropic SDK serialization and Black OAuth checksumming', { timeout: 10_000 }, async () => {
  const modules = [
    fileURLToPath(new URL('../extensions/pi-openai/fast.ts', import.meta.url)),
    join(agentDir, packagePath, 'src/anthropic-provider.ts'),
  ].map(path => {
    const moduleExports = {};
    const { outputText } = ts.transpileModule(readFileSync(path, 'utf8'), {
      compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
    });
    runInNewContext(outputText, {
      exports: moduleExports, URL,
      require: name => name === './claude-code-protocol.ts' ? exports : require(name),
    }, { filename: path });

    return moduleExports;
  });
  const [fast, black] = modules;
  const npmRoot = spawnSync('npm', ['root', '--global'], { encoding: 'utf8', timeout: 5_000 });
  assert.equal(npmRoot.status, 0, npmRoot.stderr || npmRoot.error?.message);
  const nativePath = join(npmRoot.stdout.trim(), '@earendil-works/pi-coding-agent',
    'node_modules/@earendil-works/pi-ai/dist/providers/anthropic.js');
  const { anthropicProvider } = await import(pathToFileURL(nativePath).href);
  const native = anthropicProvider();
  const models = native.getModels();
  const model = models.find(fast.isAnthropicFastModel);
  assert.ok(model, 'installed catalog needs a model on the official Anthropic Messages endpoint');
  // A resolved empty identity avoids reading actual Claude Code account state.
  const provider = black.wrapAnthropicProvider(native, Promise.resolve(undefined));

  for (const oauth of [true, false]) {
    for (const enabled of [true, false]) {
      const label = `${oauth ? 'OAuth' : 'API key'}, fast ${enabled ? 'on' : 'off'}`;
      const requests = [];
      let nativeBetas;
      const events = [
        { type: 'message_start', message: {
          id: 'msg_synthetic', type: 'message', role: 'assistant', model: model.id, content: [],
          stop_reason: null, stop_sequence: null,
          usage: { input_tokens: 1, output_tokens: 0, speed: enabled ? 'fast' : 'standard' },
        } },
        { type: 'message_delta', delta: { stop_reason: 'end_turn', stop_sequence: null },
          usage: { output_tokens: 0 } },
        { type: 'message_stop' },
      ];
      const result = await provider.streamSimple(model, { messages }, {
        apiKey: oauth ? 'sk-ant-oat-synthetic' : 'sk-ant-api-synthetic',
        sessionId: 'synthetic-session', maxTokens: 16, maxRetries: 0,
        onPayload: (payload, requestModel) => {
          nativeBetas = [...(payload.betas ?? [])];
          return fast.rewriteFastPayload(payload, requestModel, enabled);
        },
        fetch: async (input, init) => {
          requests.push({ input, init });
          return new Response(events.map(event =>
            `event: ${event.type}\ndata: ${JSON.stringify(event)}\n\n`).join(''), {
            headers: { 'content-type': 'text/event-stream' },
          });
        },
      }).result();

      assert.equal(result.stopReason, 'stop', `${label}: ${result.errorMessage ?? ''}`);
      assert.equal(requests.length, 1, label);
      const [{ input, init }] = requests;
      assert.equal(String(input), 'https://api.anthropic.com/v1/messages?beta=true', label);
      assert.equal(typeof init.body, 'string', label);
      const body = JSON.parse(init.body);
      const headers = new Headers(init.headers);
      assert.equal(body.speed, enabled ? 'fast' : undefined, label);
      assert.equal('betas' in body, false, label);
      const expectedBetas = [...new Set([...nativeBetas, ...(enabled ? ['fast-mode-2026-02-01'] : [])])];
      assert.deepEqual((headers.get('anthropic-beta') ?? '').split(',').filter(Boolean), expectedBetas, label);

      if (oauth) {
        assert.ok(nativeBetas.includes('claude-code-20250219'), label);
        assert.ok(nativeBetas.includes('oauth-2025-04-20'), label);
        assert.equal(headers.get('authorization'), 'Bearer sk-ant-oat-synthetic', label);
        assert.equal(headers.get('user-agent'), 'claude-cli/2.1.280 (external, sdk-cli)', label);
        assert.equal(headers.get('x-app'), 'cli', label);
        assert.equal(headers.get('x-claude-code-session-id'), 'synthetic-session', label);
        assert.match(headers.get('x-client-request-id'), /^[0-9a-f-]{36}$/u, label);
        const billing = body.system[0].text;
        assert.match(billing, /^x-anthropic-billing-header: cc_version=2\.1\.280\.[0-9a-f]{3};.*cch=[0-9a-f]{5};$/u, label);
        assert.doesNotMatch(billing, /cch=00000/u, label);
        assert.equal(body.system[1].text, "You are a Claude agent, built on Anthropic's Claude Agent SDK.", label);
        body.system[0].text = billing.replace(/cch=[0-9a-f]{5}/u, 'cch=00000');
        assert.equal(JSON.parse(exports.patchClaudeCodeCch(JSON.stringify(body))).system[0].text, billing, label);
      } else {
        assert.equal(headers.get('x-api-key'), 'sk-ant-api-synthetic', label);
        assert.equal(headers.get('x-app'), null, label);
        assert.equal(headers.get('x-claude-code-session-id'), null, label);
        assert.ok(!body.system?.some(block => block.text.startsWith('x-anthropic-billing-header: ')), label);
      }
    }
  }
});

test('patch installer applies once, is idempotent, and rejects incompatible versions', () => {
  const root = mkdtempSync(join(tmpdir(), 'pi-black-patch-'));
  const sourceFixture = join(root, packagePath, 'src/claude-code-protocol.ts');
  const testFixture = join(root, packagePath, 'test/claude-code-protocol.test.ts');
  const upstreamTests = readFileSync(join(agentDir, packagePath, 'test/claude-code-protocol.test.ts'), 'utf8');
  const apply = () => spawnSync('sh', [fileURLToPath(new URL('apply.sh', import.meta.url))], {
    env: { ...process.env, PI_CODING_AGENT_DIR: root }, encoding: 'utf8',
  });

  try {
    mkdirSync(dirname(sourceFixture), { recursive: true });
    mkdirSync(dirname(testFixture), { recursive: true });
    writeFileSync(sourceFixture, source.replace('"2.1.280"', '"2.1.258"'));
    writeFileSync(testFixture, upstreamTests.replaceAll('022', '01c'));

    const first = apply();
    assert.equal(first.status, 0, first.stderr);
    assert.match(first.stdout, /Applied pi-black-cc2\.1\.280\.patch/);
    assert.equal(readFileSync(sourceFixture, 'utf8'), source);
    assert.equal(readFileSync(testFixture, 'utf8'), upstreamTests);

    const second = apply();
    assert.equal(second.status, 0, second.stderr);
    assert.match(second.stdout, /Already applied pi-black-cc2\.1\.280\.patch/);

    writeFileSync(sourceFixture, source.replace('"2.1.280"', '"9.9.999"'));
    const incompatible = apply();
    assert.notEqual(incompatible.status, 0);
    assert.match(incompatible.stderr, /Cannot patch src\/claude-code-protocol\.ts/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
