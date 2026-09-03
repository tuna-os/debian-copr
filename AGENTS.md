# AGENTS.md — agent guide for tuna-os/debian-copr

The **APT half** of TunaOS's package build: `.deb`s for the Wayland-native
XFCE stack (`xfwl4` and friends) that Ubuntu's archives don't carry, built in
podman, indexed by `reprepro`, published to Cloudflare R2 and served from
`deb.tunaos.org`.

Human docs: [`README.md`](README.md) (including the exact local validation
commands), [`ROADMAP.md`](ROADMAP.md).

## It is a sibling, not an original

Everything here mirrors [`tuna-os/tunaos-packages`](https://github.com/tuna-os/tunaos-packages),
which builds the same stack as RPMs for EL10: the same tiered
`build-order-xfce.yml` schema, the same podman-run-per-package plus
shared-local-repo shape in `scripts/build-chain.sh`. When porting the next
component, **start from that repo's already-fixed spec** — the tier order and
the build fixes are worked out there first. The notable divergence is that
sbuild/schroot's chroot-in-a-container step is gone: the `--rm` container
*is* the throwaway build environment.

Status is early. `xfwl4` is the only package, and it exists to prove the
pipeline (a Rust/cargo build wrapped in a `.deb`, with no upstream Debian
packaging to crib from).

## Two reprepro configs, and which one is which

`scripts/build-chain.sh` uses **`conf-unsigned/`** (no `SignWith`), not
`conf/`. That is deliberate: no GPG key exists in the intermediate build and
import steps — only the final publish job re-exports and signs with the real
key. A build step that reaches for `conf/` will fail looking for a key that
isn't there.

Two more details of that script worth knowing before changing it:

- **The empty-repo export is load-bearing.** On the very first package, the
  repo has no `dists/<dist>/Release`, and `apt-get update` inside the build
  container fails outright against a nonexistent index rather than an empty
  one. The script exports once up front so there is always valid (if empty)
  metadata to serve.
- **Manifest membership is a substring match** — `grep -qF "path: ${PACKAGE}"`
  — so a path that is a *prefix* of a real entry passes the check and fails
  later, less legibly. Pass the full path exactly as it appears in
  `build-order-xfce.yml`.

## Checks

```bash
bash tests/test-build-chain.sh                    # 10 tests, ~1s, no install
shellcheck scripts/*.sh tests/*.sh
yamllint -d '{extends: default, rules: {line-length: disable}}' \
  build-order-xfce.yml conf/distributions .github/workflows/
```

The test suite needs nothing installed: it stubs `reprepro`, `curl`, `podman`
and the rest into a fixture `PATH`. A real package build does need `podman`,
`reprepro` and `flock` on the host plus the builder image
(`podman build -t localhost/debian-copr-builder:resolute -f builder/Containerfile builder/`).

`yamllint` reports two pre-existing warnings on `validate.yml`
(`document-start`, `truthy`). They are warnings, so the job stays green;
don't read them as a regression.

## Workflows

`validate.yml` runs on every push and PR. `build-xfce-distributed.yml` is
**manually dispatched only** — publishing is never automatic, and a package
only builds once every earlier tier is already in the repo.

Neither workflow has a `required-checks` aggregator job, so a skipped or
cancelled job would report an absent check rather than a failure. Worth
closing before branch protection or agent auto-merge is pointed here.

## Whitespace is significant in two places

`debian/rules` is a makefile — recipe lines need real tabs — and
`debian/patches/*.patch` are byte-exact, where trailing whitespace on a
context line is data. `.editorconfig` carries exemptions for both; don't let
an editor or a formatting sweep normalise them.
