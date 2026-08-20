#!/usr/bin/env -S node --experimental-strip-types
import { accessSync, constants, realpathSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { filesystemPolicyHash, loadSafetyConfig } from './config.ts';
import { buildSandboxProfile } from './profile.ts';

function executable(path: string, label: string): string {
  try {
    accessSync(path, constants.X_OK);
    return path;
  } catch {
    throw new Error(`${label} is not executable: ${path}`);
  }
}

function realPiPath(): string {
  if (process.env.PI_REAL_PI) return process.env.PI_REAL_PI;
  const pnpmHome = process.env.PNPM_HOME || join(homedir(), 'Library', 'pnpm');
  return join(pnpmHome, 'pi');
}

function exec(file: string, args: string[], env: NodeJS.ProcessEnv): never {
  if (!process.execve) throw new Error('pi-safety requires Node.js 22.15 or newer (process.execve is unavailable)');
  return process.execve(file, args, env);
}

export function launchPi(args: string[]): never {
  const realPi = executable(realPiPath(), 'underlying pnpm pi launcher');

  // Subagents and other nested Pi processes already inherit the parent Seatbelt
  // profile. Avoid stacking sandbox-exec while preserving the same policy.
  if (process.env.PI_SAFETY_SANDBOXED === '1') {
    return exec(realPi, [realPi, ...args], process.env);
  }

  // This escape hatch disables only the filesystem Seatbelt. The extension
  // still enforces shell-command rules and routes rm/rmdir through Trash.
  if (process.env.PI_SAFETY_DISABLE_FILESYSTEM_SANDBOX === '1') {
    return exec(realPi, [realPi, ...args], { ...process.env, PI_REAL_PI: realPi });
  }

  if (process.platform !== 'darwin') throw new Error('pi-safety currently supports macOS only');
  const sandboxExec = executable('/usr/bin/sandbox-exec', 'sandbox-exec');
  const loaded = loadSafetyConfig(process.env.PI_SAFETY_CONFIG);
  if (loaded.status !== 'loaded') {
    console.warn(`pi-safety: ${loaded.errors.join('; ')}; launching with built-in safeguards only`);
  }

  const profile = buildSandboxProfile(loaded.config);
  const env = {
    ...process.env,
    PI_SAFETY_SANDBOXED: '1',
    PI_SAFETY_FS_POLICY_HASH: filesystemPolicyHash(loaded.config),
    PI_SAFETY_CONFIG_STATUS: loaded.status,
    PI_REAL_PI: realPi,
  };
  return exec(sandboxExec, ['sandbox-exec', '-p', profile, realPi, ...args], env);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === realpathSync(resolve(process.argv[1]))) {
  try {
    launchPi(process.argv.slice(2));
  } catch (error) {
    console.error(`pi-safety: ${error instanceof Error ? error.message : String(error)}`);
    process.exit(1);
  }
}
