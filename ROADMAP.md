# debian-copr Roadmap

**Last updated**: 2026-08-24 | **Maintainer**: tuna-os (hanthor)

---

## Mission

Run the apt-world package pipeline for TunaOS: build and serve Debian/Ubuntu
packages (GitHub Actions + Cloudflare R2) — the sibling of tunaos-packages —
so the `grouper` variant (Ubuntu 26.04 bootc) gets the Wayland-native XFCE
stack (`xfwl4`) and every other apt-based variant gets its packages reliably.

---

## Current Status

- **Role**: Debian/Ubuntu APT build system; feeds grouper's XFCE stack.
- **Distribution**: package artifacts served via the apt pipeline (R2); the
  build system itself has **no tagged releases**.
- **Health**: 6 open issues — R2 credential interpolation (#18), README
  publish/architecture docs (#16/#17), build orchestration tests (#13),
  manifest/distributed workflow design (#12).

### Priorities

| Priority | Item | Tracking | Status |
|----------|------|----------|--------|
| P0 | R2 credential handling — no interpolation into `run:` blocks | #18 | 🟡 Open |
| P1 | README: published-use + current architecture | #16/#17 | 🟡 Open |
| P1 | Build-chain orchestration test coverage | #13 | 🟡 Open |
| P2 | Manifest + distributed workflow design | #12 | 🟡 Open |
| P2 | ROADMAP-coverage entry in org ROADMAP tally | #1295 | ⬜ Not started |

---

## Quarterly Goals

### Current Quarter (2026 Q3)

**Theme**: secure and document the pipeline

| Goal | Owner | Tracking | Status |
|------|-------|----------|--------|
| R2 credential handling fixed | hanthor | #18 | ⬜ Not started |
| README publish + architecture docs | hanthor | #16/#17 | ⬜ Not started |

### Next Quarter (2026 Q4)

**Theme**: deliver grouper parity

| Goal | Owner | Tracking | Status |
|------|-------|----------|--------|
| xfwl4/XFCE stack served for grouper | hanthor | (org parity #323) | ⬜ Not started |
| Build-chain orchestration tests | hanthor | #13 | ⬜ Not started |

---

*ROADMAP added by strategist agent (ACMM L6 — full mode). Signed-off-by: hanthor-hive-agent[bot] <290068839+hanthor-hive-agent[bot]@users.noreply.github.com>*
