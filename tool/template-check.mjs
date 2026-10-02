#!/usr/bin/env node
// `template:check` of a CONSUMER project (docs/CONSUMING.md): copy this file into the project's
// scripts/ and add "template:check": "node scripts/template-check.mjs" to its root package.json.
// CI runs it (docs/ci/*.yml). In the template repository itself it has nothing to check.
//
//   node scripts/template-check.mjs [--root <dir>]
//
// Fails when:
// - the @dimam18/* packages of the project's package.json files do not all have the same EXACT
//   version (no ^, ~, file:, link:, workspace:);
// - a pubspec.yaml depends on mobile_kit / mobile_kit_clock other than as a git dependency with
//   `ref: v<that version>` (a path dependency or dependency_overrides is local co-development);
// - pubspec_overrides.yaml is tracked by git, the root package.json has pnpm.overrides for
//   @dimam18/*, or pnpm-lock.yaml resolves a @dimam18/* package from file: or link: (a forgotten
//   tarball / injected co-development setup, docs/CONSUMING.md "Совместная разработка").
import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join, relative } from 'node:path';
import { pathToFileURL } from 'node:url';

const SCOPE = '@dimam18/';
const FLUTTER_PACKAGES = ['mobile_kit', 'mobile_kit_clock'];
const DEPENDENCY_FIELDS = ['dependencies', 'devDependencies', 'peerDependencies', 'optionalDependencies'];
const SKIP_DIRS = new Set(['node_modules', '.git', 'dist', 'build', '.dart_tool', 'coverage', '.packs', 'Pods', '.symlinks']);
const EXACT = /^\d+\.\d+\.\d+$/;

function findFiles(root, name, dir = root, out = []) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (!SKIP_DIRS.has(entry.name)) findFiles(root, name, join(dir, entry.name), out);
    } else if (entry.name === name) out.push(relative(root, join(dir, entry.name)).split('\\').join('/'));
  }
  return out.sort();
}

/** The indented block under `key:` at `indent` (or an inline value), null when absent. */
function yamlBlock(text, key, indent) {
  const lines = text.split('\n');
  const head = new RegExp(`^${' '.repeat(indent)}${key}:(.*)$`);
  const start = lines.findIndex((line) => head.test(line));
  if (start < 0) return null;
  const inline = head.exec(lines[start])[1].replace(/\s+#.*$/, '').trim();
  const body = [];
  for (let i = start + 1; i < lines.length; i += 1) {
    const line = lines[i];
    if (line.trim() === '' || line.trim().startsWith('#')) continue;
    if (line.length - line.trimStart().length <= indent) break;
    body.push(line);
  }
  return `${inline}\n${body.join('\n')}`;
}

/** Problems of one pubspec.yaml text, given the expected tag (vX.Y.Z or null). */
export function pubspecProblems(file, text, tag) {
  const problems = [];
  const overrides = yamlBlock(text, 'dependency_overrides', 0);
  for (const name of FLUTTER_PACKAGES) {
    if (overrides !== null && new RegExp(`^\\s+${name}:`, 'm').test(overrides)) problems.push(`${file}: dependency_overrides.${name} (local co-development) must not be committed`);
    const dependencies = yamlBlock(text, 'dependencies', 0);
    const spec = dependencies === null ? null : yamlBlock(dependencies.split('\n').slice(1).join('\n'), name, 2);
    if (spec === null) continue;
    if (!/\bgit\s*:/.test(spec)) {
      problems.push(`${file}: ${name} must be a git dependency on the template repository with ref: vX.Y.Z`);
      continue;
    }
    const ref = /\bref\s*:\s*['"]?([^\s,'"}]+)/.exec(spec)?.[1] ?? null;
    if (ref === null) problems.push(`${file}: ${name} has no ref (pin the release tag)`);
    else if (tag !== null && ref !== tag) problems.push(`${file}: ${name} ref is ${ref}, the npm packages are ${tag.slice(1)} (expected ref: ${tag})`);
    else if (!/^v\d+\.\d+\.\d+$/.test(ref)) problems.push(`${file}: ${name} ref ${ref} is not a release tag vX.Y.Z`);
  }
  return problems;
}

function trackedByGit(root, file) {
  try {
    execFileSync('git', ['ls-files', '--error-unmatch', file], { cwd: root, stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

/**
 * The first lockfile entry that resolves a @dimam18/* package from file: or link: (null: none).
 * pnpm-lock v9 has the name on one line and `specifier:` / `version:` on the next ones (importers),
 * or `'@dimam18/x@file:…':` as a key (packages).
 */
export function lockfileLocalEntry(text) {
  let current = null;
  let currentIndent = -1;
  for (const line of text.split('\n')) {
    const indent = line.length - line.trimStart().length;
    if (current !== null && indent <= currentIndent) current = null;
    const trimmed = line.trim();
    if (trimmed.includes(SCOPE) && /\b(?:file|link):/.test(trimmed)) return trimmed;
    const key = /^'?(@dimam18\/[^'@:\s]+)'?:\s*$/.exec(trimmed);
    if (key !== null) {
      current = key[1];
      currentIndent = indent;
    } else if (current !== null && /^(?:specifier|version):\s*(?:file|link):/.test(trimmed)) {
      return `${current} ${trimmed}`;
    }
  }
  return null;
}

/** Problems of the project at `root` (empty: consistent). */
export function templateCheck(root) {
  const problems = [];
  const versions = new Map();
  for (const file of findFiles(root, 'package.json')) {
    const manifest = JSON.parse(readFileSync(join(root, file), 'utf8'));
    for (const field of DEPENDENCY_FIELDS) {
      for (const [name, range] of Object.entries(manifest[field] ?? {})) {
        if (!name.startsWith(SCOPE)) continue;
        if (!EXACT.test(range)) problems.push(`${file}: ${field}.${name} is "${range}"; pin the exact template version`);
        else versions.set(`${file} ${name}`, range);
      }
    }
    if (file === 'package.json') {
      for (const name of Object.keys(manifest.pnpm?.overrides ?? {})) {
        if (name.includes(SCOPE)) problems.push(`package.json: pnpm.overrides.${name} (local co-development) must not be committed`);
      }
    }
  }
  const distinct = [...new Set(versions.values())];
  if (distinct.length > 1) problems.push(`@dimam18/* versions differ: ${[...versions].map(([where, v]) => `${where}@${v}`).join(', ')}`);
  const tag = distinct.length === 1 ? `v${distinct[0]}` : null;

  for (const file of findFiles(root, 'pubspec.yaml')) problems.push(...pubspecProblems(file, readFileSync(join(root, file), 'utf8'), tag));
  for (const file of findFiles(root, 'pubspec_overrides.yaml')) {
    if (trackedByGit(root, file)) problems.push(`${file} is tracked by git; it is local only (add it to .gitignore)`);
  }
  const lockfile = join(root, 'pnpm-lock.yaml');
  if (existsSync(lockfile)) {
    const local = lockfileLocalEntry(readFileSync(lockfile, 'utf8'));
    if (local !== null) problems.push(`pnpm-lock.yaml resolves a template package locally: ${local}`);
  }
  return problems;
}

export function main(argv = process.argv.slice(2)) {
  const rootIndex = argv.indexOf('--root');
  const root = rootIndex >= 0 ? argv[rootIndex + 1] : process.cwd();
  const problems = templateCheck(root);
  for (const problem of problems) process.stderr.write(`template:check: ${problem}\n`);
  if (problems.length > 0) return 1;
  process.stdout.write('template:check: OK\n');
  return 0;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) process.exitCode = main();
