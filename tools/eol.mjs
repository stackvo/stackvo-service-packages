#!/usr/bin/env node
/**
 * eol — is every `support` block still true?
 *
 *   node tools/eol.mjs [--write] [--strict] [--service postgres]
 *
 * ADR 0014 says the packages repository carries the versions people actually
 * run, and that "supported" is a **measurement rather than an opinion**. This
 * is the measurement: each manifest's `support.status` against endoflife.date,
 * which is the same source the `support.source` field points at.
 *
 * A drift here is not cosmetic. `support` decides ordering and visibility in
 * the version picker — an `eol` version is listed but hidden behind "show older
 * versions" — so a series that quietly went end-of-life and still reads
 * `supported` is a version the app recommends and nobody upstream patches.
 *
 * Reports by default, like `probe-tags.mjs` and for the same reason: this needs
 * the network, and a gate that needs the network is a gate that fails on a
 * train. `--strict` is for the release step, and `--write` is what makes the
 * manifests true — the generator that produces them cannot know a support
 * status, so it writes `supported` as a starting point and this corrects it.
 * The generator preserves whatever it finds, so the two do not fight.
 *
 * ## Why the mapping is a table
 *
 * endoflife.date names products its own way — `postgresql`, not `postgres`;
 * `elasticsearch`, not `docker.elastic.co/elasticsearch/elasticsearch` — and a
 * service with no entry there is not an error, it is a service whose upstream
 * publishes no schedule. Guessing the product name would produce confident
 * answers about the wrong software, which is worse than no answer.
 */

