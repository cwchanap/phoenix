import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const commands: string[][] = [
  ['bun', 'install', '--frozen-lockfile'],
  ['bun', 'run', 'test:e2e:install'],
  ['bun', 'run', 'check'],
  ['bun', 'run', 'lint'],
  ['bun', 'run', 'format:check'],
  ['bun', 'run', 'test'],
  ['bun', 'run', 'test:coverage'],
  ['bun', 'run', 'coverage:check'],
  ['bun', 'run', 'test:e2e'],
  ['bun', 'run', 'build'],
  ['bun', 'run', 'tauri:build', '--', '--no-sign'],
];

const verificationEnv = { ...process.env, CI: 'true', HUSKY: '0' };

async function run(command: string[], cwd: string): Promise<void> {
  const child = Bun.spawn(command, {
    cwd,
    env: verificationEnv,
    stdin: 'inherit',
    stdout: 'inherit',
    stderr: 'inherit',
  });
  const code = await child.exited;
  if (code !== 0) throw new Error(`clean verification failed (${code}): ${command.join(' ')}`);
}

const checkout = await mkdtemp(join(tmpdir(), 'phoenix-clean-'));
const archive = `${checkout}.tar`;

try {
  const archiveCommand = ['git', 'archive', '--format=tar', 'HEAD'];
  const git = Bun.spawn(archiveCommand, { stdout: 'pipe', stderr: 'inherit' });
  const archiveBytes = await new Response(git.stdout).arrayBuffer();
  const archiveCode = await git.exited;
  if (archiveCode !== 0) {
    throw new Error(`clean verification failed (${archiveCode}): ${archiveCommand.join(' ')}`);
  }
  await Bun.write(archive, archiveBytes);

  await run(['tar', '-xf', archive, '-C', checkout], process.cwd());
  await run(['git', 'init'], checkout);
  for (const command of commands) await run(command, checkout);
} finally {
  await rm(archive, { force: true });
  await rm(checkout, { recursive: true, force: true });
}
