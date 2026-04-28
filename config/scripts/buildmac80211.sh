#!/usr/bin/env bash
set -euo pipefail

# 1. Grab the image's kernel version
KVER=$(rpm -q kernel-core --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')
KVER_BASE="${KVER%%-*}"
MAJOR="${KVER_BASE%%.*}"

echo "Building patched mac80211 for kernel: $KVER"

# 2. Setup workspace
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT
cd "$WORK_DIR"

# 3. Download source (only the bits we need)
URL="https://cdn.kernel.org/pub/linux/kernel/v${MAJOR}.x/linux-$KVER_BASE.tar.xz"
curl -sL "$URL" | tar -xJ --strip-components=1 "linux-$KVER_BASE/net/mac80211" "linux-$KVER_BASE/include"

# 4. Apply the patch from your config/patches directory
# Note: BlueBuild scripts run with /tmp/config available
patch -p1 < /tmp/config/patches/mcs-toggle.patch

# 5. Compile against image headers
make -C "/usr/lib/modules/$KVER/build" M="$WORK_DIR/net/mac80211" modules

# 6. Install to 'extra' so it persists in the image
INSTALL_DIR="/usr/lib/modules/$KVER/extra"
mkdir -p "$INSTALL_DIR"
cp net/mac80211/mac80211.ko "$INSTALL_DIR/"

# 7. Create the depmod override 
# (This ensures the 'extra' module takes precedence)
mkdir -p /etc/depmod.d
echo "override mac80211 * extra" > /etc/depmod.d/mac80211.conf

# 8. Refresh module map
depmod -a "$KVER"
