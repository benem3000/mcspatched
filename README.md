# MCSPatched &nbsp; [![bluebuild build badge](https://github.com/benem3000/mcspatched/actions/workflows/build.yml/badge.svg)](https://github.com/benem3000/mcspatched/actions/workflows/build.yml)

This repository provides a pre-compiled, toggleable kernel module for Bazzite and Fedora Atomic desktops. It bypasses basic MCS set validation to resolve slow connections (under 20mbps) with certain 4x4 access points, such as newer Comcast routers (XB7+).

The included GitHub Actions workflow automatically compiles the module against the latest kernel used by Bazzite, signs it for Secure Boot, and packages it natively into a custom Bazzite image. To ensure system stability, the patch is disabled by default and must be explicitly enabled by the user after installation.

## Installation

To ensure your system properly imports the signing keys and policies, this is a two-step rebase process.

### 1. Rebase to the Unsigned Image & Stage MOK
_Commands given are used in your terminal (Ctrl+Alt+T)_

First, rebase to the unverified registry to pull down the initial image containing the proper signing keys and policies:

`rpm-ostree rebase ostree-unverified-registry:ghcr.io/benem3000/mcspatched-bazzite:latest`

**If you have Secure Boot enabled:** You must instruct your firmware to trust the custom Machine Owner Key (MOK) used to sign the module. Because the key is pre-packaged in the custom image, simply run the following command to stage the public key:

`sudo mokutil --import /usr/share/mcspatched/public_key.der`

*(You will be prompted to create a temporary password. Remember this password, as you will need it during the next boot phase.)*

### 2. First Reboot
Reboot your machine:

`systemctl reboot`

*If you enrolled the Secure Boot key:* You will be intercepted by a blue screen (MOKManager) during startup. Select "Enroll MOK", view the key to confirm it, and enter the temporary password you created. Once complete, select reboot to finish loading the OS.

### 3. Rebase to the Signed Image
Now that the signing keys and policies are installed from the first step, secure your system by rebasing to the cryptographically signed image:

`rpm-ostree rebase ostree-image-signed:docker://ghcr.io/benem3000/mcspatched-bazzite:latest`

### 4. Enable the Patch
By default, the installed module behaves exactly like the stock Fedora kernel module. To activate the MCS validation bypass, enable the toggle by appending the kernel argument:

`sudo rpm-ostree kargs --append="mac80211.skip_mcs_check=1"`

### 5. Final Reboot
Reboot your system one last time to apply the signed image and the kernel argument:

`systemctl reboot`

When your system boots back up, the patched module will be active and you should be able to connect to the problematic access point.

## Verification
These images are cryptographically signed. You can verify the signature by downloading the `cosign.pub` file from this repository and running the following command:

`cosign verify --key cosign.pub ghcr.io/benem3000/mcspatched-bazzite`

## Removal
If you need to revert to the stock Wi-Fi behavior, you should unenroll the security key before leaving the custom image.

### 1. Delete the kernel argument:
`sudo rpm-ostree kargs --delete="mac80211.skip_mcs_check=1"`

### 2. Unenroll the Secure Boot Key (Optional)
If you wish to completely remove the custom Secure Boot key from your system's firmware, run:

`sudo mokutil --delete /usr/share/mcspatched/public_key.der`

*(You will be prompted to create a temporary password before rebooting. In the MOKManager screen, select "Delete MOK", confirm the key details, and enter the temporary password to finalize the removal.)*

### 3. Rebase back to standard Bazzite:
`rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ublue-os/bazzite:stable`

### 4. Reboot your system to apply the changes.
`systemctl reboot`
