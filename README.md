# MCSPatched &nbsp; [![bluebuild build badge](https://github.com/benem3000/mcspatched/actions/workflows/build.yml/badge.svg)](https://github.com/benem3000/mcspatched/actions/workflows/build.yml)

# !DO NOT USE YET UNTIL THIS COMMENT IS REMOVED!

This repository provides a pre-compiled, toggleable kernel module (mac80211-kmod) for Bazzite and Fedora Atomic desktops. It bypasses basic MCS set validation to resolve Wi-Fi connectivity issues with certain 4x4 access points, such as specific Comcast or Xfinity routers.

The included GitHub Actions workflow automatically compiles the module against the latest kernel used by Bazzite, signs it for Secure Boot, and packages it as an RPM. To ensure system stability, the patch is disabled by default and must be explicitly enabled by the user after installation.

## Installation
Because this is a layered package for an atomic operating system, you will use rpm-ostree to install the module directly over your base image.

### 1. Download the Files
Navigate to the Releases page of this repository. Download the two files attached to the latest release:

`mac80211-kmod-*.rpm`

`signing_key.x509`

### 2. Install the Kernel Module
Open your terminal in the directory where you downloaded the files and run the following command to layer the package:

`rpm-ostree install ./mac80211-kmod-*.rpm`
### 3. Enroll the Secure Boot Key (optional)
The kernel module is signed using a custom Machine Owner Key (MOK) generated during the build process. If you have Secure Boot enabled in your BIOS, you must instruct your system to trust this key.

Run the following command to import the public key:

`sudo mokutil --import signing_key.x509`
You will be prompted to create a temporary password. Remember this password, as you will need it during the next boot phase.

### 4. Enable the Patch
By default, the installed module behaves exactly like the stock Fedora kernel module. To activate the MCS validation bypass, you need to set a module parameter.

Create a modprobe drop-in file by running:

`echo "options mac80211 skip_mcs_check=1" | sudo tee /etc/modprobe.d/mac80211-mcs.conf`
### 5. Reboot and Apply
Reboot your machine.

If you enrolled the key in step 3, you will be intercepted by a blue screen (MOKManager). Select Enroll MOK, view the key to confirm it, and enter the temporary password you created in Step 3. Once complete, select reboot.

When your system boots back up, the patched module will be active and you should be able to connect to the problematic access point.

## Removal
If you need to revert to the stock Wi-Fi behavior, you can uninstall the module and remove the configuration file:

### 1. Delete the modprobe configuration:
_If you have other settings in this file, you'll need to modify it manually._

`sudo rm /etc/modprobe.d/mac80211-mcs.conf`

### 2. Remove the layered RPM:

`rpm-ostree uninstall mac80211-kmod`

### 3. Unenroll the Secure Boot Key (Optional)

If you wish to completely remove the custom Secure Boot key from your system's firmware, you will need the original `signing_key.x509` file you downloaded from the release. 

Navigate to the directory containing the key and run:

`sudo mokutil --delete signing_key.x509`

### 4. Reboot your system to apply the changes.

You will be prompted to create a temporary password just as before. Reboot your machine to enter the MOKManager screen. Select Delete MOK, confirm the key details, and enter the temporary password to finalize the removal.
