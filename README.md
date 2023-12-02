#What is this? 
A port of void linux' default efibootmgr hook to work with gentoo dist-kernel

# How do I configure it? 
Place the appropriate hooks from `etc_hooks/` in `/etc/kernel/` under their respective directories
Place `etc_hooks/default/efibootmgr-kernel-hook` in the target device as `/etc/default/efibootmgr-kernel-hook`
This will account for kernel version numbers present in `/boot` which are appended to the initrd and vmlinuz files by default both with `genkernel` and `dracut`
Check the `efibootmgr-kernel-hook` file and place your own arguments inside, including UUID's and target device.

## Depencencies
on gentoo, ensure use flags for `initramfs` and `crpytsetup` are enabled. 
