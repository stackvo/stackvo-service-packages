#!/usr/bin/env node
/**
 * validate — is this tree a set of packages a StackVo client would install?
 *
 *   node tools/validate.mjs [--json]
 *
 * Three layers, and the order matters because each assumes the one before it:
 *
 *   1. **Schema.** Every `package.json` and `manifest.json` against
 *      `schema/*.json`, with `additionalProperties: false` doing most of the
 *      work — a field on one side only is the drift that is hardest to see.
 *   2. **Structure.** What JSON Schema cannot say: that a directory is named
 *      for the service inside it, that `connection.port` names a port the
 *      manifest declares, that `recommendedVersion` is a version that exists,
 *      that every version of a service agrees about `instancing`.
 *   3. **Content.** That the sha256 in a manifest is the sha256 of the file
 *      beside it. This is the link a client checks on every read, so a tree
 *      that fails it is a tree nobody can install.
 *
 * Zero dependencies, and no network. `eol.mjs` and `probe-tags.mjs` are where
 * network-shaped truth lives, and they are separate precisely so this can be a
 * gate.
 */

import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs';
import { join, dirname, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';

import { validate as againstSchema } from './lib/schema.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..');
const PACKAGES = join(ROOT, 'packages');

const asJson = process.argv.includes('--json');

const findings = [];
const err = (subject, code, message) => findings.push({ level: 'error', subject, code, message });
const warn = (subject, code, message) => findings.push({ level: 'warn', subject, code, message });

const readJson = (path) => JSON.parse(readFileSync(path, 'utf8'));
const sha256 = (path) => createHash('sha256').update(readFileSync(path)).digest('hex');
const dirs = (path) =>
  existsSync(path)
    ? readdirSync(path).filter((n) => !n.startsWith('.') && statSync(join(path, n)).isDirectory())
    : [];

/// Services that may ship without a healthcheck, and why.
///
/// Deliberately keyed by service rather than by version: "this one cannot be
/// asked whether it is ready" is a fact about what the software is, and a
/// version-shaped exemption would be a place for one to hide.
const HEALTH_EXEMPT = {
  blackfire:
    'the agent is an outbound probe. It opens no readiness endpoint, and a check that ' +
    'proved the process was running would pass for a reason unrelated to whether profiling works.',
};

/**
 * Who may be named as a maintainer here.
 *
 * `maintainer` is a free string in the schema, and the app shows it on the
 * market card. Those two facts together are an impersonation hole with nothing
 * in between them: a pull request could name `stackvo` as the publisher of
 * anything and every user would read a name that nobody had checked.
 *
 * The check belongs here rather than in the client, and that is the whole of
 * the trust argument: the index is signed by the registry key **after** these
 * gates run, so the signature is what carries "the registry vouches for this",
 * and the maintainer strings are inside what it covers. A client cannot verify
 * an identity claim on its own — it can only verify that the registry made it.
 */
const publishers = new Set(
  readJson(join(ROOT, 'publishers.json')).publishers.map((p) => p.id),
);

const packageSchema = readJson(join(ROOT, 'schema/package.schema.json'));
const versionSchema = readJson(join(ROOT, 'schema/package-version.schema.json'));

// ---------------------------------------------------------------- the walk

let serviceCount = 0;
let versionCount = 0;

