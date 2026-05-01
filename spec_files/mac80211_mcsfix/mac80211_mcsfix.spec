%global __os_install_post %{nil}

Name:           mac80211-kmod
Version:        2.0
Release:        %{?build_tag}%{!?build_tag:1}%{?dist}
Summary:        Patched mac80211 kernel module for 4x4 AP compatibility
License:        GPLv2
Source0:        mac80211-mcsfix.patch
Source1:        public_key.der

BuildRequires:  make, gcc, kernel-devel, curl, xz, binutils, zstd, patch

%description
A dynamically patched mac80211 kernel module to skip basic MCS set validation.

%prep
KVER_BASE=$(echo %{kversion} | cut -d'-' -f1)
MAJOR=$(echo ${KVER_BASE} | cut -d'.' -f1)

URL="https://cdn.kernel.org/pub/linux/kernel/v${MAJOR}.x/linux-${KVER_BASE}.tar.xz"
curl -sLO "$URL"
curl -sLO "https://cdn.kernel.org/pub/linux/kernel/v${MAJOR}.x/sha256sums.asc"

export GNUPGHOME=$(mktemp -d)
gpg2 --locate-keys torvalds@kernel.org gregkh@kernel.org sashal@kernel.org bwh@kernel.org autosigner@kernel.org

if ! gpg2 --verify sha256sums.asc; then
    echo "CRITICAL: Kernel signature verification failed!"
    exit 1
fi

grep "linux-${KVER_BASE}.tar.xz" sha256sums.asc | sha256sum -c -

tar -xJf "linux-${KVER_BASE}.tar.xz" --strip-components=1 "linux-${KVER_BASE}/net/mac80211" "linux-${KVER_BASE}/include"

patch -d net/mac80211 -p0 < %{SOURCE0}
%build
make -C /usr/src/kernels/%{kversion} M=$PWD/net/mac80211 modules

%install
mkdir -p %{buildroot}/lib/modules/%{kversion}/updates/net/mac80211/
mkdir -p %{buildroot}/usr/share/mcspatched/

strip --strip-debug net/mac80211/mac80211.ko

SIGN_FILE_PATH=$(find /usr/src/kernels/%{kversion} -name sign-file | head -n 1)

if [[ -z "$SIGN_FILE_PATH" ]]; then
    echo "CRITICAL: Kernel sign-file utility not found!"
    exit 1
fi

install -m 755 net/mac80211/mac80211.ko %{buildroot}/lib/modules/%{kversion}/updates/net/mac80211/mac80211.ko
install -m 644 %{SOURCE1} %{buildroot}/usr/share/mcspatched/public_key.der

%files
/lib/modules/%{kversion}/updates/net/mac80211/mac80211.ko
/usr/share/mcspatched/public_key.der

%changelog
* Fri May 01 2026 Bazzite Patch <benem3000@users.noreply.github.com> - 2.0-5
- Bundled public_key.der directly into the RPM for seamless mokutil enrollment
