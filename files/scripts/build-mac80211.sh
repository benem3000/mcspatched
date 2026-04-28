#!/usr/bin/env bash
set -euo pipefail

# 1. Grab the image's kernel version FIRST
# We need this to tell DNF exactly which headers to download
KVER=$(rpm -q kernel-core --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')
KVER_BASE="${KVER%%-*}"
MAJOR="${KVER_BASE%%.*}"

echo "Detected Target Kernel: $KVER"

# 2. Install build tools for this session only
# We use the explicit $KVER to avoid the 'azure' kernel header error
echo "Installing temporary build tools and headers..."
dnf install -y --nogpgcheck --setopt=install_weak_deps=False \
    gcc make patch kernel-devel-"$KVER"

# 3. Setup workspace
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT
cd "$WORK_DIR"

# 4. Download source
echo "Downloading kernel source for v$KVER_BASE..."
URL="https://cdn.kernel.org/pub/linux/kernel/v${MAJOR}.x/linux-$KVER_BASE.tar.xz"
curl -sL "$URL" | tar -xJ --strip-components=1 "linux-$KVER_BASE/net/mac80211" "linux-$KVER_BASE/include"

# 5. Patch net/mac80211/main.c
# Move the definition to the top to satisfy MODPOST linker requirements
echo "Patching main.c..."
sed -i '/#include <linux\/module.h>/a \
\
bool skip_mcs_check = false;\
module_param(skip_mcs_check, bool, 0644);\
MODULE_PARM_DESC(skip_mcs_check, "Skip basic MCS set validation");' net/mac80211/main.c

# 6. Patch net/mac80211/mlme.c
echo "Patching mlme.c..."
# Add the extern declaration so mlme.o knows the variable exists
sed -i '15i extern bool skip_mcs_check;' net/mac80211/mlme.c

# Insert logic check: If ht_op is found, append the toggle on the next line
sed -i '/if (!ht_op)/a \	if (skip_mcs_check) return true;' net/mac80211/mlme.c

# 7. Compile against image headers
echo "Compiling mac80211 module..."
make -C "/usr/lib/modules/$KVER/build" M="$WORK_DIR/net/mac80211" modules

# 8. Install to 'extra'
echo "Installing module to extra/..."
INSTALL_DIR="/usr/lib/modules/$KVER/extra"
mkdir -p "$INSTALL_DIR"
cp net/mac80211/mac80211.ko "$INSTALL_DIR/"

# 9. Create the depmod override
echo "Setting depmod overrides..."
mkdir -p /usr/lib/depmod.d
echo "override mac80211 * extra" > /usr/lib/depmod.d/mac80211-patch.conf

# 10. Refresh module map
# Note: We use the full KVER to ensure it maps to the Bazzite kernel
depmod -a "$KVER"

echo "Build complete!"
