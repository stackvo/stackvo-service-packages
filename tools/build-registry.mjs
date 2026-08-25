#!/usr/bin/env node
/**
 * build-registry — the index a client fetches before it can show a catalog.
 *
 *   node tools/build-registry.mjs [--check] [--sequence N] [--generated-at ISO]
 *
 * `registry.json` is **generated and never hand-edited**, and `--check` is what
 * makes that true rather than aspirational: it rebuilds the index in memory and
 * compares, so a commit whose index disagrees with the tree beside it fails CI.
 * An index somebody edited by hand is an index that can name a package that
 * does not exist, and the client would trust it — this file is the second link
 * of the chain of trust, so everything downstream inherits whatever it says.
 *
 * ## What it does not do
 *
 * It does not sign. Signing needs a private key, which belongs to a release
 * step and not to a validator anybody can run — see ADR 0015 in
 * `stackvo/docs/durum.md`. It also does not resolve image digests: that needs
 * the network, and `probe-tags.mjs` is where network-shaped truth lives.
 *
 * ## The two fields worth reading twice
 *
 * `sequence` is monotonic and a client refuses an index that goes backwards.
 * It is passed in rather than read from a clock, so the same tree always
 * produces the same bytes and `--check` can compare them.
 *
 * `recommended` is lifted from each service's `recommendedVersion`, and it is
 * what `latest` resolves to (ADR 0014). Exactly one version per service carries
 * it; `validate.mjs` is what refuses a service with none.
 */

import { readFileSync, readdirSync, existsSync, statSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..');
const PACKAGES = join(ROOT, 'packages');
const OUT = join(ROOT, 'registry.json');

const argv = process.argv.slice(2);
const flag = (name, fallback) => {
  const i = argv.indexOf(name);
  return i === -1 ? fallback : argv[i + 1];
};
const checking = argv.includes('--check');

const readJson = (p) => JSON.parse(readFileSync(p, 'utf8'));
const sha256 = (p) => createHash('sha256').update(readFileSync(p)).digest('hex');
const dirs = (p) =>
  existsSync(p) ? readdirSync(p).filter((n) => !n.startsWith('.') && statSync(join(p, n)).isDirectory()) : [];

/** Bytes on disk under a directory, so a client can show progress. */
function sizeOf(dir) {
  let total = 0;
  for (const name of readdirSync(dir)) {
    const path = join(dir, name);
    const stat = statSync(path);
    total += stat.isDirectory() ? sizeOf(path) : stat.size;
  }
  return total;
}

// When checking, reuse whatever the committed index says for the two fields
// that are inputs rather than facts about the tree. Otherwise `--check` would
// fail on every run for reasons that have nothing to do with the packages.
const existing = existsSync(OUT) ? readJson(OUT) : null;
const sequence = Number(flag('--sequence', checking ? existing?.sequence : (existing?.sequence ?? 0) + 1));
const generatedAt = flag('--generated-at', checking ? existing?.generatedAt : new Date().toISOString());

const packages = [];

for (const category of dirs(PACKAGES).sort()) {
  for (const service of dirs(join(PACKAGES, category)).sort()) {
    const serviceDir = join(PACKAGES, category, service);
    const identity = readJson(join(serviceDir, 'package.json'));

    const entry = {
      service: identity.service,
      category: identity.category,
      name: identity.name,
    };
    if (identity.summary) entry.summary = identity.summary;
    if (identity.keywords) entry.keywords = identity.keywords;
    // Who publishes it. Every package here names a maintainer and the index
    // dropped every one of them, so the client could not have shown whose a
    // package was even if it wanted to — and a catalogue that means to carry
    // third-party packages is asking somebody to run somebody else's compose
    // fragment. That is the fact they weigh before saying yes.
    if (identity.maintainer) entry.maintainer = identity.maintainer;
    if (identity.icon && existsSync(join(serviceDir, identity.icon))) {
      entry.icon = { path: identity.icon, sha256: sha256(join(serviceDir, identity.icon)) };
    }
    if (identity.legacyEnvPrefix) entry.legacyEnvPrefix = identity.legacyEnvPrefix;

    const versionsDir = join(serviceDir, 'versions');
    const capabilities = new Set();
    let multiple;

    // Directory order is alphabetical and version order is not, so the
    // manifests decide nothing here: the list is emitted sorted by name and the
    // client orders it for display. What must be stable is the BYTES, because
    // `--check` compares them.
    const versions = dirs(versionsDir)
      .sort()
      .map((version) => {
        const versionDir = join(versionsDir, version);
        const manifest = readJson(join(versionDir, 'manifest.json'));
        for (const c of manifest.capabilities ?? []) capabilities.add(c);
        multiple = manifest.instancing?.multiple;

        const row = {
          version,
          path: `packages/${category}/${service}/versions/${version}`,
          manifestSha256: sha256(join(versionDir, 'manifest.json')),
          sizeBytes: sizeOf(versionDir),
          support: manifest.support?.status ?? 'supported',
        };
        if (version === identity.recommendedVersion) row.recommended = true;
        if (manifest.support?.eolDate) row.eolDate = manifest.support.eolDate;
        return row;
      });

    if (multiple !== undefined) entry.instancing = { multiple };
    if (capabilities.size) entry.capabilities = [...capabilities].sort();
    entry.versions = versions;
    packages.push(entry);
  }
}

const registry = { schemaVersion: 1, sequence, generatedAt, packages };
const text = `${JSON.stringify(registry, null, 2)}\n`;

if (checking) {
  if (!existing) {
    console.error('registry.json is not there — run `node tools/build-registry.mjs` and commit it');
    process.exit(1);
  }
  const committed = `${JSON.stringify(existing, null, 2)}\n`;
  if (committed !== text) {
    console.error(
      'registry.json does not match the packages beside it.\n' +
        'It is generated: run `node tools/build-registry.mjs` and commit the result.\n' +
        'An index edited by hand can name a package that is not there, and a client would believe it.'
    );
    process.exit(1);
  }
  console.log(`registry.json is current — ${packages.length} package(s), sequence ${sequence}`);
} else {
  writeFileSync(OUT, text);
  const versions = packages.reduce((n, p) => n + p.versions.length, 0);
  console.log(`registry.json — ${packages.length} package(s), ${versions} version(s), sequence ${sequence}`);
}
