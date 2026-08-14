#!/usr/bin/env bash
# Build one package via a fresh, privileged, --rm'd Ubuntu 26.04 container
# (the "builder" image — see builder/Containerfile), then import the
# resulting .debs into the local reprepro repo. Mirrors tunaos-packages'
# scripts/build-chain.sh (podman-run-per-package + shared local-repo),
# with sbuild/schroot's chroot-in-a-container step removed entirely —
# the --rm container instance IS the throwaway build environment.
set -euo pipefail

BUILD_IMAGE="localhost/debian-copr-builder:resolute"
LOCAL_REPO="${LOCAL_REPO:-$(pwd)/local-repo}"
DISTRIBUTION="${DISTRIBUTION:-resolute}"
# conf-unsigned (no SignWith) rather than conf (SignWith: default) — no GPG
# key is available in these intermediate build/import steps, only in the
# final publish job that re-exports and signs with the real key.
CONFDIR="$(pwd)/conf-unsigned"
MANIFEST="build-order-xfce.yml"
PACKAGE=""
FORCE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --package) PACKAGE="$2"; shift 2 ;;
        --manifest) MANIFEST="$2"; shift 2 ;;
        --force) FORCE=1; shift ;;
        --image) BUILD_IMAGE="$2"; shift 2 ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$PACKAGE" ]]; then
    echo "ERROR: --package <path> is required" >&2
    exit 1
fi

if [[ ! -f "$MANIFEST" ]] || ! grep -qF "path: ${PACKAGE}" "$MANIFEST"; then
    echo "ERROR: ${PACKAGE} not found in ${MANIFEST}" >&2
    exit 1
fi

pkg_name="$(basename "$PACKAGE")"
mkdir -p "$LOCAL_REPO"

# On the very first package ever built, the repo has no dists/<dist>/Release
# or Packages files yet — `apt-get update` inside the build container fails
# outright against a nonexistent index rather than an empty one. Export once
# up front so the repo always has valid (if empty) metadata to serve.
if [[ ! -f "${LOCAL_REPO}/dists/${DISTRIBUTION}/Release" ]]; then
    echo "==> Initializing empty local repo for ${DISTRIBUTION}..."
    reprepro -b "$LOCAL_REPO" --confdir "$CONFDIR" export "$DISTRIBUTION"
fi

# Already built and not forcing? Skip (mirrors tunaos-packages'
# 'skip if in repo' short-circuit).
if [[ "$FORCE" != "1" ]] && reprepro -b "$LOCAL_REPO" --confdir "$CONFDIR" list "$DISTRIBUTION" 2>/dev/null | grep -q " ${pkg_name} "; then
    echo "==> [${pkg_name}] already in repo; skipping (use --force to rebuild)"
    exit 0
fi

echo "==> [${pkg_name}] Fetching upstream source..."
srcdir="$(mktemp -d)"
trap 'rm -rf "$srcdir"' EXIT

if [[ ! -f "${PACKAGE}/upstream-source.txt" ]]; then
    echo "ERROR: ${PACKAGE}/upstream-source.txt not found" >&2
    exit 1
fi
url="$(cat "${PACKAGE}/upstream-source.txt")"
curl -fsSL "$url" -o "${srcdir}/src.tar.gz"
mkdir -p "${srcdir}/extracted"
tar -xzf "${srcdir}/src.tar.gz" -C "${srcdir}/extracted" --strip-components=1

# Overlay this package's debian/ packaging directory onto the extracted
# upstream source (same idea as an RPM Source0 tarball + a hand-written
# .spec sitting beside it — the packaging metadata isn't part of upstream).
cp -r "${PACKAGE}/debian" "${srcdir}/extracted/debian"

echo "==> [${pkg_name}] Building in ${BUILD_IMAGE}..."
resultdir="${srcdir}/result"
mkdir -p "$resultdir"

podman run --rm --privileged \
    -v "${srcdir}/extracted:/build/src:Z" \
    -v "${resultdir}:/build/out:Z" \
    -v "${LOCAL_REPO}:/local-repo:Z" \
    "${BUILD_IMAGE}" \
    bash -exc "
        # Resolve build-deps against the current local repo (earlier
        # tiers) plus Ubuntu's own archives.
        echo 'deb [trusted=yes] file:/local-repo ${DISTRIBUTION} main' > /etc/apt/sources.list.d/local-repo.list
        apt-get update -q
        cd /build/src
        mk-build-deps -i -r -t 'apt-get -y -q' debian/control
        dpkg-buildpackage -us -uc -b
        mkdir -p /build/out
        cp ../*.deb /build/out/
    "

echo "==> [${pkg_name}] Importing into local repo..."
flock "${LOCAL_REPO}/repo.lock" -c "
    for deb in ${resultdir}/*.deb; do
        reprepro -b '${LOCAL_REPO}' --confdir '${CONFDIR}' includedeb '${DISTRIBUTION}' \"\$deb\"
    done
"

echo "==> [${pkg_name}] Done."
