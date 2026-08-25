#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS=0

fail() {
    echo "not ok ${TESTS} - $*" >&2
    exit 1
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain: ${needle}"
}

new_fixture() {
    FIXTURE="$(mktemp -d)"
    mkdir -p "$FIXTURE/bin" "$FIXTURE/project/scripts" \
        "$FIXTURE/project/src/xfce-wayland/xfwl4/debian" \
        "$FIXTURE/project/conf-unsigned"
    cp "$ROOT/scripts/build-chain.sh" "$FIXTURE/project/scripts/"
    cp "$ROOT/build-order-xfce.yml" "$FIXTURE/project/"
    touch "$FIXTURE/project/src/xfce-wayland/xfwl4/debian/control"
    printf '%s\n' 'https://example.invalid/xfwl4.tar.gz' \
        > "$FIXTURE/project/src/xfce-wayland/xfwl4/upstream-source.txt"

    cat > "$FIXTURE/bin/reprepro" <<'EOF'
#!/usr/bin/env bash
echo "reprepro $*" >> "$CALL_LOG"
if [[ " $* " == *" list "* && "${FAKE_ALREADY_BUILT:-0}" == 1 ]]; then
    echo "resolute|main|amd64: xfwl4 0.1 amd64"
fi
EOF
    cat > "$FIXTURE/bin/curl" <<'EOF'
#!/usr/bin/env bash
echo "curl $*" >> "$CALL_LOG"
output=""
while (($#)); do
    if [[ "$1" == -o ]]; then output="$2"; break; fi
    shift
done
: > "$output"
EOF
    cat > "$FIXTURE/bin/tar" <<'EOF'
#!/usr/bin/env bash
echo "tar $*" >> "$CALL_LOG"
while (($#)); do
    if [[ "$1" == -C ]]; then mkdir -p "$2"; break; fi
    shift
done
EOF
    cat > "$FIXTURE/bin/podman" <<'EOF'
#!/usr/bin/env bash
echo "podman $*" >> "$CALL_LOG"
for arg in "$@"; do
    if [[ "$arg" == *:/build/out:Z ]]; then
        resultdir="${arg%:/build/out:Z}"
        : > "$resultdir/xfwl4_0.1_amd64.deb"
    fi
done
EOF
    chmod +x "$FIXTURE/bin/"*
    CALL_LOG="$FIXTURE/calls.log"
    : > "$CALL_LOG"
    export CALL_LOG
}

cleanup_fixture() {
    rm -rf "$FIXTURE"
}

run_test() {
    local name="$1"
    shift
    TESTS=$((TESTS + 1))
    new_fixture
    if "$@"; then
        echo "ok ${TESTS} - ${name}"
        cleanup_fixture
    else
        cleanup_fixture
        fail "$name"
    fi
}

test_requires_package() {
    local output
    if output="$(cd "$FIXTURE/project" && PATH="$FIXTURE/bin:$PATH" ./scripts/build-chain.sh 2>&1)"; then
        return 1
    fi
    assert_contains "$output" "--package <path> is required"
}

test_rejects_unknown_argument() {
    local output
    if output="$(cd "$FIXTURE/project" && PATH="$FIXTURE/bin:$PATH" ./scripts/build-chain.sh --wat 2>&1)"; then
        return 1
    fi
    assert_contains "$output" "Unknown arg: --wat"
}

test_rejects_package_outside_manifest() {
    mkdir -p "$FIXTURE/project/src/xfce-wayland/other"
    local output
    if output="$(cd "$FIXTURE/project" && PATH="$FIXTURE/bin:$PATH" ./scripts/build-chain.sh --package src/xfce-wayland/other 2>&1)"; then
        return 1
    fi
    assert_contains "$output" "not found in build-order-xfce.yml"
}

test_skips_existing_package() {
    mkdir -p "$FIXTURE/project/local-repo/dists/resolute"
    touch "$FIXTURE/project/local-repo/dists/resolute/Release"
    local output
    output="$(cd "$FIXTURE/project" && FAKE_ALREADY_BUILT=1 PATH="$FIXTURE/bin:$PATH" \
        ./scripts/build-chain.sh --package src/xfce-wayland/xfwl4 2>&1)"
    assert_contains "$output" "already in repo; skipping"
    ! grep -q '^curl ' "$CALL_LOG"
    ! grep -q '^podman ' "$CALL_LOG"
}

test_force_builds_and_initializes_repo() {
    local output
    output="$(cd "$FIXTURE/project" && FAKE_ALREADY_BUILT=1 PATH="$FIXTURE/bin:$PATH" \
        ./scripts/build-chain.sh --package src/xfce-wayland/xfwl4 --force 2>&1)"
    assert_contains "$output" "Initializing empty local repo"
    assert_contains "$output" "Done."
    grep -q ' export resolute$' "$CALL_LOG"
    grep -q '^curl ' "$CALL_LOG"
    grep -q '^podman run ' "$CALL_LOG"
    grep -q ' includedeb resolute ' "$CALL_LOG"
}

test_rejects_missing_upstream_source() {
    rm -f "$FIXTURE/project/src/xfce-wayland/xfwl4/upstream-source.txt"
    local output
    if output="$(cd "$FIXTURE/project" && PATH="$FIXTURE/bin:$PATH" ./scripts/build-chain.sh --package src/xfce-wayland/xfwl4 2>&1)"; then
        return 1
    fi
    assert_contains "$output" "upstream-source.txt not found"
}

run_test "requires --package" test_requires_package
run_test "rejects unknown arguments" test_rejects_unknown_argument
run_test "rejects packages outside the manifest" test_rejects_package_outside_manifest
run_test "skips packages already in the repository" test_skips_existing_package
run_test "--force builds and initializes an empty repository" test_force_builds_and_initializes_repo
run_test "rejects packages missing upstream-source.txt" test_rejects_missing_upstream_source

echo "1..${TESTS}"
