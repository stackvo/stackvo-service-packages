#!/usr/bin/env node
/**
 * compose-check — is every fragment a compose file, and one this policy allows?
 *
 *   node tools/compose-check.mjs [--json] [--skip-docker]
 *
 * Two questions, and they fail differently.
 *
 * **Is it valid Compose?** Answered by `docker compose config`, which is the
 * reference implementation of the specification and the only honest way to ask.
 * A fragment is a service body, so it is wrapped in the smallest file that can
 * hold one before being handed over — with the handles filled in, because an
 * unrendered `{{ port.main }}` is not a port and Compose would rightly refuse
 * it. What is being checked is the shape, not the values.
 *
 * **Is it a fragment this app may run?** Answered against
 * `schema/compose-policy.json`, which is the same file `compose_policy.rs`
 * reads on the client. An allowlist: a key nobody has considered is refused,
 * and adding one is a review rather than an omission. This is the gate that
 * matters — a compose service is not a passive description, and four words in
 * the wrong place are root on the host.
 *
 * The policy runs on both sides on purpose. Here it is a review, on the client
 * it is a defence: a repository somebody has taken over can serve anything, and
 * a check that only ever ran at publish time would not be there when it did.
 */

import { readFileSync, readdirSync, existsSync, statSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..');
const PACKAGES = join(ROOT, 'packages');

const argv = process.argv.slice(2);
const asJson = argv.includes('--json');
const skipDocker = argv.includes('--skip-docker');

const policy = JSON.parse(readFileSync(join(ROOT, 'schema/compose-policy.json'), 'utf8'));
const ALLOWED = new Set(Object.keys(policy.allowed));
const REFUSED = new Set(Object.keys(policy.refused));

const findings = [];
const err = (subject, code, message) => findings.push({ level: 'error', subject, code, message });

const readJson = (p) => JSON.parse(readFileSync(p, 'utf8'));
const dirs = (p) =>
  existsSync(p) ? readdirSync(p).filter((n) => !n.startsWith('.') && statSync(join(p, n)).isDirectory()) : [];

/** Is `docker compose` here at all? Absent is a skip, not a pass. */
function haveDocker() {
  if (skipDocker) return false;
  try {
    execFileSync('docker', ['compose', 'version'], { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

/**
 * Fill the handles with something of the right shape.
 *
 * Values that would make Compose complain about the value rather than the
 * structure — a port must be a number, a volume must be a name — because the
 * question here is whether the fragment is well-formed.
 */
function render(fragment, manifest) {
  let out = fragment;
  out = out.replaceAll(/\{\{\s*(companion\.)?image\s*\}\}/g, 'busybox:latest');
  out = out.replaceAll(/\{\{\s*(companion\.)?instance\.container\s*\}\}/g, 'stackvo-check');
  out = out.replaceAll(/\{\{\s*(companion\.)?instance\.aliases\s*\}\}/g, '["stackvo-check"]');
  out = out.replaceAll(/\{\{\s*(companion\.)?instance\.slug\s*\}\}/g, 'check');
  out = out.replaceAll(/\{\{\s*(companion\.)?instance\.domain\s*\}\}/g, 'check.stackvo.loc');
  out = out.replaceAll(/\{\{\s*(companion\.)?instance\.logs\s*\}\}/g, '/tmp/stackvo-check-logs');
  out = out.replaceAll(/\{\{\s*network\s*\}\}/g, 'stackvo-net');

  let port = 10000;
  out = out.replaceAll(/\{\{\s*(companion\.)?port\.[a-z0-9-]+\s*\}\}/g, () => String(port++));
  out = out.replaceAll(/\{\{\s*(companion\.)?volume\.([a-z0-9-]+)\s*\}\}/g, (_, __, name) => `stackvo-check-${name}`);
  out = out.replaceAll(/\{\{\s*(companion\.)?file\.([a-z0-9_-]+)\s*\}\}/g, '/tmp/stackvo-check.conf');

  for (const setting of manifest.settings ?? []) {
    const value = setting.default ?? 'x';
    out = out.replaceAll(new RegExp(`\\{\\{\\s*settings\\.${setting.key}\\s*\\}\\}`, 'g'), String(value));
  }
  // Anything left is a handle nothing declared; `validate.mjs` reports those by
  // name, so here it only has to become something Compose can parse.
  out = out.replaceAll(/\{\{[^}]*\}\}/g, 'x');
  return out;
}

/**
 * The fragment as the only service in the smallest valid compose file.
 *
 * The named volumes have to be declared here, because that is precisely what a
 * fragment does NOT carry: it is a service body, and the top-level `volumes:`
 * section is assembled by the app from the manifest. Leaving them out made
 * Compose refuse every package that stores anything — which is the right answer
 * to the wrong file.
 */
function wrap(rendered, volumes) {
  const body = rendered
    .split('\n')
    .map((line) => (line.trim() ? `    ${line}` : ''))
    .join('\n');
  const declared = volumes.length
    ? `\nvolumes:\n${volumes.map((v) => `  ${v}:`).join('\n')}\n`
    : '';
  return (
    `name: stackvo-check\nservices:\n  check:\n${body}\n` +
    declared +
    `\nnetworks:\n  stackvo-net:\n    name: stackvo-net\n    external: true\n`
  );
}

/**
 * Top-level keys of a service body, read by indentation.
 *
 * A YAML parser would be a dependency, and the shape here is fixed: a fragment
 * is emitted by one generator at one indent. `xdebug.rs` in the app makes the
 * same trade for the same reason — the file was written by this project.
 */
function topLevelKeys(fragment) {
  const keys = [];
  for (const raw of fragment.split('\n')) {
    if (!raw.trim() || raw.startsWith(' ') || raw.startsWith('#') || raw.startsWith('-')) continue;
    const key = raw.split(':')[0].trim();
    if (key && /^[a-z_]+$/.test(key)) keys.push(key);
  }
  return keys;
}

function checkPolicy(subject, fragment, manifest) {
  for (const key of topLevelKeys(fragment)) {
    if (REFUSED.has(key)) {
      err(subject, 'REFUSED_KEY', `${key}: ${policy.refused[key]}`);
    } else if (!ALLOWED.has(key)) {
      err(
        subject,
        'UNKNOWN_KEY',
        `${key} is not in the allowlist — adding it is a review, not an omission`
      );
    }
  }

  if (!/image:\s*"?\{\{\s*(companion\.)?image\s*\}\}"?/.test(fragment)) {
    err(subject, 'LITERAL_IMAGE', policy.rules.image.why);
  }

  // Which top-level key a list item belongs to. Tracked rather than matched by
  // shape, because `environment:` is a list in some templates and a mapping in
  // others — Elasticsearch writes `- discovery.type=single-node`, which reads
  // exactly like a Traefik label and is not one.
  const inVolumes = [];
  const inLabels = [];
  let section = null;
  for (const raw of fragment.split('\n')) {
    if (!raw.trim()) continue;
    if (!raw.startsWith(' ') && raw.includes(':')) {
      section = raw.split(':')[0].trim();
      continue;
    }
    const item = raw.trim();
    if (!item.startsWith('- ')) continue;
    if (section === 'volumes') inVolumes.push(item.slice(2).trim());
    if (section === 'labels') inLabels.push(item.slice(2).trim());
  }
  for (const mount of inVolumes) {
    const source = mount.replace(/^["']|["']$/g, '').split(':')[0];
    const ok =
      /^\{\{\s*(companion\.)?volume\.[a-z0-9-]+\s*\}\}$/.test(source) ||
      /^\{\{\s*(companion\.)?file\.[a-z0-9_-]+\s*\}\}$/.test(source) ||
      /^\{\{\s*(companion\.)?instance\.logs\s*\}\}$/.test(source);
    if (!ok) {
      err(subject, 'REFUSED_MOUNT', `${source} — ${policy.rules.volumes.refused}`);
    }
  }

  for (const [, cap] of fragment.matchAll(/cap_add:[\s\S]*?- ([A-Z_]+)/g)) {
    if (!policy.rules.cap_add.allowed.includes(cap)) {
      err(subject, 'REFUSED_CAPABILITY', `${cap} is not one of ${policy.rules.cap_add.allowed.join(', ')}`);
    }
  }

  for (const entry of inLabels) {
    const label = entry.replace(/^["']|["']$/g, '').split('=')[0];
    if (!label.startsWith(policy.rules.labels.requiredPrefix)) {
      err(subject, 'REFUSED_LABEL', `${label} — ${policy.rules.labels.why}`);
    }
  }

  // Handles must be ones the manifest declares. `validate.mjs` says the same
  // thing; here it keeps the rendered file honest before Docker sees it.
  const declared = new Set((manifest.settings ?? []).map((s) => s.key));
  for (const [, key] of fragment.matchAll(/\{\{\s*settings\.([A-Z0-9_]+)\s*\}\}/g)) {
    if (!declared.has(key)) err(subject, 'DANGLING_SETTING', `the fragment reads {{ settings.${key} }}`);
  }
}

// ---------------------------------------------------------------- the walk

const docker = haveDocker();
const scratch = mkdtempSync(join(tmpdir(), 'stackvo-compose-'));
let checked = 0;

for (const category of dirs(PACKAGES).sort()) {
  for (const service of dirs(join(PACKAGES, category)).sort()) {
    const versionsDir = join(PACKAGES, category, service, 'versions');
    for (const version of dirs(versionsDir).sort()) {
      const versionDir = join(versionsDir, version);
      const manifest = readJson(join(versionDir, 'manifest.json'));
      const subject = `${service}@${version}`;

      const fragments = [
        [manifest.compose.file, manifest],
        ...(manifest.companions ?? []).map((c) => [c.compose.file, { settings: [], volumes: c.volumes }]),
      ];

      for (const [file, forSettings] of fragments) {
        const path = join(versionDir, file);
        if (!existsSync(path)) continue;
        const fragment = readFileSync(path, 'utf8');
        checked += 1;

        checkPolicy(`${subject}/${file}`, fragment, forSettings);

        if (!docker) continue;
        const composePath = join(scratch, 'compose.yaml');
        const volumes = (forSettings.volumes ?? []).map((v) => `stackvo-check-${v.name}`);
        writeFileSync(composePath, wrap(render(fragment, forSettings), volumes));
        try {
          execFileSync('docker', ['compose', '-f', composePath, 'config'], { stdio: 'pipe' });
        } catch (e) {
          const detail = String(e.stderr ?? e.message).trim().split('\n')[0];
          err(`${subject}/${file}`, 'NOT_VALID_COMPOSE', detail);
        }
      }
    }
  }
}

rmSync(scratch, { recursive: true, force: true });

// ---------------------------------------------------------------- output

const errors = findings.filter((f) => f.level === 'error');

if (asJson) {
  console.log(JSON.stringify({ checked, docker, errors }, null, 2));
} else {
  console.log(`\nstackvo service packages — compose check`);
  console.log(`  ${checked} fragment(s)${docker ? '' : '  (docker not available — policy only)'}\n`);
  for (const f of findings) {
    console.log(`  ERROR ${f.code.padEnd(20)} ${f.subject}`);
    console.log(`        ${f.message}`);
  }
  if (findings.length) console.log('');
  console.log(`  ${errors.length} error(s)\n`);
}

process.exit(errors.length ? 1 : 0);
