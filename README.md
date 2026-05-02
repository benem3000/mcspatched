# MCSPatched-Bazzite, Currently in testing, use at you own risk! &nbsp; [![Generate Kmod](https://github.com/benem3000/mcspatched/actions/workflows/build.yml/badge.svg)](https://github.com/benem3000/mcspatched/actions/workflows/build.yml)


_Version numbers should align with Bazzite stable releases. Alternate versions for deck, nvidia, etc not yet available but are planned. This is intended to be a temporary solution for Bazzite users until a fix is implemented by the developers upstream._

## This is currently for desktop AMD or Intel gpus only. Gnome, steam deck, and other special versions not yet available.

## Installation

### IMPORTANT! Please pin your current install before rebasing!

`ostree admin pin 0`

### 1. Rebase to the Unsigned Image

First, rebase to the unverified registry to pull down the initial image containing the proper signing keys and policies:

`rpm-ostree rebase ostree-unverified-registry:ghcr.io/benem3000/mcspatched-bazzite:latest`

### 2. First Reboot
Reboot your machine:

`systemctl reboot`

### 3. Instruct Bazzite to Enable the Patch
By default, the installed module behaves exactly like the stock kernel module.
When setting the `mac80211.skip_mcs_check` kernel argument, use the following values.

Choose only one for the version your card supports:

* **Wifi 4 Only:** `rpm-ostree kargs --append mac80211.skip_mcs_check=1`
* **Wifi 5 or higher:** `rpm-ostree kargs --append mac80211.skip_mcs_check=3`

_Wifi 6/6E is not affected by this particular issue, though may have other unrelated isues. Wifi 7 is not yet confirmed.
If you see the message "required MCSes not supported, disabling HE (or EHT)" when running dmesg, then please report that issue here so I can include it in the bypass._

### 4. (Secure Boot Only) Enroll Key:
If using Secure Boot you must instruct your firmware to trust the custom Machine Owner Key (MOK) used to sign the module. Because the key is pre-packaged in the custom image, simply run the following command to stage the public key:

`mokutil --import /usr/share/mcspatched/public_key.der`

*(You will be prompted to create a temporary password. Remember this password, as you will need it during the next boot phase.)*

_If you are not using secure boot then it is not recommended to enroll they key. You will likely see a warning about an unsigned or out of tree package, this is normal. Enrolling third party MOK keys inherently carries added risk if that key were ever compromised. I have secret scanning enabled to ensure that if this happens I will receive notice and will act accordingly to remedy the issue._

### 5. Rebase to the Signed Image
Now that the signing keys and policies are installed from the first step, secure your system by rebasing to the cryptographically signed image:

`rpm-ostree rebase ostree-image-signed:docker://ghcr.io/benem3000/mcspatched-bazzite:latest`

### 6. Final Reboot
Reboot your system one last time to apply the signed image and the kernel argument:

`systemctl reboot`

If you enrolled the MOK key in step 4, you will be intercepted by a blue screen (MOKManager) during startup. Select "Enroll MOK", verify the key, then confirm it and enter the temporary password you created. Once complete, select reboot to finish loading the OS.

### 7. Disable Protected Management Frames (PMF)
At the moment pmf is not compatible and will cause severe lag, ping, and speed issues. You can disable this locally via NetworkManager for your specific network by using these commands:
_Ensure you have already connected to the network at least once._

`nmcli connection modify "YOUR_WIFI_NAME" wifi-sec.pmf 1`

`nmcli connection up "YOUR_WIFI_NAME"`

The patched module will be active and you should notice an improvement in speed. Give it a speed test or check conection speed under your wifi network's details in the taskbar to confirm. (Or use a more techy method if you know one)

## Results
Patch Enabled:

<img width="750" height="400" alt="19147132124" src="https://github.com/user-attachments/assets/cd52f2e7-0efd-4587-82f4-0b44093efcdc" />

Patch Disabled:

<img width="750" height="400" alt="patchdisabled" src="https://github.com/user-attachments/assets/23bfcc83-1b57-4223-b07b-90ef0441bb0d" />

## Verification
To ensure the OS is actually utilizing the bypass. Run this command:

`cat /sys/module/mac80211/parameters/skip_mcs_check`

*(If it returns `Y`, the patch is active. If it returns `N`, verify your kernel arguments. If it returns "No such file or directory", then there is an issue with the install.).*

You can verify the signature by downloading the `cosign.pub` file from this repository and running the following command:

`cosign verify --key cosign.pub ghcr.io/benem3000/mcspatched-bazzite`

## Common Issues and Troubleshooting

### Follow recommended steps on bazzite's website: https://docs.bazzite.gg/General/issues_and_resolutions/#wi-fi-is-slow-wi-fi-lag-spikes

### Disable Wi-Fi 6 (802.11ax)
If the Intel AX210/AX1675 card is still failing to negotiate with the router, forcing the card to fall back to Wi-Fi 5 (802.11ac) often stabilizes the connection. Apply this kernel argument and reboot:

