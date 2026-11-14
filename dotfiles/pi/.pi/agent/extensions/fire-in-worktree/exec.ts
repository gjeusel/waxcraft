import { spawn } from 'node:child_process';

export const LONG_TIMEOUT_MS = 15 * 60_000;

export interface RunOptions {
  cwd?: string;
  timeoutMs?: number;
  signal?: AbortSignal;
}

export interface RunResult {
  code: number;
  stdout: string;
  stderr: string;
  /** Set when a signal ended the command, as its timeout does. */
  killed?: string;
}

/**
 * Run a command with stdin closed: wt and git would otherwise wait on prompts nobody answers. The
 * parent's VIRTUAL_ENV is dropped so that uv sets up the worktree's own venv.
 */
export function run(command: string, args: string[], options: RunOptions = {}): Promise<RunResult> {
  const env = { ...process.env };
  delete env.VIRTUAL_ENV;
  const timeoutMs = options.timeoutMs ?? 60_000;

  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: options.cwd,
      env,
      stdio: ['ignore', 'pipe', 'pipe'],
      timeout: timeoutMs,
      signal: options.signal,
    });
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (data: Buffer) => (stdout += data.toString()));
    child.stderr.on('data', (data: Buffer) => (stderr += data.toString()));
    child.on('error', reject);
    child.on('close', (code, signal) => {
      const killed = signal ? `${signal}, its timeout being ${timeoutMs / 1000}s` : undefined;
      resolve({ code: code ?? (signal ? 1 : 0), stdout, stderr, killed });
    });
  });
}

export function failure(command: string, args: string[], result: RunResult): Error {
  const output = (result.stderr.trim() || result.stdout.trim()).slice(-2000);
  const reason = result.killed ? `killed by ${result.killed}` : `exit ${result.code}`;

  return new Error(`\`${command} ${args.join(' ')}\` failed (${reason}):\n${output}`);
}

export async function runOrThrow(command: string, args: string[], options: RunOptions = {}): Promise<string> {
  const result = await run(command, args, options);
  if (result.code !== 0) throw failure(command, args, result);

  return result.stdout.trim();
}

export function errorText(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
