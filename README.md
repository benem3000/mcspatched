# MCSPatched &nbsp; [![bluebuild build badge](https://github.com/benem3000/mcspatched/actions/workflows/build.yml/badge.svg)](https://github.com/benem3000/mcspatched/actions/workflows/build.yml)

# !DO NOT USE YET UNTIL THIS COMMENT IS REMOVED!

This repository provides a pre-compiled, toggleable kernel module (mac80211-kmod) for Bazzite and Fedora Atomic desktops. It bypasses basic MCS set validation to resolve Wi-Fi connectivity issues with certain 4x4 access points, such as specific Comcast or Xfinity routers.

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

## Common Issues and Troubleshooting

If you are still experiencing connection drops or authentication timeouts after enabling the patch, try the following fixes for Intel (`iwlwifi`) and standard Fedora/Bazzite networking stacks.

### 1. Verify the Patch is Active
Before applying further fixes, ensure the OS is actually utilizing the bypass. Run this command:

`cat /sys/module/mac80211/parameters/skip_mcs_check`
*(If it returns `Y`, the patch is active. If it returns `N`, verify your kernel arguments. If it returns "No such file or directory", you are not booted into the custom image).*

### 2. Disable Protected Management Frames (PMF)
Some Comcast and Sercomm routers enforce PMF in a way that causes the Linux networking stack to drop the handshake. You can disable this locally via NetworkManager for your specific network:

`nmcli connection modify "YOUR_WIFI_NAME" wifi-sec.pmf 1`

`nmcli connection up "YOUR_WIFI_NAME"`

### 3. Disable Wi-Fi 6 (802.11ax)
If the Intel AX210/AX1675 card is still failing to negotiate with the router, forcing the card to fall back to Wi-Fi 5 (802.11ac) often stabilizes the connection. Apply this kernel argument and reboot:

`sudo rpm-ostree kargs --append="iwlwifi.disable_11ax=1"`

### 4. Disable 802.11n Aggregation
If you experience extreme lag spikes or packet loss while connected, the hardware TX aggregation might be failing. You can disable it by passing the `11n_disable=8` parameter:

`sudo rpm-ostree kargs --append="iwlwifi.11n_disable=8"`

### Collecting Safe Logs for Bug Reports
If none of the above steps work and you need to submit an issue, please collect your kernel networking logs. **For your privacy, run the following command to automatically scrub your MAC addresses from the output** before uploading the text file:

```bash
sudo dmesg | grep -iE "mac80211|iwlwifi|wlp" | sed -E 's/([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}/XX:XX:XX:XX:XX:XX/g' > safe_wifi_logs.txt
## Removal
```

If you need to revert to the stock Wi-Fi behavior, you should unenroll the security key before leaving the custom image.

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
