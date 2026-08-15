# StackVo Service Packages

The service catalogue StackVo installs from. **Data, not code** — one directory
per version of one service, and nothing here runs on anybody's machine except as
a compose fragment the app renders.

Until this repository existed, StackVo carried its twenty-five services inside
its own binary: the templates under `skeleton/`, and six compile-time tables
naming them. Adding a service meant a release. The point of this tree is that it
does not.

## What is here

```text
packages/<category>/<service>/
├── package.json                 # identity: name, category, which version `latest` means
└── versions/<version>/
    ├── manifest.json            # the contract: image, ports, volumes, files, settings, hashes
    ├── compose.yml.tpl          # ONE compose service, no top-level keys
    └── files/…                  # config files the service mounts
```

**27 services, 107 versions.** Eight categories: `databases`, `cache`, `queue`,
`search`, `storage`, `monitoring`, `devtools`, `admin-uis`.

The last two — Solr and ClickHouse — are the first that were never templates in
the app's binary. Every other entry here arrived by migration; these arrived as
packages, which is what the tree was built for.

`registry.json` at the root is the index a client fetches first. It is
**generated** by `tools/build-registry.mjs` and never hand-edited — CI fails a
commit whose index disagrees with the tree beside it.

## Three things about the format

**`latest` is not a version.** A manifest whose image can move under it has no
fixed digest, so it has no place in the chain of trust that makes an installed
package verifiable. Each service's `package.json` names a `recommendedVersion`,
and that is what `latest` resolves to. When StackVo migrates a workspace that
says `latest`, it writes the concrete version it resolved to — so a re-pull can
no longer move somebody's version underneath them.

**A fragment is one service, and it names handles rather than things.** No
container name, no host port, no volume name is written literally:

```yaml
image: "{{ image }}"
container_name: "{{ instance.container }}"
volumes:
  - "{{ volume.data }}:/var/lib/mysql"
ports:
  - "{{ port.main }}:3306"
```

The app resolves those per instance, which is what lets `mysql@8.0` and
`mysql@9.4` run side by side with separate data. It is also why the old
templates could not: eighteen of them hardcoded a volume like
`stackvo-mysql-data`, and two versions sharing one is not an error Docker
reports — the newer engine opens the older one's data directory and upgrades it.

**`support` is measured, not asserted.** `tools/eol.mjs` checks every version
against endoflife.date. The first run corrected twenty of a hundred and one, and
three of those were StackVo's own shipped defaults. A version that reads
`supported` and is not is one the picker recommends and nobody patches.

An end-of-life version is still **published** — it is hidden behind "show older
versions", not withdrawn. Somebody's workspace names it today, and removing it
would strand their migration.

## Checks

```bash
node tools/validate.mjs           # schema, cross-references, hashes on disk
node tools/build-registry.mjs     # rebuild registry.json
node tools/compose-check.mjs      # docker compose config + the policy allowlist
node tools/probe-tags.mjs         # does every image tag still exist        (network)
node tools/eol.mjs                # is every support status still true      (network)
node tools/check-schema-sync.mjs  # is schema/ still the copy it claims to be
```

Zero dependencies. Everything runs on a fresh clone with Node and nothing else;
`compose-check` uses Docker when it is there and falls back to the policy half
when it is not.

The two that need the network report rather than fail, and that is deliberate: a
gate that fails because Docker Hub rate-limited a runner is a gate people learn
to re-run instead of read. `--strict` makes them fail, and the release job uses
it.

## The policy allowlist

`schema/compose-policy.json` says what a fragment may declare. It is an
**allowlist** — a key nobody has considered is refused, and adding one is a
review.

This is the part worth reading before contributing a package. A compose service
is not a passive description: `privileged: true`, `network_mode: host`, a
`build:` context, or a bind mount of `/var/run/docker.sock` are each root on
somebody's machine, in one line. The same file is read by the app after it
renders a fragment, so the check runs at publish time as a review and at install
time as a defence — a repository somebody has taken over can serve anything, and
a check that only ever ran here would not be there when it did.

## Schemas

`schema/` holds copies of the contracts, which are authored in
[`stackvo/contracts`](https://github.com/stackvo/stackvo). `check-schema-sync.mjs`
keeps the copies honest; edit the originals and re-run it with `--update`.

| File | What it fixes in place |
| --- | --- |
| `package.schema.json` | A service's identity, shared across its versions |
| `package-version.schema.json` | One version: image, ports, volumes, files, settings, connection, hashes |
| `registry.schema.json` | The generated index |
| `compose-policy.json` | What a fragment may declare, and why each refusal is a refusal |

## Adding a version

1. Copy the newest version directory to the new version's name.
2. Update `manifest.json`: `version`, `image.tag`, anything that genuinely
   differs between the series — an authentication default, a config key that was
   renamed. A directory per version is the point: a template with a conditional
   in it is a program, and a program is not what this repository ships.
3. Re-hash: the manifest states the sha256 of every file beside it.
4. `node tools/validate.mjs && node tools/build-registry.mjs`
5. Point `recommendedVersion` at it only if it should be what `latest` means.

The packages here were generated from StackVo's own templates by
`cargo run --example build_packages` in the app repository, and that path stays
open: it reads the catalogue, the versions and the connection shapes from the
app rather than restating them, and refuses any template it does not recognise.
