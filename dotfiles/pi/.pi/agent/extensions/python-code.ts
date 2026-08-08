import { realpathSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { inspect } from 'node:util';
import { DEFAULT_MAX_BYTES, DEFAULT_MAX_LINES, truncateHead, type ExtensionAPI } from '@earendil-works/pi-coding-agent';
import type { Monty, ResourceLimits } from '@pydantic/monty';

type MontyModule = typeof import('@pydantic/monty');

const extensionPath = realpathSync(fileURLToPath(import.meta.url));
const extensionDirectory = dirname(extensionPath);
const localRequire = createRequire(extensionPath);
const runtimePackages = ['@pydantic/monty', 'typebox'] as const;
type RuntimePackage = (typeof runtimePackages)[number];
type PackageResolver = (specifier: string) => string;

let montyModulePromise: Promise<MontyModule> | undefined;

function resolveLocalPackage(specifier: string): string {
  return localRequire.resolve(specifier);
}

function importLocalPackage<T>(specifier: string): Promise<T> {
  return import(pathToFileURL(resolveLocalPackage(specifier)).href) as Promise<T>;
}

function findMissingRuntimePackage(resolvePackage: PackageResolver): RuntimePackage | undefined {
  for (const specifier of runtimePackages) {
    try {
      resolvePackage(specifier);
    } catch (error) {
      const code = error && typeof error === 'object' && 'code' in error ? error.code : undefined;
      if (code === 'MODULE_NOT_FOUND' || code === 'ERR_MODULE_NOT_FOUND') return specifier;
      throw error;
    }
  }
  return undefined;
}

function registerMissingDependencyWarning(pi: ExtensionAPI, specifier: RuntimePackage): void {
  const message =
    `Python Code Tool disabled: required package "${specifier}" is not installed. ` +
    `Run "npm install" in ${extensionDirectory}.`;

  pi.on('session_start', (_event, ctx) => {
    if (ctx.hasUI) ctx.ui.notify(message, 'warning');
    else console.warn(`Warning: ${message}`);
  });
}

function loadMonty(): Promise<MontyModule> {
  montyModulePromise ??= importLocalPackage<MontyModule>('@pydantic/monty');
  return montyModulePromise;
}

export const PYTHON_LIMITS: ResourceLimits = {
  maxDurationSecs: 10,
  maxMemory: 64 * 1024 * 1024,
};

const LIMITATION_HINT =
  '[Likely a Monty sandbox limitation. Run the script with normal Python via the bash tool instead.]';

export interface PythonCodeResult {
  text: string;
  truncated: boolean;
}

interface RunPythonOptions {
  limits?: ResourceLimits;
  maxBytes?: number;
  maxLines?: number;
}

export class PythonCodeExecutionError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'PythonCodeExecutionError';
  }
}

function formatValue(value: unknown): string {
  return inspect(value, {
    breakLength: 120,
    compact: false,
    depth: 8,
    maxArrayLength: 200,
    maxStringLength: DEFAULT_MAX_BYTES,
  });
}

function formatError(error: unknown, monty: MontyModule): string {
  if (error instanceof monty.MontyRuntimeError || error instanceof monty.MontySyntaxError) {
    return error.display('traceback');
  }
  if (error instanceof monty.MontyTypingError) return error.display();
  if (error instanceof monty.MontyCrashedError && error.timedOut) {
    return 'TimeoutError: Python execution exceeded its time limit';
  }
  if (error instanceof monty.MontyError) return error.display('type-msg');
  if (error instanceof Error) return `${error.name}: ${error.message}`;
  return String(error);
}

function isMontyLimitation(error: unknown, monty: MontyModule): boolean {
  const typeName = error instanceof monty.MontyError ? error.exception.typeName : '';
  if (['ImportError', 'ModuleNotFoundError', 'NotImplementedError'].includes(typeName)) return true;

  const message = error instanceof Error ? error.message : String(error);
  return /\b(?:not implemented|not supported|unsupported)\b/i.test(message);
}

function appendSection(text: string, section: string): string {
  if (!text) return section;
  return `${text}${text.endsWith('\n') ? '' : '\n'}${section}`;
}

function utf8Prefix(text: string, maxBytes: number): string {
  let low = 0;
  let high = text.length;
  while (low < high) {
    const middle = Math.ceil((low + high) / 2);
    if (Buffer.byteLength(text.slice(0, middle)) <= maxBytes) low = middle;
    else high = middle - 1;
  }
  if (low > 0 && /[\uD800-\uDBFF]/.test(text[low - 1] ?? '')) low -= 1;
  return text.slice(0, low);
}

function truncateText(text: string, maxLines: number, maxBytes: number) {
  const truncation = truncateHead(text, { maxLines, maxBytes });
  if (truncation.firstLineExceedsLimit) {
    return { content: utf8Prefix(text, maxBytes), truncated: true };
  }
  return truncation;
}

