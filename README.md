# MCSPatched-Bazzite &nbsp; [![Generate Kmod](https://github.com/benem3000/mcspatched/actions/workflows/build.yml/badge.svg)](https://github.com/benem3000/mcspatched/actions/workflows/build.yml)

_A kernel-level fix is currently in the works, but will take time: https://git.kernel.org/pub/scm/linux/kernel/git/wireless/wireless.git/commit/?id=711a9c018ad252b2807f85d44e1267b595644f9b_
_My patch is functionally identical as both are derived from related code in the kernel._

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

### 3. (Secure Boot Only) Enroll Key:
If using Secure Boot you must instruct your firmware to trust the custom Machine Owner Key (MOK) used to sign the module. Because the key is pre-packaged in the custom image, simply run the following command to stage the public key:

`mokutil --import /usr/share/mcspatched/public_key.der`

*(You will be prompted to create a temporary password. Remember this password, as you will need it during the next boot phase.)*

_If you are not using secure boot then it is not recommended to enroll they key. You will likely see a warning about an unsigned or out of tree package, this is normal. Enrolling third party MOK keys inherently carries added risk if that key were ever compromised. I have secret scanning enabled to ensure that if this happens I will receive notice and will act accordingly to remedy the issue._

### 4. Rebase to the Signed Image
Now that the signing keys and policies are installed from the first step, secure your system by rebasing to the cryptographically signed image:

`rpm-ostree rebase ostree-image-signed:docker://ghcr.io/benem3000/mcspatched-bazzite:latest`

### 5. Final Reboot
Reboot your system one last time to apply the signed image and the kernel argument:

`systemctl reboot`

If you enrolled the MOK key in step 4, you will be intercepted by a blue screen (MOKManager) during startup. Select "Enroll MOK", verify the key, then confirm it and enter the temporary password you created. Once complete, select reboot to finish loading the OS.

### 6. Disable Protected Management Frames (PMF)
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
Be sure that you don't remove any unrelated arguments._

For easy deletion of multiple kargs (be careful not to touch unrelated kargs):

`rpm-ostree kargs --editor`

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
_I'll do my best to explain this from the information I've gathered, but I'm not a specialist in this field. Just a guy trying to get his wifi working._

Certain routers, namely the XB7 or later routers (XB6 may also be affected) from Comcast (Technicolor and Sercomm models confirmed to be affected), have a software bug that likely resulted from a copy/paste of the router capabilities into the basic MCS requirements for the older 802.11n (HT) and 802.11ac (VHT) standards. 802.11ac and ax are not affected, 802.11be is not yet confirmed as it was disabled on my router, but there shouldn't be an issue. The Mac80211 kernel module by default adheres strictly to the ieee 802.11 standards and disables the HT capabilities when it sees these incorrect Basic MCS Set from the router. While thise likely differs from behavior in Windows and MacOS, it is technically the correct way to handle the situation. Some users may wish, however, to have the option to bypass this to make their wifi usable until a fix is integrated into the kernel.

This patch modifies the source file mlme.c in mac80211 to align HT mcs checks with how VHT mcs checks are performed by only verifying mcs in strict mode.
This line is what already exists in the kernel where mac80211 checks the VHT MCS set agains what the router is requiring:

```
/*
	 * Many APs are incorrectly advertising an all-zero value here,
	 * which really means MCS 0-7 are required for 1-8 streams, but
	 * they don't really mean it that way.
	 * Some other APs are incorrectly advertising 3 spatial streams
	 * with MCS 0-7 are required, but don't really mean it that way
	 * and we'll connect only with HT, rather than even HE.
	 * As a result, unfortunately the VHT basic MCS/NSS set cannot
	 * be used at all, so check it only in strict mode.
	 */
	if (!ieee80211_hw_check(&sdata->local->hw, STRICT))
		return true;
```
Authored by @benzea and committed by @jmberg-intel
The initial commit can be found here: https://github.com/torvalds/linux/commit/574faa0e936d12718e2cadad11ce1e184d9e5a32

My patch simply inserts the same line into the similar HT function just above it.

```
+	 * Similar to the issue below with VHT, some APs, mainly Comcast XB7+,
+	 * are advertizing an all-F value, meaning the AP is requiring MCS
+	 * 0-76 in order to connect with HT. Connection to the affected 2.4
+	 * and 5ghz bands will fall back to legacy 802.11a/g,even if the
+	 * hardware and regulations support VHT or HE (and presumably EHT)
+	 * HT Basic MCS set cannot be used, so check only in strict mode
+	 * as is done in the VHT section.
+	 */
+	if (!ieee80211_hw_check(&sdata->local->hw, STRICT))
+		return true;
```

This instructs mac80211 to ignore the MCS verification and enable HT anyway until Comcast fixes their firmware or the kernel devs implement a bypass. I can confirm that VHT is indeed being falsely advertised as well, but VHT is already patched in the kernel while HT is not. This is the text from the commit:

> wifi: mac80211: add HT and VHT basic set verification
> So far we did not verify the HT and VHT basic MCS set. However, in
> P802.11REVme/D7.0 (6.5.4.2.4) says that the MLME-JOIN.request shall
> return an error if the VHT and HT basic set requirements are not met.

Given broken APs, apply VHT basic MCS/NSS set checks only in
strict mode.

While the VHT issue had to do with all-zero entries into the Basic MCS Set for VHT, the issue with HT is actually the opposite with all f's, but the result is functionally the same.
HT:

9d 05 17 00 00 00 ff ff ff ff ff
ff ff ff ff ff ff ff ff ff ff ff

The first few pairs are simply things like the channel, offset/width, and protection bits. The series of f's, however, is why things fail. Those are the bits that dictate the requirements that any client needs to meet in order to associate at high speed. To do this would require four spatial streams, while most wireless cards support only 2. When mac80211 receives this information from the wireless driver, it disables HT when it sees that the hardware can't meet those requirements.

For reference here is what this looks like in VHT:

01 2a 00 00 00

In this case though, the 0 represents that the client must support MCS 0-7 in the 4 TX and 4 RX streams. This issue had been fixed in early 2025 however. I can only assume that this issue is only now appearing for HT because companies have shifted their focus towards newer standards. It is likely that the router's supported MCS were simply copied and pasted into the Basic MCS Set at some point during development.

## Credits
The possiblity of a patch was first brought to my attention by WoodyWoodster: https://github.com/WoodyWoodster/mac80211-mcs-patch
The patch has since been changed to reflect the existing kernel code which was authored by @benzea.
Thank you to the BlueBuild team as well for the platform to release this for Bazzite users. https://github.com/blue-build

 _AI Disclodure: I used Google Gemini and Github Copilot throughout much of this process. Builds and changes were reviewed and tested by myself, but my coding skills are nowhere near professional._
 _I have personally gone through and changed mlme.c by hand, ran a diff, patched the file, double checked the code was written correctly, and installed this ont my personal device._
_Use at your own risk, and report any bugs._

## License
This project provides a patched version of the `mac80211` kernel module, which is part of the Linux kernel. This work is licensed under the **GNU General Public License v2.0**, consistent with the upstream Linux kernel source.
