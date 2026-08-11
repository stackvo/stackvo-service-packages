#!/usr/bin/env node
/**
 * check-schema-sync — is `schema/` still the copy it claims to be?
 *
 *   node tools/check-schema-sync.mjs [--from ../stackvo/contracts] [--update]
 *
 * The four files under `schema/` are copies of `contracts/*.json` in the
 * `stackvo` repository, which is where they are authored: the client reads the
 * originals and this repository is validated against the copies, so a copy that
 * has drifted lets a package pass here and be refused by the only reader that
 * matters.
 *
 * A submodule would remove the copy and with it this whole file, and it was the
 * first thing considered. It was rejected for the reason `git.rs` in the app
 * gives for keeping its own git surface small: a submodule is a second thing
 * every contributor has to know about, in a repository whose whole point is
 * that it is data anybody can read. A copy plus a check that the copy is honest
 * costs one file.
 *
 * In CI the sibling checkout is usually absent, and that is **not** a pass:
 * without it this reports what it could not verify and exits zero, and the
 * hashes below are what make that safe — they are committed, so a copy that
 * changed on its own fails whether or not the original is reachable.
 */

import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..');
const SCHEMA = join(ROOT, 'schema');
const LOCK = join(SCHEMA, '.sync.json');

const argv = process.argv.slice(2);
const updating = argv.includes('--update');
const fromAt = argv.indexOf('--from');
const FROM = fromAt === -1 ? join(ROOT, '..', 'stackvo', 'contracts') : argv[fromAt + 1];

const FILES = [
  'package.schema.json',
  'package-version.schema.json',
  'registry.schema.json',
  'compose-policy.json',
];

const sha256 = (path) => createHash('sha256').update(readFileSync(path)).digest('hex');

if (updating) {
  const lock = { source: 'stackvo/contracts', files: {} };
  for (const name of FILES) {
    const origin = join(FROM, name);
    if (!existsSync(origin)) {
      console.error(`${name} is not at ${FROM} — nothing to copy from`);
      process.exit(1);
    }
    writeFileSync(join(SCHEMA, name), readFileSync(origin));
    lock.files[name] = sha256(origin);
  }
  writeFileSync(LOCK, `${JSON.stringify(lock, null, 2)}\n`);
  console.log(`schema/ updated from ${FROM} — ${FILES.length} file(s)`);
  process.exit(0);
}

if (!existsSync(LOCK)) {
  console.error('schema/.sync.json is not there — run `node tools/check-schema-sync.mjs --update`');
  process.exit(1);
}

const lock = JSON.parse(readFileSync(LOCK, 'utf8'));
let problems = 0;

for (const name of FILES) {
  const copy = join(SCHEMA, name);
  if (!existsSync(copy)) {
    console.error(`  MISSING  ${name}`);
    problems += 1;
    continue;
  }
  const recorded = lock.files?.[name];
  const actual = sha256(copy);
  if (recorded !== actual) {
    console.error(
      `  CHANGED  ${name} — this copy has been edited. Edit it in stackvo/contracts and re-run with --update.`
    );
    problems += 1;
    continue;
  }

  const origin = join(FROM, name);
  if (!existsSync(origin)) continue; // Reported below, once.
  if (sha256(origin) !== actual) {
    console.error(`  BEHIND   ${name} — stackvo/contracts has moved on. Re-run with --update.`);
    problems += 1;
  }
}

const haveOrigin = FILES.some((n) => existsSync(join(FROM, n)));
console.log(
  `\n  ${FILES.length} schema file(s)${haveOrigin ? '' : `  (${FROM} is not here — checked the copies only)`}\n`
);

process.exit(problems ? 1 : 0);
