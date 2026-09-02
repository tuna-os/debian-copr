# debian-copr ROADMAP

This document tracks the strategic goals, release contracts, and milestone targets for the `debian-copr` APT package pipeline.

## Strategic Overview

`debian-copr` builds and hosts APT repository packages required by Debian-based image variants (such as `grouper`).

## Roadmap Milestones

### Q3 2026: Pipeline Stabilization & Security Pinning
- [ ] Pin build dependencies and rclone credentials to secure environment contexts.
- [ ] Implement automated build-chain validation tests in CI.
- [ ] Establish formal package manifest parity verification.

### Q4 2026: Multi-Variant Package Distribution & Release Contract
- [ ] Automate release signing and attestation verification.
- [ ] Support expanded packaging matrix for downstream Debian-family desktop variants.
- [ ] Implement release SLA monitoring for published APT repositories.
