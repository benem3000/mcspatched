%global __os_install_post %{nil}

Name:           mac80211-kmod
Version:        2.0
Release:        %{?build_tag}%{!?build_tag:1}%{?dist}
Summary:        Patched mac80211 kernel module for 4x4 AP compatibility
License:        GPLv2

BuildRequires:  make, gcc, kernel-devel, curl, xz, binutils, zstd

%description
A dynamically patched mac80211 kernel module to skip basic MCS set validation.

%prep
KVER_BASE=$(echo %{kversion} | cut -d'-' -f1)
MAJOR=$(echo ${KVER_BASE} | cut -d'.' -f1)

URL="https://cdn.kernel.org/pub/linux/kernel/v${MAJOR}.x/linux-${KVER_BASE}.tar.xz"
curl -sLO "$URL"

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
mkdir -p %{buildroot}/lib/modules/%{kversion}/updates/net/mac80211/

strip --strip-debug net/mac80211/mac80211.ko

SIGN_FILE_PATH=$(find /usr/src/kernels/%{kversion} -name sign-file | head -n 1)

if [[ -z "$SIGN_FILE_PATH" ]]; then
    echo "CRITICAL: Kernel sign-file utility not found!"
    exit 1
fi

install -m 755 net/mac80211/mac80211.ko %{buildroot}/lib/modules/%{kversion}/updates/net/mac80211/mac80211.ko


%files
/lib/modules/%{kversion}/updates/net/mac80211/mac80211.ko

%changelog
* Fri May 01 2026 Bazzite Patch <benem3000@users.noreply.github.com> - 2.0-3
- Migrated module from extra/ to updates/ to exploit inherent Fedora search priority
- Removed depmod.d override to bypass rpm-ostree compose bug
- Manually stripped debug symbols to fix binary bloat
- Set module permissions to 755 to match stock modules