function truncateOutput(text: string, alreadyTruncated: boolean, maxLines: number, maxBytes: number): PythonCodeResult {
  const truncation = truncateText(text, maxLines, maxBytes);
  const truncated = alreadyTruncated || truncation.truncated;
  return {
    text: truncated ? `${truncation.content}\n[output truncated]` : truncation.content,
    truncated,
  };
}

/** Execute one self-contained snippet in a fresh Monty session. */
export async function runPythonCode(
  pool: Monty,
  code: string,
  options: RunPythonOptions = {},
): Promise<PythonCodeResult> {
  const maxBytes = options.maxBytes ?? DEFAULT_MAX_BYTES;
  const maxLines = options.maxLines ?? DEFAULT_MAX_LINES;
  const monty = await loadMonty();
  const session = await pool.checkout({ limits: options.limits ?? PYTHON_LIMITS, scriptName: 'python_code_tool.py' });
  let stdout = '';
  let stdoutTruncated = false;

  try {
    const output = await session.feedRun(code, {
      printCallback: (_stream, chunk) => {
        if (stdoutTruncated) return;
        const truncation = truncateText(stdout + chunk, maxLines, maxBytes);
        stdout = truncation.content;
        stdoutTruncated = truncation.truncated;
      },
    });

    let text = stdout;
    if (output !== null && output !== undefined) text = appendSection(text, `=> ${formatValue(output)}`);
    if (!text) text = '(no output)';
    return truncateOutput(text, stdoutTruncated, maxLines, maxBytes);
  } catch (error) {
    let text = appendSection(stdout, formatError(error, monty));
    if (isMontyLimitation(error, monty)) text = appendSection(text, LIMITATION_HINT);
    const result = truncateOutput(text, stdoutTruncated, maxLines, maxBytes);
    throw new PythonCodeExecutionError(result.text);
  } finally {
    await session.close();
  }
}

export async function initializePythonCodeExtension(
  pi: ExtensionAPI,
  resolvePackage: PackageResolver = resolveLocalPackage,
): Promise<void> {
  const missingPackage = findMissingRuntimePackage(resolvePackage);
  if (missingPackage) {
    registerMissingDependencyWarning(pi, missingPackage);
    return;
  }

  const [{ Type }, monty] = await Promise.all([importLocalPackage<typeof import('typebox')>('typebox'), loadMonty()]);
  let poolPromise: Promise<Monty> | undefined;

  const getPool = (): Promise<Monty> => {
    if (!poolPromise) {
      poolPromise = monty.Monty.create({
        maxProcesses: 2,
        requestTimeout: 12,
      }).catch((error: unknown) => {
        poolPromise = undefined;
        throw error;
      });
    }
    return poolPromise;
  };

  pi.on('session_shutdown', async () => {
    const currentPool = poolPromise;
    poolPromise = undefined;
    if (currentPool) await (await currentPool).close();
  });

  pi.registerTool({
    name: 'monty-python',
    label: 'Python Code Tool (Monty)',
    description: [
      'Execute one self-contained Python snippet in the Monty sandbox.',
      'Pass source directly in the code argument (stdin-style); never write the snippet to a .py file for this tool.',
      'Use it for calculations, data transformations, and quick checks that need only Python builtins or Monty-supported standard-library modules.',
      'There is no filesystem, network, environment, host-tool, or third-party-package access. Each call starts with fresh state.',
      'The final expression value and printed output are returned. Execution is limited to 10 seconds, 64 MiB, and 50 KB / 2000 output lines.',
      'If an error is identified as a Monty implementation limitation, the result will suggest retrying with normal Python through bash.',
    ].join(' '),
    promptSnippet: 'Execute simple, dependency-free Python in an isolated Monty sandbox',
    promptGuidelines: [
      'Use python for self-contained calculations, data transformations, or quick checks that do not need files, network access, environment variables, or third-party packages.',
      'Pass Python source directly to python in its code argument (stdin-style); do not create a temporary .py file.',
      'If python reports a likely Monty sandbox limitation, retry with normal Python through bash; for ordinary Python errors, fix the code instead.',
      'Do not use python when the script needs packages that would normally require uv run --with; use normal Python through bash instead.',
    ],
    parameters: Type.Object({
      code: Type.String({
        description:
          'Self-contained Python source passed directly to Monty (stdin-style, not a script file). The final top-level expression is returned.',
      }),
    }),
    async execute(_toolCallId, params, signal) {
      if (signal?.aborted) throw new Error('Python execution cancelled');
      const pool = await getPool();
      if (signal?.aborted) throw new Error('Python execution cancelled');
      const result = await runPythonCode(pool, params.code);
      return {
        content: [{ type: 'text', text: result.text }],
        details: { truncated: result.truncated },
      };
    },
  });
}

export default initializePythonCodeExtension;
