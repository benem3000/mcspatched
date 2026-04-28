#!/usr/bin/env bash
set -euo pipefail

# 1. Detect the kernel version of the image we are building
KVER=$(rpm -q kernel-core --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')
KVER_BASE="${KVER%%-*}"
MAJOR="${KVER_BASE%%.*}"

echo "Building patched mac80211 for kernel: $KVER"

# 2. Setup workspace
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT
cd "$WORK_DIR"

# 3. Download and extract only the mac80211 source
URL="https://cdn.kernel.org/pub/linux/kernel/v${MAJOR}.x/linux-$KVER_BASE.tar.xz"
curl -sL "$URL" | tar -xJ --strip-components=1 "linux-$KVER_BASE/net/mac80211" "linux-$KVER_BASE/include"

# 4. Apply your toggleable patch
# This assumes the patch is placed in /tmp/patches/ via recipe.yml
patch -p1 < /tmp/patches/mcs-toggle.patch

# 5. Build the module against the image headers
make -C "/usr/lib/modules/$KVER/build" M="$WORK_DIR/net/mac80211" modules

# 6. Install to the 'extra' directory (where it survives the build)
INSTALL_DIR="/usr/lib/modules/$KVER/extra"
mkdir -p "$INSTALL_DIR"
cp net/mac80211/mac80211.ko "$INSTALL_DIR/"

# 7. Set depmod priority so 'extra' is preferred over 'kernel'
mkdir -p /etc/depmod.d
echo "override mac80211 * extra" > /etc/depmod.d/mac80211.conf

# 8. Update module dependencies
depmod -a "$KVER"