import { readFileSync, readdirSync, existsSync, statSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..');
const PACKAGES = join(ROOT, 'packages');

const argv = process.argv.slice(2);
const strict = argv.includes('--strict');
const writing = argv.includes('--write');
// `indexOf` returns -1 when the flag is absent, and -1 + 1 is 0 — so the first
// argument becomes the service name. With no arguments that was undefined and
// harmless; the moment a flag was added it filtered every package out and the
// tool reported cheerfully on nothing.
const serviceAt = argv.indexOf('--service');
const only = serviceAt === -1 ? undefined : argv[serviceAt + 1];

/**
 * Service id → the product endoflife.date knows it as.
 *
 * Absent means "upstream publishes no schedule we can check", and those are
 * skipped rather than guessed at. Kept short and explicit for that reason.
 */
const PRODUCTS = {
  mysql: 'mysql',
  mariadb: 'mariadb',
  postgres: 'postgresql',
  mongo: 'mongodb',
  cassandra: 'cassandra',
  redis: 'redis',
  memcached: 'memcached',
  valkey: 'valkey',
  rabbitmq: 'rabbitmq',
  kafka: 'apache-kafka',
  elasticsearch: 'elasticsearch',
  kibana: 'elasticsearch',
  grafana: 'grafana',
  solr: 'solr',
  clickhouse: 'clickhouse',
  prometheus: 'prometheus',
  graylog: 'graylog',
  mssql: 'mssqlserver',
};

/**
 * Versions whose upstream calls them something else.
 *
 * SQL Server is sold by the year and versioned by a number: what the world
 * calls 2022 is internally 16.0, and endoflife.date keys by the number. Without
 * this the schedule lookup finds nothing and the row is reported as unchecked —
 * which is not wrong, exactly, but it means `support: supported` on the one
 * package here whose vendor publishes the clearest schedule of any of them
 * would be the opinion this tool exists to replace.
 *
 * A table rather than a rule: the mapping is a naming decision at Microsoft
 * and there is nothing to derive it from.
 */
const CYCLES = {
  mssql: { 2019: '15.0', 2022: '16.0', 2025: '17.0' },
};

const readJson = (p) => JSON.parse(readFileSync(p, 'utf8'));
const dirs = (p) =>
  existsSync(p) ? readdirSync(p).filter((n) => !n.startsWith('.') && statSync(join(p, n)).isDirectory()) : [];

async function schedule(product) {
  try {
    const response = await fetch(`https://endoflife.date/api/${product}.json`, {
      signal: AbortSignal.timeout(15000),
    });
    return response.ok ? await response.json() : null;
  } catch {
    return null;
  }
}

/**
 * The cycle a version belongs to.
 *
 * endoflife.date keys by series — `16`, `8.0`, `7.17` — and a package version
 * is either the series itself or a patch inside it. Longest prefix wins, so
 * `8.19.19` finds `8.x` rather than `8` finding it first.
 */
function cycleOf(entries, version) {
  return entries
    .filter((e) => version === String(e.cycle) || version.startsWith(`${e.cycle}.`))
    .sort((a, b) => String(b.cycle).length - String(a.cycle).length)[0];
}

const today = new Date().toISOString().slice(0, 10);
const isPast = (value) => typeof value === 'string' && value <= today;

const rows = [];
for (const category of dirs(PACKAGES).sort()) {
  for (const service of dirs(join(PACKAGES, category)).sort()) {
    if (only && service !== only) continue;
    const versionsDir = join(PACKAGES, category, service, 'versions');
    for (const version of dirs(versionsDir).sort()) {
      const manifest = readJson(join(versionsDir, version, 'manifest.json'));
      rows.push({
        service,
        version,
        support: manifest.support ?? {},
        path: join(versionsDir, version, 'manifest.json'),
      });
    }
  }
}

const schedules = new Map();
let drift = 0;
let unchecked = 0;
let written = 0;

console.log('');
for (const row of rows) {
  const product = PRODUCTS[row.service];
  if (!product) {
    unchecked += 1;
    continue;
  }
  if (!schedules.has(product)) schedules.set(product, await schedule(product));
  const entries = schedules.get(product);
  if (!Array.isArray(entries)) {
    unchecked += 1;
    continue;
  }

  const cycle = cycleOf(entries, CYCLES[row.service]?.[row.version] ?? row.version);
  if (!cycle) {
    unchecked += 1;
    continue;
  }

  // `eol` is either a date or `true`/`false`. Both spellings are in the wild
  // and treating `true` as a date silently means "not yet".
  const dead = cycle.eol === true || isPast(cycle.eol);
  const claimed = row.support.status ?? 'supported';
  const expected = dead ? 'eol' : 'supported';

  // `deprecated` is a human's judgement — "still patched, do not start here" —
  // so it is only wrong when upstream says the series is actually dead.
  const wrong = claimed === 'deprecated' ? dead : claimed !== expected;
  const dateWrong = typeof cycle.eol === 'string' && row.support.eolDate !== cycle.eol;

  if (wrong) {
    drift += 1;
    console.log(
      `  ${writing ? 'FIXED' : 'DRIFT'} ${row.service}@${row.version}  manifest says ${claimed}, ` +
        `${product} cycle ${cycle.cycle} says ${expected}` +
        (typeof cycle.eol === 'string' ? ` (eol ${cycle.eol})` : '')
    );
  }

  if (writing && (wrong || dateWrong)) {
    // Rewritten field by field rather than replaced, so a `deprecated` a human
    // set on a series upstream still patches survives — that judgement is not
    // this tool's to overturn.
    const manifest = readJson(row.path);
    manifest.support = manifest.support ?? {};
    if (wrong) manifest.support.status = expected;
    if (typeof cycle.eol === 'string') manifest.support.eolDate = cycle.eol;
    manifest.support.source = `https://endoflife.date/api/${product}.json`;
    writeFileSync(row.path, `${JSON.stringify(manifest, null, 2)}\n`);
    written += 1;
  } else if (dateWrong && row.support.eolDate) {
    console.log(
      `  DATE  ${row.service}@${row.version}  manifest says ${row.support.eolDate}, upstream says ${cycle.eol}`
    );
  }
}

console.log(
  `\n  ${rows.length} version(s): ${rows.length - drift - unchecked} agree, ${drift} drifted, ` +
    `${unchecked} have no published schedule` +
    (writing ? `, ${written} manifest(s) rewritten` : '') +
    '\n'
);

if (writing && written) {
  console.log('  Hashes moved — run `node tools/build-registry.mjs` and commit both.\n');
}

if (drift && strict) {
  console.error('A version that reads `supported` and is not is a version the picker recommends and nobody patches.');
  process.exit(1);
}
