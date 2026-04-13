# Gitian Multi-Suite Build — GLIBC Compatibility Fix

## Issue

When building zcash v6.12.0 with multiple Debian suites (bookworm + bullseye), the bullseye build fails with:

```
/home/debian/build/zcash/depends/.../cxxbridge: version `GLIBC_2.33' not found
```

## Root Cause

1. **gitian-builder caches `depends/` between suite builds**
2. Original descriptor order: `bookworm` → `bullseye`
3. Bookworm (GLIBC 2.36) builds first → compiles `cxxbridge` (Rust tool)
4. `cxxbridge` binary links against GLIBC 2.33+
5. Bullseye (GLIBC 2.31) reuses cached `cxxbridge` → incompatible

## Solution

**Swap suite order**: build `bullseye` first, then `bookworm`

```yaml
suites:
- "bullseye"  # GLIBC 2.31 - builds cxxbridge
- "bookworm"  # GLIBC 2.36 - reuses (backward compatible)
```

## Implementation

**Hotfix in `gitian-direct.sh`** (lines 100-113):
- Detects `bookworm` before `bullseye` in descriptor
- Automatically swaps order via `sed` after git clone
- No manual intervention needed

## Commits

- `zcash/zcash-gitian@7f14515` - Main fix
- `zodl-inc/infra@5f5ebd9` - Synced copy

## Prevention

For future zcash releases:
1. Always list **oldest suite first** in gitian descriptor
2. Or: submit PR to zcash/zcash to fix descriptor upstream
3. Monitor depends/ cache behavior with multiple suites

## GLIBC Versions

| Debian Release | GLIBC Version |
|----------------|---------------|
| Bullseye (11)  | 2.31          |
| Bookworm (12)  | 2.36          |

---
Date: 2026-04-13
Author: y4ssi
Build: v6.12.0 (run 24371151620)
