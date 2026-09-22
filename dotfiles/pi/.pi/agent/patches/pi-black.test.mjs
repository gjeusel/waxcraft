import assert from 'node:assert/strict';
import { createHash, webcrypto } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { homedir, tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
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
