#!/usr/bin/env bash
set -euo pipefail

# 1. Grab the image's kernel version FIRST
KVER=$(rpm -q kernel-core --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')
KVER_BASE="${KVER%%-*}"
MAJOR="${KVER_BASE%%.*}"

echo "Detected Target Kernel: $KVER"

# 2. Install build tools (Added openssl for signing)
echo "Installing temporary build tools and headers..."
dnf install -y --nogpgcheck --setopt=install_weak_deps=False \
    gcc make patch openssl kernel-devel-"$KVER"

# 3. Setup workspace
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT
cd "$WORK_DIR"

# 4. Download source
echo "Downloading kernel source for v$KVER_BASE..."
URL="https://cdn.kernel.org/pub/linux/kernel/v${MAJOR}.x/linux-$KVER_BASE.tar.xz"
curl -sL "$URL" | tar -xJ --strip-components=1 "linux-$KVER_BASE/net/mac80211" "linux-$KVER_BASE/include"

# 5. Patch net/mac80211/main.c
echo "Patching main.c..."
sed -i '/#include <linux\/module.h>/a \
\
bool skip_mcs_check = false;\
module_param(skip_mcs_check, bool, 0644);\
MODULE_PARM_DESC(skip_mcs_check, "Skip basic MCS set validation");' net/mac80211/main.c

# 6. Patch net/mac80211/mlme.c
echo "Patching mlme.c..."
sed -i '15i extern bool skip_mcs_check;' net/mac80211/mlme.c
sed -i '/if (!ht_op)/a \	if (skip_mcs_check) return true;' net/mac80211/mlme.c

# 7. Compile against image headers
echo "Compiling mac80211 module..."
make -C "/usr/lib/modules/$KVER/build" M="$WORK_DIR/net/mac80211" modules

# --- INSTRUCTION 21: MODULE VERIFICATION FIX ---
echo "Signing module to satisfy kernel verification logic..."

# A. Determine hash algorithm from boot config (per StackOverflow NOTE)
HASH_ALGO=$(grep CONFIG_MODULE_SIG_HASH /boot/config-"$KVER" | cut -d'"' -f2 || echo "sha512")

# B. Generate the keys (Instruction 21: priv and x509)
openssl req -new -x509 -newkey rsa:4096 -keyout signing_key.priv -outform PEM -out signing_key.x509 -nodes -days 36500 -subj "/CN=Bazzite-AX210-Patch/"

# C. Sign the module (Instruction 21 syntax)
/usr/src/kernels/"$KVER"/scripts/sign-file "$HASH_ALGO" ./signing_key.priv ./signing_key.x509 net/mac80211/mac80211.ko

# D. Bake the cert into the image so the kernel can verify the signature
mkdir -p /etc/pki/akmods/certs/
cp signing_key.x509 /etc/pki/akmods/certs/ax210-patch.der
# -----------------------------------------------

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
depmod -a "$KVER"

echo "Build complete!"