for (const category of dirs(PACKAGES)) {
  for (const service of dirs(join(PACKAGES, category))) {
    const serviceDir = join(PACKAGES, category, service);
    const at = `${category}/${service}`;
    serviceCount += 1;

    // ---- package.json ---------------------------------------------------
    const identityPath = join(serviceDir, 'package.json');
    if (!existsSync(identityPath)) {
      err(at, 'NO_PACKAGE_JSON', 'a service directory with no identity file');
      continue;
    }

    let identity;
    try {
      identity = readJson(identityPath);
    } catch (e) {
      err(at, 'UNREADABLE', `package.json: ${e.message}`);
      continue;
    }

    for (const problem of againstSchema(identity, packageSchema)) {
      err(at, 'SCHEMA', `package.json${problem}`);
    }

    // The directory IS the identity. A mismatch means one of the two is a
    // typo, and which one is not knowable from here — so both are named.
    if (identity.service !== service) {
      err(at, 'NAME_MISMATCH', `package.json says service ${JSON.stringify(identity.service)}`);
    }
    if (identity.category !== category) {
      err(at, 'CATEGORY_MISMATCH', `package.json says category ${JSON.stringify(identity.category)}`);
    }

    // Who is answerable for it, and whether that is somebody this repository
    // has accepted. Required here even though the schema leaves it optional:
    // the schema describes a package anywhere, and this is the official set,
    // where an unnamed publisher is a package nobody is answerable for.
    if (!identity.maintainer) {
      err(at, 'NO_MAINTAINER', 'package.json names no maintainer, so nobody is answerable for it');
    } else if (!publishers.has(identity.maintainer)) {
      err(
        at,
        'UNKNOWN_PUBLISHER',
        `package.json names ${JSON.stringify(identity.maintainer)}, which publishers.json does not list — ` +
          'accepting a publisher is a decision of its own (CONTRIBUTING.md)',
      );
    }

    // ---- versions ---------------------------------------------------------
    const versionsDir = join(serviceDir, 'versions');
    const versions = dirs(versionsDir);
    if (!versions.length) {
      err(at, 'NO_VERSIONS', 'a service with nothing to install');
      continue;
    }

    const instancing = new Set();
    const capabilities = new Set();

    for (const version of versions) {
      const versionDir = join(versionsDir, version);
      const vat = `${at}@${version}`;
      versionCount += 1;

      const manifestPath = join(versionDir, 'manifest.json');
      if (!existsSync(manifestPath)) {
        err(vat, 'NO_MANIFEST', 'a version directory with no manifest');
        continue;
      }

      let manifest;
      try {
        manifest = readJson(manifestPath);
      } catch (e) {
        err(vat, 'UNREADABLE', `manifest.json: ${e.message}`);
        continue;
      }

      for (const problem of againstSchema(manifest, versionSchema)) {
        err(vat, 'SCHEMA', `manifest.json${problem}`);
      }

      if (manifest.service !== service) {
        err(vat, 'NAME_MISMATCH', `manifest says service ${JSON.stringify(manifest.service)}`);
      }
      if (manifest.version !== version) {
        err(vat, 'VERSION_MISMATCH', `manifest says version ${JSON.stringify(manifest.version)}`);
      }

      instancing.add(manifest.instancing?.multiple);
      for (const c of manifest.capabilities ?? []) capabilities.add(c);

      // ---- the cross-references a schema cannot express -------------------
      const portNames = new Set((manifest.ports ?? []).map((p) => p.name));
      if (manifest.connection && !portNames.has(manifest.connection.port)) {
        err(vat, 'DANGLING_PORT', `connection is built from port ${JSON.stringify(manifest.connection.port)}`);
      }
      if (manifest.url && !portNames.has(manifest.url.port)) {
        err(vat, 'DANGLING_PORT', `the router forwards to port ${JSON.stringify(manifest.url.port)}`);
      }
      if ((manifest.ports ?? []).filter((p) => p.primary).length > 1) {
        err(vat, 'TWO_PRIMARY_PORTS', 'a connection string would be built from whichever came first');
      }

      const settingKeys = new Set((manifest.settings ?? []).map((s) => s.key));
      for (const key of ['userSetting', 'passwordSetting', 'databaseSetting']) {
        const named = manifest.connection?.[key];
        if (named && !settingKeys.has(named)) {
          err(vat, 'DANGLING_SETTING', `connection.${key} names ${JSON.stringify(named)}`);
        }
      }

      // A real credential in a manifest is the mistake CONFLICTS.md C-18
      // records the previous round of. The defaults here are first-boot
      // placeholders and are meant to look like it.
      for (const setting of manifest.settings ?? []) {
        if (setting.type !== 'secret') continue;
        const value = String(setting.default ?? '');
        if (value.length > 24) {
          err(vat, 'SECRET_LOOKS_REAL', `${setting.key} has a ${value.length}-character default`);
        }
      }

      // ---- the fragment reads its handles, and only its handles -----------
      const composePath = join(versionDir, manifest.compose?.file ?? '');
      if (!existsSync(composePath)) {
        err(vat, 'NO_FRAGMENT', `${manifest.compose?.file} is not there`);
      } else {
        if (sha256(composePath) !== manifest.compose.sha256) {
          err(vat, 'HASH', `${manifest.compose.file} is not the file the manifest describes`);
        }
        const fragment = readFileSync(composePath, 'utf8');
        // A fragment is ONE service body, written at indent zero — so its own
        // `volumes:`, `ports:` and `networks:` keys live at column zero and are
        // correct there. What must not appear is `services:`, which would make
        // the assembled file nest a service inside a service and render
        // nothing at all.
        //
        // The first version of this check forbade `volumes:` too and failed
        // every one of the hundred and one packages. Worth leaving the reason
        // written down: in a whole compose file `volumes:` at column zero is
        // the top-level declaration, and in a fragment it is the service's own
        // list. Same bytes, opposite meanings.
        if (/^services:/m.test(fragment)) {
          err(vat, 'NOT_A_FRAGMENT', 'the compose file declares a top-level services: key');
        }
        for (const [, handle] of fragment.matchAll(/\{\{\s*port\.([a-z0-9-]+)\s*\}\}/g)) {
          if (!portNames.has(handle)) {
            err(vat, 'DANGLING_HANDLE', `the fragment reads {{ port.${handle} }}`);
          }
        }
        const volumeNames = new Set((manifest.volumes ?? []).map((v) => v.name));
        for (const [, handle] of fragment.matchAll(/\{\{\s*volume\.([a-z0-9-]+)\s*\}\}/g)) {
          if (!volumeNames.has(handle)) {
            err(vat, 'DANGLING_HANDLE', `the fragment reads {{ volume.${handle} }}`);
          }
        }
        const fileNames = new Set((manifest.files ?? []).map((f) => f.name));
        for (const [, handle] of fragment.matchAll(/\{\{\s*file\.([a-z0-9_-]+)\s*\}\}/g)) {
          if (!fileNames.has(handle)) {
            err(vat, 'DANGLING_HANDLE', `the fragment reads {{ file.${handle} }}`);
          }
        }
        for (const [, key] of fragment.matchAll(/\{\{\s*settings\.([A-Z0-9_]+)\s*\}\}/g)) {
          if (!settingKeys.has(key)) {
            err(vat, 'DANGLING_HANDLE', `the fragment reads {{ settings.${key} }}`);
          }
        }
      }

      // ---- shipped files ---------------------------------------------------
      for (const file of manifest.files ?? []) {
        const path = join(versionDir, file.template);
        if (!existsSync(path)) {
          err(vat, 'NO_FILE', `${file.template} is declared and not there`);
          continue;
        }
        if (sha256(path) !== file.sha256) {
          err(vat, 'HASH', `${file.template} is not the file the manifest describes`);
        }

        // A config template is rendered by the same substituter as the compose
        // fragment, so it is under the same rule: every handle is one the
        // manifest declares. This check was missing, and what it would have
        // caught is exactly what got through — `redis.conf.tpl` reading
        // `{{ REDIS_PASSWORD }}` and `elasticsearch.yml.tpl` reading
        // `{{ ELASTIC_SECURITY }}`, neither declared anywhere. The client
        // refused the package at render time, which is the right answer at the
        // wrong end of the pipeline.
        const template = readFileSync(path, 'utf8');
        for (const [, key] of template.matchAll(/\{\{\s*settings\.([A-Z0-9_]+)\s*\}\}/g)) {
          if (!settingKeys.has(key)) {
            err(vat, 'DANGLING_HANDLE', `${file.template} reads {{ settings.${key} }}`);
          }
        }
        for (const [, whole] of template.matchAll(/\{\{\s*([^}]*?)\s*\}\}/g)) {
          const name = whole.split('|')[0].trim();
          if (!/^(settings|port|volume|file|instance|companion)\./.test(name) && name !== 'image' && name !== 'network') {
            err(vat, 'RAW_PLACEHOLDER', `${file.template} reads {{ ${name} }}, which is not a handle`);
          }
        }
      }
      // ---- readiness --------------------------------------------------
      //
      // A package without a healthcheck is not a package with a lenient one:
      // `depends_on: condition: service_healthy` against a service that never
      // declared readiness waits for the process to exist and calls that
      // healthy. `docker compose up --wait` did exactly that for the whole
      // catalogue and reported two MySQLs up that both refused connections —
      // the container was building its datadir.
      //
      // So the absence has to be a sentence somebody wrote, not a field
      // somebody skipped. NO_HEALTH is an error; the way to satisfy it is a
      // healthcheck or a line in this table.
      if (!manifest.health) {
        const why = HEALTH_EXEMPT[manifest.service];
        if (!why) {
          err(
            vat,
            'NO_HEALTH',
            'declares no healthcheck. Add one to the manifest, or add this service to ' +
              'HEALTH_EXEMPT in tools/validate.mjs with the reason it cannot have one'
          );
        }
      }
      for (const companion of manifest.companions ?? []) {
        const path = join(versionDir, companion.compose.file);
        if (!existsSync(path)) {
          err(vat, 'NO_FILE', `${companion.compose.file} is declared and not there`);
        } else if (sha256(path) !== companion.compose.sha256) {
          err(vat, 'HASH', `${companion.compose.file} is not the file the manifest describes`);
        }
      }

      // Nothing may ship that no manifest claims: an unreferenced file is
      // either dead weight or a file somebody expected to be mounted.
      const shipped = new Set([
        'manifest.json',
        manifest.compose?.file,
        ...(manifest.companions ?? []).map((c) => c.compose.file),
      ]);
      for (const name of readdirSync(versionDir)) {
        if (name === 'files' || shipped.has(name)) continue;
        warn(vat, 'UNCLAIMED_FILE', `${name} is in the package and no manifest field names it`);
      }
      const filesDir = join(versionDir, 'files');
      if (existsSync(filesDir)) {
        const claimed = new Set((manifest.files ?? []).map((f) => f.template.replace(/^files\//, '')));
        for (const name of readdirSync(filesDir)) {
          if (!claimed.has(name)) {
            warn(vat, 'UNCLAIMED_FILE', `files/${name} is not declared`);
          }
        }
      }
    }

    // ---- facts that must hold across a service's versions -----------------
    if (instancing.size > 1) {
      err(at, 'INSTANCING_DRIFT', 'some versions allow multiple instances and some do not');
    }
    if (identity.recommendedVersion && !versions.includes(identity.recommendedVersion)) {
      err(
        at,
        'RECOMMENDED_MISSING',
        `recommendedVersion is ${JSON.stringify(identity.recommendedVersion)}, which is not published — ` +
          'and that is what `latest` resolves to'
      );
    }
    if (!identity.recommendedVersion) {
      err(at, 'NO_RECOMMENDED', 'nothing says which version `latest` means');
    }
  }
}

// ---------------------------------------------------------------- the index

// Checked here as well as by `build-registry.mjs --check`, and the two ask
// different questions: that one asks whether the index matches the tree, this
// one whether it is a document the schema allows. A generated file can be
// faithfully generated and still be invalid, which is how a schema change
// lands without anybody noticing.
{
  const registryPath = join(ROOT, 'registry.json');
  if (!existsSync(registryPath)) {
    warn('registry.json', 'NOT_BUILT', 'run `node tools/build-registry.mjs`');
  } else {
    const registrySchema = readJson(join(ROOT, 'schema/registry.schema.json'));
    let registry;
    try {
      registry = readJson(registryPath);
    } catch (e) {
      err('registry.json', 'UNREADABLE', e.message);
      registry = null;
    }
    if (registry) {
      for (const problem of againstSchema(registry, registrySchema)) {
        err('registry.json', 'SCHEMA', problem);
      }
      for (const entry of registry.packages ?? []) {
        const recommended = (entry.versions ?? []).filter((v) => v.recommended);
        if (recommended.length !== 1) {
          err(
            `registry.json/${entry.service}`,
            'RECOMMENDED_COUNT',
            `${recommended.length} version(s) are recommended, and \`latest\` resolves to exactly one`
          );
        }
      }
    }
  }
}

// ---------------------------------------------------------------- output

const errors = findings.filter((f) => f.level === 'error');
const warns = findings.filter((f) => f.level === 'warn');

if (asJson) {
  console.log(JSON.stringify({ services: serviceCount, versions: versionCount, errors, warnings: warns }, null, 2));
} else {
  console.log(`\nstackvo service packages — validate`);
  console.log(`  ${serviceCount} service(s), ${versionCount} version(s), under ${relative(ROOT, PACKAGES)}/\n`);
  for (const f of findings) {
    const tag = f.level === 'error' ? 'ERROR' : 'warn ';
    console.log(`  ${tag} ${f.code.padEnd(20)} ${f.subject}`);
    console.log(`        ${f.message}`);
  }
  if (findings.length) console.log('');
  console.log(`  ${errors.length} error(s), ${warns.length} warning(s)\n`);
}

process.exit(errors.length ? 1 : 0);