`rpm-ostree kargs --append="iwlwifi.disable_11ax=1"`

### Disable 802.11n Aggregation
If you experience extreme lag spikes or packet loss while connected, the hardware TX aggregation might be failing. You can disable it by passing the `11n_disable=8` parameter:

`rpm-ostree kargs --append="iwlwifi.11n_disable=8"`

## Uninstallation

### 1. Delete the kernel argument(s):
_Note: I recommend reverting any additional kargs you may have tried while troubleshooting. 
If you enabled other kargs, use `rpm-ostree kargs` to list your current arguments, and substitue them into the command below. Be sure that you don't remove any unrelated arguments._

Wifi 4 Only:
`rpm-ostree kargs --delete="mac80211.skip_mcs_check=1"`
Wifi 5 or later:
`rpm-ostree kargs --delete="mac80211.skip_mcs_check=3"`

For easy deletion of multiple kargs (be careful not to touch unrelated kargs):

`rpm-ostree kargs --editor"`

### 2. Unenroll the Secure Boot Key (Optional)
If you enrolled the MOK while installing, run:

`mokutil --delete /usr/share/mcspatched/public_key.der`

*(You will be prompted to create a temporary password before rebooting. In the MOKManager screen, select "Delete MOK", confirm the key details, and enter the temporary password to finalize the removal.)*

### 3. Rebase back to your desired Bazzite version:

`brh`

Select rebase and follow the prompts.

### 4. Reboot your system to apply the changes.

`systemctl reboot`

## In case of emergency (break glass) (aka your internet isn't working anymore)

### 1. Use brh Rollback
   
`brh`

_You should still have your old image pinned if you want to easily return to stock. Otherwise you can rollback to the previous build of the patch and wait for the issue to be fixed._

### 2. Reboot
   
`systemctl reboot`

### 3. (Optional) If you roll back to a previous patched build then disable automatic updates

### 4. File an issue on this repository

## Technical Detail

Certain routers, namely the XB7 or later routers from Comcast (Technicolor and Sercomm models confirmed to be affected), have a software bug that likely resulted from a copy/paste of the router capabilities into the basic MCS requirements for the older 802.11n (HT) and 802.11ac (VHT) standards. 802.11ax is not affected, 802.11be is not yet confirmed as it was disabled on my router. The Mac80211 kernel module by default adheres strictly to the ieee 802.11 standards and disables the HT and VHT capabilities when it sees these incorrect Basic MCS requirements. While thise likely differs from behavior in Windows and MacOS, it is technically the correct way to handle the situation. Some users may wish, however, to have the option to bypass this to make their wifi usable until a fix is integrated into the kernel.

This patch modifies the source file mlme.c in mac80211 by first introducing a new unsigned integer paraameter, skip_mcs_check here:

```
+
+
+static unsigned int skip_mcs_check = 0;
+module_param(skip_mcs_check, uint, 0644);
+MODULE_PARM_DESC(skip_mcs_check, "Bitmask to bypass MCS verification (0=No Bypass, 1=HT, 2=VHT, 3=ALL");
+
+#define MCS_SKIP_HT  (1 << 0)
+#define MCS_SKIP_VHT (1 << 1)
+
+
```
It then proceeds to bypass the mcs checks for the specified standards depending on the user's configuration by returning true in the following sections:


Wifi 4 (HT)
`ieee80211_verify_sta_ht_mcs_support`

Wifi 5 (VHT)
`ieee80211_verify_sta_vht_mcs_support`

Patch adds these statements directly after the declarations:

Wifi 4 (HT)
`+	if (skip_mcs_check & MCS_SKIP_HT) return true;`

Wifi 5 (VHT)
`+	if (skip_mcs_check & MCS_SKIP_VHT) return true;`

### Bitmask Table:

| Bitmask Value | Wi-Fi Standard | Technology Name | Description |
| :---: | :--- | :--- | :--- |
| **`0`** | **None** | Default | MCS checks are **enabled** (Standard Kernel Behavior) |
| **`1`** | **Wi-Fi 4** | HT | Skips MCS validation for High Throughput (802.11n) |
| **`2`** | **Wi-Fi 5** | VHT | Skips MCS validation for Very High Throughput (802.11ac) |

This instructs mac80211 to ignore the MCS verification and enable HT/VHT anyway until Comcast fixes their firmware or the kernel devs implement a bypass.

## Credits
This is a modified version based on work by WoodyWoodster: https://github.com/WoodyWoodster/mac80211-mcs-patch
Thank you to the BlueBuild team as well. https://github.com/blue-build

 _AI Disclodure: I used Google Gemini and Github Copilot throughout much of this process. Builds and changes were reviewed and tested by myself, but my coding skills are nowhere near professional_
_Use at your own risk, and report any bugs._

## License
This project provides a patched version of the `mac80211` kernel module, which is part of the Linux kernel. This work is licensed under the **GNU General Public License v2.0**, consistent with the upstream Linux kernel source.
