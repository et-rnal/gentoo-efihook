# What is this? 
A port of void linux' default efibootmgr hook to work with gentoo dist-kernel
If you'd like to see more about their implimentation, please see [void's efibootmgr package](https://github.com/void-linux/void-packages/tree/d97b4abbe11ff5b08e1a2c852489bc36dd2f64c5/srcpkgs/efibootmgr)
This implimentation supplants the requirement of a traditional bootloader. It will automatically add `efibootmgr` entries upon kernel installation/upgrade. 

# Why does this exist?

Primarily as a learning tool for myself. I actually use this setup on my personal machines. If you've stumbled across this, please ensure you know what these scripts are doing. Your mileage may vary. You have been warned. 

# How do I configure it? 

## Manually
Place the appropriate hooks from `etc_hooks/` in `/etc/kernel/` under their respective directories
Place `etc_hooks/default/efibootmgr-kernel-hook` in the target device as `/etc/default/efibootmgr-kernel-hook`
This will account for kernel version numbers present in `/boot` which are appended to the initrd and vmlinuz files by default both with `genkernel` and `dracut`
Check the `efibootmgr-kernel-hook` file and place your own arguments inside, including UUID's and target device.

## `dracut` vs `genkernel` 
One important consideration is whether or not the target system will be utilizing `dracut` or `genkernel`. Both of these have different arguments required for LUKS to work. 


### dracut cmdline example 
```rd.luks.uuid=MY_ENCRYPTED_ROOT_UUID rd.luks.name=MY_ENCRYPTED_ROOT_UUID=crypt_root root=/dev/mapper/crypt_root
```
This would be placed in `/etc/default/efibootmgr-kernel-hook` in the OPTIONS variable for machines using dracut. Please read why you'd want both "rd.luks.uuid" and "rd.luks.name" present [here](https://github.com/dracutdevs/dracut/issues/1566)

### genkernel cmdline example 
```crypt_root=UUID=MY_ENCRYPTED_ROOT_UUID root=/dev/mapper/root
```
This would be placed in `/etc/default/efibootmgr-kernel-hook` in the OPTIONS variable for machines using genkernel.

Note: If you want to leverage genkernel's initramfs (which works better in my opinion), disable the initramfs use flag for gentoo-kernel and install genkernel. 

After this, you can drop a 2 liner in `/etc/kernel/postinst.d/` containing the following lines:
```#!/bin/sh
genkernel initramfs --luks
```
This will cause gentoo-kernel to automatically leverage genkernel to produce the initramfs vice dracut. 

## inst.sh
This is a quick deployment script to be ran in a chroot. This was made to function inside of archiso (but can be used by any GNU/Linux system) with the following disk layout
sdc2 being LUKS, with crypt_root being the name of it's unlocked part in /dev/mapper/

At the top of "inst.sh", simply plug in the target device (i.e /dev/sdc) and your desired InitramfsScheme (dracut or genkernel) and it will take care for the rest, including disabling the initramfs use flag for gentoo-kernel

sdc                                                               
├─sdc1         /mnt/boot               
├─sdc2                                 
│ └─crypt_root /mnt                    
└─sdc3                                 

# Depencencies
`gentoo-kernel` (disable the initramfs use flag if you want to use genkernel instead), `genkernel` (optional, default is dracut) `cryptsetup`, `efibootmgr`, `linux-firmware`
