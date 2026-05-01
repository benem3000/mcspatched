Name:           mac80211-kmod
Version:        2.0
Release:        %{?build_tag}%{!?build_tag:1}%{?dist}
Summary:        Patched mac80211 kernel module for 4x4 AP compatibility
License:        GPLv2
BuildRequires:  make, gcc, kernel-devel, curl, xz

%description
A dynamically patched mac80211 kernel module to skip basic MCS set validation.

%prep
KVER_BASE=$(echo %{kversion} | cut -d'-' -f1)
MAJOR=$(echo ${KVER_BASE} | cut -d'.' -f1)

URL="https://cdn.kernel.org/pub/linux/kernel/v${MAJOR}.x/linux-${KVER_BASE}.tar.xz"
SUMS_URL="https://cdn.kernel.org/pub/linux/kernel/v${MAJOR}.x/sha256sums.asc"

curl -sLO "$URL"
curl -sLO "$SUMS_URL"

export GNUPGHOME=$(mktemp -d)

gpg2 --locate-keys torvalds@kernel.org gregkh@kernel.org sashal@kernel.org bwh@kernel.org autosigner@kernel.org

if ! gpg2 --verify sha256sums.asc; then
    echo "CRITICAL: Signature verification failed!"
    echo "The kernel was signed by an unknown key or the signature is invalid."
    exit 1
fi

grep "linux-${KVER_BASE}.tar.xz" sha256sums.asc | sha256sum -c -

tar -xJf "linux-${KVER_BASE}.tar.xz" --strip-components=1 "linux-${KVER_BASE}/net/mac80211" "linux-${KVER_BASE}/include"

TARGET="net/mac80211/mlme.c"

sed -i '/#include <net\/mac80211.h>/a \
\
static bool skip_mcs_check = false;\
module_param(skip_mcs_check, bool, 0644);\
MODULE_PARM_DESC(skip_mcs_check, "Bypass MCS verification for 4x4 router compatibility");' "$TARGET"

for func in ieee80211_verify_sta_ht_mcs_support ieee80211_verify_sta_vht_mcs_support ieee80211_verify_peer_he_mcs_support ieee80211_verify_sta_he_mcs_support ieee80211_verify_sta_eht_mcs_support; do
    sed -i "/^$func(/,/^{/ s/^{/{\n\tif (skip_mcs_check) return true;/" "$TARGET"
done

%build
make -C /usr/src/kernels/%{kversion} M=$PWD/net/mac80211 modules

%install
mkdir -p %{buildroot}/lib/modules/%{kversion}/extra/net/mac80211

SIGN_FILE_PATH=$(find /usr/src/kernels/%{kversion} -name sign-file | head -n 1)
if [[ -f "%{mok_priv}" ]] && [[ -f "%{mok_x509}" ]]; then
    $SIGN_FILE_PATH sha512 %{mok_priv} %{mok_x509} net/mac80211/mac80211.ko
else
    echo "WARNING: MOK keys not provided, module will be unsigned."
fi

cp net/mac80211/mac80211.ko %{buildroot}/lib/modules/%{kversion}/extra/net/mac80211/

mkdir -p %{buildroot}/usr/lib/depmod.d
echo "override mac80211 * extra" > %{buildroot}/usr/lib/depmod.d/mac80211-patch.conf
%files
/lib/modules/%{kversion}/extra/mac80211.ko
/usr/lib/depmod.d/mac80211-patch.conf

%changelog
* Thu Apr 30 2026 Bazzite Patch <benem3000@users.noreply.github.com> - 1.0-1
- Initial automated build
