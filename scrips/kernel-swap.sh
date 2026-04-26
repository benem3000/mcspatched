#!/usr/bin/env bash
set -oue pipefail

# 1. Define the URLs from your Kernel Build Release
# Replace these with the actual links from your GitHub Release page
CORE_URL="https://github.com/benem3000/bazzite-AX210-test/releases/download/v6.13-patched/kernel-core-6.13.rpm"
MODS_URL="https://github.com/benem3000/bazzite-AX210-test/releases/download/v6.13-patched/kernel-modules-6.13.rpm"
EXTRA_URL="https://github.com/benem3000/bazzite-AX210-test/releases/download/v6.13-patched/kernel-modules-extra-6.13.rpm"

echo "Swapping to Patched AX210 Kernel..."

# 2. Use rpm-ostree to override the existing kernel
rpm-ostree override replace \
    "$CORE_URL" \
    "$MODS_URL" \
    "$EXTRA_URL"
