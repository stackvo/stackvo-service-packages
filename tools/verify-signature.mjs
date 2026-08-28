#!/usr/bin/env node
/**
 * Does `registry.json.minisig` verify over `registry.json`, against the key the
 * app pins?
 *
 * ## Why this exists at all
 *
 * `registry.json` is generated and committed, and the signature beside it is
 * made by hand on the one machine that holds the private key. So the two can
 * come apart in the most ordinary way there is: somebody adds a package, runs
 * `build-registry.mjs`, commits, and does not re-sign.
 *
 * That is not a soft failure downstream. A signature that no longer matches is
 * a **refusal** in the app — deliberately, because a signature that verifies
 * against nothing is evidence, not noise — so forgetting this step takes the
 * catalogue away from every user at once, and nothing here would have said so.
 * The rule cannot live in somebody's memory; it has to fail a build.
 *
 * ## Why it is written out rather than shelling to minisign
 *
 * `minisign` is not on a GitHub runner and would be an apt install in the one
 * job whose whole purpose is to be trustworthy. Node has Ed25519 and this
 * repository's tools are already zero-dependency `.mjs`, so the verification is
 * sixty lines of format handling and one `crypto.verify`.
 *
 * The format, for whoever reads this next:
 *
 *   a .pub file       untrusted comment line, then base64( "Ed" | keyid[8] | key[32] )
 *   a .minisig file   untrusted comment, base64( algo[2] | keyid[8] | sig[64] ),
 *                     trusted comment, base64( global signature )
 *   algo              "ED" signs the file's BLAKE2b-512; "Ed" signs the bytes
 *
 * `tauri signer` wraps that whole .minisig file in base64 a second time,
 * because the updater manifest carries a signature as one JSON string — so the
 * envelope is peeled first if it is there. The app does exactly the same, for
 * the same reason.
 *
 *   node tools/verify-signature.mjs
 */

import { createHash, createPublicKey, verify as edVerify } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

/**
 * The key `signing::PINNED` carries in the app. Public half — safe to commit.
 *
 * A copy, and the second one: the app is the authority and this file cannot
 * read it, so the two agree by somebody keeping them in step. That is a real
 * cost and it was paid the first time the key rotated — this line still named
 * the old key after the app had moved on, so a correctly signed index was
 * reported as signed with the wrong key. **Rotating the content key means
 * editing here as well as in `signing.rs`.**
 *
 * The alternative would be fetching the app's source to read the constant,
 * which trades a copy for a network dependency in a gate whose whole job is to
 * work offline. The copy is the cheaper wrong thing; this note is what makes
 * it survivable.
 */
const PINNED = 'RWSW56bSXoFQm+jNBGKcK6qbvyrG/bMqQ16lHJrhOgAmQUz840qNUYc+';

const die = (message) => {
  console.error(`✗ ${message}`);
  process.exit(1);
};

/** Raw Ed25519 public key bytes wrapped as SPKI, which is what Node will take. */
const publicKeyFrom = (raw) =>
  createPublicKey({
    key: Buffer.concat([
      Buffer.from('302a300506032b6570032100', 'hex'),
      Buffer.from(raw),
    ]),
    format: 'der',
    type: 'spki',
  });

/** The line of a minisign file that is not a comment. */
const payloadLine = (text, which) => {
  const lines = text.trim().split('\n');
  const line = lines[which];
  if (!line) die('the signature file does not have the shape minisign writes');
  return Buffer.from(line.trim(), 'base64');
};

/** `tauri signer` base64-encodes the whole file again; the app peels it too. */
const peeled = (text) => {
  const trimmed = text.trim();
  if (trimmed.startsWith('untrusted comment:')) return trimmed;
  const decoded = Buffer.from(trimmed, 'base64').toString('utf8');
  return decoded.trimStart().startsWith('untrusted comment:') ? decoded : trimmed;
};

const index = readFileSync(join(ROOT, 'registry.json'));
let signatureFile;
try {
  signatureFile = peeled(readFileSync(join(ROOT, 'registry.json.minisig'), 'utf8'));
} catch {
  die(
    'registry.json.minisig is not here. The index is signed by hand on the machine \n' +
      '  that holds the content key:  tools/keys.sh sign registry.json  (in the app repo)',
  );
}

const key = Buffer.from(PINNED, 'base64');
if (key.length !== 42) die(`the pinned key is ${key.length} bytes, and a minisign key is 42`);
const keyId = key.subarray(2, 10);
const publicKey = publicKeyFrom(key.subarray(10));

const signature = payloadLine(signatureFile, 1);
if (signature.length !== 74) {
  die(`the signature is ${signature.length} bytes, and a minisign signature is 74`);
}

const algorithm = signature.subarray(0, 2).toString('latin1');
if (!signature.subarray(2, 10).equals(keyId)) {
  die(
    `the signature names key ${signature.subarray(2, 10).toString('hex')} and the app ` +
      `pins ${keyId.toString('hex')} — it was signed with the wrong key, and every ` +
      'installed copy of the app would refuse it',
  );
}

if (algorithm !== 'Ed' && algorithm !== 'ED') {
  die(`the signature declares algorithm ${JSON.stringify(algorithm)}, which is not minisign's`);
}

// "ED" signs the digest, "Ed" signs the file — that way round, and it is worth
// stating because guessing it the other way produces a verifier that refuses a
// perfectly good signature and blames the index. Both are minisign; which one
// you get depends on the tool, so both are read rather than assumed.
const signed =
  algorithm === 'ED' ? createHash('blake2b512').update(index).digest() : index;

if (!edVerify(null, signed, publicKey, signature.subarray(10))) {
  die(
    'the signature does not match registry.json.\n' +
      '  The usual cause is the index being regenerated without being signed again:\n' +
      '      node tools/build-registry.mjs        # here\n' +
      '      tools/keys.sh sign registry.json     # in the app repo, then commit both\n' +
      '  Left as it is, every user’s catalogue is refused rather than downgraded.',
  );
}

console.log(`✓ registry.json is signed by ${keyId.toString('hex').toUpperCase()}, the key the app pins`);
