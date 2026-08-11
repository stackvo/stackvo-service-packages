#!/usr/bin/env node
/**
 * probe-tags — does every image these packages name still exist?
 *
 *   node tools/probe-tags.mjs [--strict] [--service mysql]
 *
 * The failure this exists to catch is silent: a registry drops a series, the
 * package keeps offering it, and the first anyone hears is a pull error after
 * the user clicked Install. `validate.mjs` cannot answer it — whether a tag
 * resolves is a fact about the world, not about this tree, and a gate that
 * needs the network is a gate that fails on a train.
 *
 * So this **reports** by default and exits zero. `--strict` is for the release
 * step, where a missing tag should stop a publish.
 *
 * Two details are why this is a program rather than a note to check by hand.
 * The reference is read out of the manifest rather than reconstructed, so
 * RabbitMQ is probed as `4.3-management` — the plain tags exist for series the
 * management ones do not, and checking the bare name would pass while the pull
 * failed. And `docker.elastic.co` is a different registry from the Hub, with
 * its own token handshake and its own idea of which tags exist.
 */

import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..');
const PACKAGES = join(ROOT, 'packages');

const argv = process.argv.slice(2);
const strict = argv.includes('--strict');
// `indexOf` returns -1 when the flag is absent, and -1 + 1 is 0 — so the first
// argument becomes the service name. With no arguments that was undefined and
// harmless; the moment a flag was added it filtered every package out and the
// tool reported cheerfully on nothing.
const serviceAt = argv.indexOf('--service');
const only = serviceAt === -1 ? undefined : argv[serviceAt + 1];

const readJson = (p) => JSON.parse(readFileSync(p, 'utf8'));
const dirs = (p) =>
  existsSync(p) ? readdirSync(p).filter((n) => !n.startsWith('.') && statSync(join(p, n)).isDirectory()) : [];

/**
 * Docker Hub's own API rather than the registry v2 one: it answers for
 * `library/*` and for user repositories through a single unauthenticated path.
 */
async function hubResolves(repository, tag) {
  const path = repository.includes('/') ? repository : `library/${repository}`;
  const url = `https://hub.docker.com/v2/repositories/${path}/tags/${encodeURIComponent(tag)}`;
  try {
    const response = await fetch(url, { signal: AbortSignal.timeout(15000) });
    return response.ok;
  } catch {
    return null; // Unreachable is not the same answer as absent.
  }
}

/** The v2 handshake `docker.elastic.co` insists on. */
async function registryResolves(host, repository, tag) {
  const manifest = `https://${host}/v2/${repository}/manifests/${encodeURIComponent(tag)}`;
  const accept = [
    'application/vnd.docker.distribution.manifest.v2+json',
    'application/vnd.docker.distribution.manifest.list.v2+json',
    'application/vnd.oci.image.manifest.v1+json',
    'application/vnd.oci.image.index.v1+json',
  ].join(', ');

  try {
    let response = await fetch(manifest, {
      headers: { Accept: accept },
      signal: AbortSignal.timeout(15000),
    });
    if (response.status === 401) {
      const challenge = response.headers.get('www-authenticate') ?? '';
      const realm = /realm="([^"]+)"/.exec(challenge)?.[1];
      const service = /service="([^"]+)"/.exec(challenge)?.[1];
      if (!realm) return null;
      const token = await fetch(
        `${realm}?service=${encodeURIComponent(service ?? host)}&scope=${encodeURIComponent(
          `repository:${repository}:pull`
        )}`,
        { signal: AbortSignal.timeout(15000) }
      ).then((r) => (r.ok ? r.json() : null));
      if (!token?.token) return null;
      response = await fetch(manifest, {
        headers: { Accept: accept, Authorization: `Bearer ${token.token}` },
        signal: AbortSignal.timeout(15000),
      });
    }
    return response.ok;
  } catch {
    return null;
  }
}

const resolves = (image) =>
  !image.registry || image.registry === 'docker.io'
    ? hubResolves(image.repository, image.tag)
    : registryResolves(image.registry, image.repository, image.tag);

// ---------------------------------------------------------------- the walk

const rows = [];
for (const category of dirs(PACKAGES).sort()) {
  for (const service of dirs(join(PACKAGES, category)).sort()) {
    if (only && service !== only) continue;
    const versionsDir = join(PACKAGES, category, service, 'versions');
    for (const version of dirs(versionsDir).sort()) {
      const manifest = readJson(join(versionsDir, version, 'manifest.json'));
      rows.push({ service, version, image: manifest.image });
      for (const companion of manifest.companions ?? []) {
        rows.push({ service: `${service}/${companion.name}`, version, image: companion.image });
      }
    }
  }
}

console.log(`\nprobing ${rows.length} image reference(s)\n`);

let missing = 0;
let unreachable = 0;

// Sequential on purpose. Docker Hub rate-limits anonymous callers, and a
// hundred parallel requests turns "does this tag exist" into "were we throttled"
// — which is the answer that would make this tool untrustworthy.
for (const row of rows) {
  const reference = `${row.image.registry && row.image.registry !== 'docker.io' ? `${row.image.registry}/` : ''}${
    row.image.repository
  }:${row.image.tag}`;
  const answer = await resolves(row.image);
  if (answer === true) continue;
  if (answer === null) {
    unreachable += 1;
    console.log(`  ?     ${row.service}@${row.version}  ${reference}  (could not ask)`);
  } else {
    missing += 1;
    console.log(`  GONE  ${row.service}@${row.version}  ${reference}`);
  }
}

console.log(`\n  ${rows.length - missing - unreachable} resolved, ${missing} missing, ${unreachable} unreachable\n`);

if (missing && strict) {
  console.error('A package offering a tag that no longer exists fails as a pull error after Install.');
  process.exit(1);
}
