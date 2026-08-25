# Submitting a package

This repository is the catalogue StackVo installs from. A package here is not a
document: it is a compose fragment that reaches somebody's Docker daemon, and
the right four words in one are root on their host (`SECURITY.md`, T-3). So a
submission is reviewed, and this page says what the review is — because a
review whose rules are not written down is a review that changes with whoever
does it.

Most of it is not judgement. The gates in `.github/workflows/ci.yml` already
decide most of what a reviewer would otherwise be trusted to notice, and they
decide it the same way every time. What is left for a person is small, and it
is named at the bottom.

## What the gates already settle

Run them before you open anything — `npm run check` is all of them:

| Gate                          | What it refuses                                                                     |
| ----------------------------- | ----------------------------------------------------------------------------------- |
| `check-schema-sync.mjs`       | a `schema/` copy that has drifted from the app's `contracts/`                        |
| `validate.mjs`                | a manifest that does not match its schema, a name or version that disagrees with its directory, a port or handle nothing declares, a `secret` with a real-looking default, a file whose sha256 is not what the manifest says, **a maintainer this repository has not accepted** |
| `build-registry.mjs --check`  | an index that is not a fresh build of the tree beside it                             |
| `verify-signature.mjs`        | a signature that no longer covers the index                                          |
| `compose-check.mjs`           | a fragment that is not valid Compose, or that leaves the allowlist in `schema/compose-policy.json` |

The allowlist is the one to read before writing a fragment. It is what answers
T-3, and it is checked twice — here before publication, and again inside the
app after the fragment is rendered, because only the second is still standing
if this repository is ever taken over.

## What you send

1. A directory at `packages/<category>/<service>/` with a `package.json`, and
   `versions/<version>/manifest.json` under it. The shapes are in `schema/`,
   and `README.md` walks through adding a version to a service that exists.
2. `maintainer` in `package.json`, naming an `id` from `publishers.json`.
3. `npm run check`, green, before you open the pull request.

## Being a publisher

`maintainer` is a free string in the schema and the app **shows it on the
market card**. Those two facts together would be an impersonation hole with
nothing in between: a pull request could name `stackvo` as the publisher of
anything, and every user would read a name nobody had checked. A name on a card
reads as something somebody checked, so `publishers.json` is the checking, and
`validate.mjs` refuses any maintainer that is not in it.

That check lives here rather than in the app, and the reason is the whole trust
argument: the index is signed with the registry key **after** these gates run,
so the signature is what carries *the registry vouches for this*, and the
maintainer strings are inside what it covers. A client cannot verify an identity
claim on its own. It can only verify that the registry made it.

**Adding a publisher is a separate pull request from adding a package**, and
deliberately so. Bundling them means the decision that matters — do we vouch
for this person — arrives as a line inside a diff about YAML, and gets the
attention a line inside a diff about YAML gets.

## What a person still decides

Three things, and only three. Everything above is a gate; this is the part a
gate cannot hold.

1. **Whether to vouch for a publisher.** The entry in `publishers.json` is this
   repository saying it knows who this is. What counts as knowing is not
   something a file can settle.
2. **Whether the service belongs in the catalogue at all.** Passing every gate
   only means a package is well-formed. Whether StackVo should offer it — and
   keep offering it, because a catalogue entry is a maintenance commitment — is
   a judgement.
3. **Whether the image is one to hand to a stranger's daemon.** The gates check
   the fragment; nobody can check the image from here. A pinned digest and a
   publisher who is answerable for it are what stand in for that, which is why
   both are required rather than encouraged.

## After a merge

The index is generated and signed, and the signature is made by hand on the one
machine holding the content key — deliberately not a CI secret, because a
content key every workflow can reach is not a content key.

```
node tools/build-registry.mjs
tools/keys.sh sign registry.json      # in the app repository checkout
```

Both files go in one commit. A regenerated index published without a fresh
signature is **refused** by every installed copy of the app rather than
downgraded, which is correct and is why `verify-signature.mjs` fails the build
instead of leaving it to memory.
