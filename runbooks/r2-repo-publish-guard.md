# Runbook: R2 apt repo publish workflow wipes production packages

## When to use this

`.github/workflows/build-xfce-distributed.yml`'s `publish` job runs
`rclone sync local-repo/ r2:${R2_BUCKET}/deb/26.04-resolute/` against the
production apt repo served at `deb.tunaos.org`. Use this runbook if:

* `Release` / `Packages` at the `26.04-resolute` prefix advertises fewer
  packages than a previous run, or a package that should be published is
  missing from the served index.
* A publish run's `local-repo` artifact (downloaded from the preceding build
  job) is smaller than expected, or empty, right before the `Publish to R2`
  step runs.

## Why this happens

`rclone sync SRC DST` makes `DST` match `SRC` exactly — anything present in
`DST` but not in `SRC` is deleted. This workflow's `publish` job builds
`local-repo` from scratch every run (`scripts/build-chain.sh` starts with an
empty `reprepro` repo and imports only the packages this run's build jobs
produced) — **there is no step that first seeds `local-repo` from the
existing production content in R2.** As soon as `build-order-xfce.yml` grows
past a single tier, any run that doesn't rebuild every previously-published
tier's package will `rclone sync` a partial tree over production and delete
everything else that was already published.

This is the same failure class as `INCIDENT-repo-wipe-gnome.md` and the
2026-07-19 XFCE .deb wipe in `tunaos-packages` (fixed there in `f877c83`,
PR #99): a publish-side `rclone sync` with no downstream-safe guard. See
`tuna-os/tunaos-packages#627` for the same gap found and patched in that
repo's `build.yml` on 2026-09-02.

## Immediate triage

1. Confirm the blast radius by listing the R2 prefix directly:
   `rclone lsf r2:bluefin/deb/26.04-resolute/` (read-only, always safe).
2. Compare against `build-order-xfce.yml`'s `tiers:` list — anything listed
   there but absent from the bucket was deleted, not merely never built.
3. There is no soft-delete configured for this bucket. Recovery is a full
   rebuild of the missing tier(s) via `workflow_dispatch` with `force: true`,
   not a restore.

## Preventing this

Before `local-repo/` is trusted as the full publish source, the `publish`
job needs both gates already standard on sibling apt/rpm publishers:

1. **Seed from production first.** Sync the current `r2:${R2_BUCKET}/deb/26.04-resolute/`
   prefix down into `local-repo/` before importing this run's newly-built
   `.deb`s, and fail the job (not `|| true`) if that sync-down errors.
2. **Refuse to publish empty/shrunk.** Immediately before the final
   `rclone sync` up, count `.deb` files in `local-repo/` and compare against
   the tier count in `build-order-xfce.yml`; `exit 1` with an `::error::`
   annotation rather than syncing a smaller tree over production.

As `build-order-xfce.yml` gains tiers, treat adding these two gates to
`build-xfce-distributed.yml` as a prerequisite, not a follow-up — the
window where a partial `local-repo` can wipe real content opens the moment
a second package is published.

## Related

* `tuna-os/tunaos-packages#627` — the same gap, found and patched in that
  repo's RPM `build.yml` the same day this runbook was written.
* `runbooks/r2-repo-publish-guard.md` in `tuna-os/tunaos-packages` — the
  RPM-side version of this runbook, with the "Refuse to publish an empty
  result" step template.
