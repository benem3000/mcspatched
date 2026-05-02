# MCSPatched &nbsp; [![Generate Kmod](https://github.com/benem3000/mcspatched/actions/workflows/build.yml/badge.svg)](https://github.com/benem3000/mcspatched/actions/workflows/build.yml)

# !DO NOT USE YET UNTIL THIS COMMENT IS REMOVED!
Huge thanks to WoodyWoodster for providing the orginal patch here: https://github.com/WoodyWoodster/mac80211-mcs-patch
This uses a modified version to expand it to newer protocols. (VHT,HE,EHT)

This repository provides a pre-compiled, toggleable kernel module for Bazzite and Fedora Atomic desktops. It bypasses basic MCS set validation to resolve Wi-Fi connectivity issues with certain 4x4 access points, such as newer Comcast gateways (XB7+).

The patch is disabled by default and must be explicitly enabled after installation.

## Installation

To ensure your system properly imports the signing keys and policies, there is a two-step rebase process.

### 1. Rebase to the Unsigned Image
_Commands given are used in your terminal (Ctrl+Alt+T)_

First, rebase to the unverified registry to pull down the initial image containing the proper signing keys and policies:

`rpm-ostree rebase ostree-unverified-registry:ghcr.io/benem3000/mcspatched-bazzite:latest`

### 2. First Reboot
Reboot your machine:

`systemctl reboot`

### 3. Instruct Bazzite to Enable the Patch
By default, the installed module behaves exactly like the stock Fedora kernel module. To activate the MCS validation bypass, enable the toggle by appending the kernel argument:

`sudo rpm-ostree kargs --append="mac80211.skip_mcs_check=1"`

### 4. Enroll Key:
You must instruct your firmware to trust the custom Machine Owner Key (MOK) used to sign the module. Because the key is pre-packaged in the custom image, simply run the following command to stage the public key:

`sudo mokutil --import /usr/share/mcspatched/public_key.der`

*(You will be prompted to create a temporary password. Remember this password, as you will need it during the next boot phase.)*

### 5. Rebase to the Signed Image
Now that the signing keys and policies are installed from the first step, secure your system by rebasing to the cryptographically signed image:

`rpm-ostree rebase ostree-image-signed:docker://ghcr.io/benem3000/mcspatched-bazzite:latest`

### 6. Final Reboot
Reboot your system one last time to apply the signed image and the kernel argument:
You will be intercepted by a blue screen (MOKManager) during startup. Select "Enroll MOK", view the key to confirm it, and enter the temporary password you created. Once complete, select reboot to finish loading the OS.

`systemctl reboot`

### 7. Disable Protected Management Frames (PMF)
At the moment pmf is not compatible and will cause severe lag, ping, and speed issues. You can disable this locally via NetworkManager for your specific network by using these commands:
_Ensure you have already connected to the network at least once._

`nmcli connection modify "YOUR_WIFI_NAME" wifi-sec.pmf 1`

`nmcli connection up "YOUR_WIFI_NAME"`

The patched module will be active and you should notice an improvement in speed. Give it a speed test or check conection speed under your wifi network's details in the taskbar to confirm.

## Verification
These images are cryptographically signed. You can verify the signature by downloading the `cosign.pub` file from this repository and running the following command:

`cosign verify --key cosign.pub ghcr.io/benem3000/mcspatched-bazzite`

## Common Issues and Troubleshooting

If you are still experiencing connection drops or authentication timeouts after enabling the patch, try the following fixes for Intel (`iwlwifi`) and standard Fedora/Bazzite networking stacks.

### 1. Verify the Patch is Active
Before applying further fixes, ensure the OS is actually utilizing the bypass. Run this command:

`cat /sys/module/mac80211/parameters/skip_mcs_check`
*(If it returns `Y`, the patch is active. If it returns `N`, verify your kernel arguments. If it returns "No such file or directory", then there is an issue with the install.).*

### 2. Disable Wi-Fi 6 (802.11ax)
If the Intel AX210/AX1675 card is still failing to negotiate with the router, forcing the card to fall back to Wi-Fi 5 (802.11ac) often stabilizes the connection. Apply this kernel argument and reboot:

`sudo rpm-ostree kargs --append="iwlwifi.disable_11ax=1"`

### 3. Disable 802.11n Aggregation
If you experience extreme lag spikes or packet loss while connected, the hardware TX aggregation might be failing. You can disable it by passing the `11n_disable=8` parameter:

`sudo rpm-ostree kargs --append="iwlwifi.11n_disable=8"`

## Uninstallation

### 1. Delete the kernel argument:
_Note: I recommend reverting any additional kargs you may have tried while troubleshooting. 
Use `rpm-ostree kargs` to list your current arguments, and substitue them into the command below. Be sure that you don't remove any unrelated arguments, most will start with iwlwifi._

`sudo rpm-ostree kargs --delete="mac80211.skip_mcs_check=1"`

### 2. Unenroll the Secure Boot Key (Optional)
If you wish to completely remove the custom Secure Boot key from your system's firmware, run:

`sudo mokutil --delete /usr/share/mcspatched/public_key.der`

*(You will be prompted to create a temporary password before rebooting. In the MOKManager screen, select "Delete MOK", confirm the key details, and enter the temporary password to finalize the removal.)*

### 3. Rebase back to standard Bazzite:

`rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ublue-os/bazzite:stable`

### 4. Reboot your system to apply the changes.
`systemctl reboot`

## License
This project provides a patched version of the `mac80211` kernel module, which is part of the Linux kernel. This work is licensed under the **GNU General Public License v2.0**, consistent with the upstream Linux kernel source.
