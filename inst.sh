#!/bin/bash
######################
# FILL OUT THE BELOW #

#/dev/sdX
TargetDevice=""
InitramfsScheme=""
#genkernel or dracut

######################

refresh_uuid(){
block_data=$(blkid $TargetDevice* 2>/dev/null)
get_home_crypto_uuid=$(blkid $TargetDevice* | grep -e $TargetDevice"3" -e $TargetDevice"p3" | cut -d '"' -f 2)
get_root_crypto_uuid=$(blkid $TargetDevice*| grep -e $TargetDevice"2" -e $TargetDevice"p2" | cut -d '"' -f 2)
get_home_plain_uuid=$(lsblk /dev/mapper/crypt_home --output UUID --noheadings 2>/dev/null)
get_root_plain_uuid=$(lsblk /dev/mapper/crypt_root --output UUID --noheadings 2>/dev/null)
dev_name=$(echo $TargetDevice | cut -d '/' -f 3)
get_root_puuid=$(lsblk $TargetDevice* --output NAME,PARTUUID --raw --noheadings | grep -e $dev_name"2" -e $dev_name"p2"| cut -d ' ' -f 2 | uniq | xargs)
get_home_puuid=$(lsblk $TargetDevice* --output NAME,PARTUUID --raw --noheadings| grep -e $dev_name"3" -e $dev_name"p3" | cut -d ' ' -f 2 | uniq | xargs)
get_boot_part=$(lsblk $TargetDevice* --raw --noheadings --output NAME| grep -e $dev_name"1" -e $dev_name"p1" | uniq | xargs)
get_boot_uuid=$(blkid $TargetDevice*| grep -e $TargetDevice"1" -e $TargetDevice"p1" | cut -d '"' -f 2)
get_device_id=$(blkid /dev/disk/by-id/* --match-token UUID="$get_boot_uuid" |xargs | cut -d '/' -f 5 | cut -d ':' -f 1 | sed 's/-part[0-9]*//g')
}


config_check(){
doas_check=$(which doas 2>/dev/null)


if [ -z $TargetDevice ]; then 
	echo "No target device set, please read the config file!" && exit
else 
	echo -n
fi

if [ "$InitramfsScheme" = "dracut" ] || [ "$InitramfsScheme" = "genkernel" ]; then
	echo "InitramfsScheme is $InitramfsScheme"
else 
	echo "No valid \$InitramfsScheme set! Please view the script, it requires either \"genkernel\" or \"dracut\"" && exit
fi

if [ ! -b $TargetDevice ]; then
	echo "Target device is not reachable, check your config file!" && exit
else 
	echo -n
fi
if [ -z "$doas_check" ]; then
	echo "Set PrivEsc to sudo"
	PrivEsc="sudo"
else
	echo "Set PrivEsc to doas"
	PrivEsc="doas"
fi

}


deploy(){



if [ $InitramfsScheme == "dracut" ]; then
echo -----------------------------
echo "dracut Configuration"
echo \>\> Directory: /etc/dracut.conf.d \(will be configured\)
echo \>\> File: 10.conf \(will be added\)
echo \>\> Content:
echo -e "hostonly=\"yes\""
echo -e "add_drivers+=\" vfat \""
echo -e "add_dracutmodules+=\" crypt \"" 
echo -----------------------------
echo
echo "This will automatically create the appropriate initramfs and vmlinuz files in /boot to include the desired modules."
read -p "Do you wish to create this file? [y/N]: " yn 
case $yn in
  "y"|"Y") echo;;
  "n"|"N") echo "Understood." && sleep 2  && efihook_strap;;
esac
mkdir /mnt/etc/dracut.conf.d
echo -e "hostonly=\"yes\"" > /mnt/etc/dracut.conf.d/10.conf
echo -e "add_drivers+=\" vfat \"" >> /mnt/etc/dracut.conf.d/10.conf
echo -e "add_dracutmodules+=\" dm crypt \"" >> /mnt/etc/dracut.conf.d/10.conf

echo "Completed!"
elif [ $InitramfsScheme == "genkernel" ]; then
echo -----------------------------
echo "genkernel Configuration"
echo \>\> File: /etc/kernel/postinst.d/aa-genkernel 
echo \>\> File: /etc/portage/package.use/gentoo-kernel 
echo \>\> Actions:
echo "1.) Deploy aa-genkernel, a hook to automatically generate an initramfs on kernel install/upgrade"
echo "2.) Deploy "sys-kernel/gentoo-kernel -initramfs", preventing the dist kernel from pulling in dracut"
echo -----------------------------

echo "This will automatically ensure genkernel creates the initramfs files required to boot, instead of utilizing dracut for this."
read -p "Do you wish to create this file? [y/N]: " yn 
case $yn in
  "y"|"Y") echo;;
  "n"|"N") echo "Understood." && sleep 2  && efihook_strap;;
esac
$PrivEsc cp -v etc_hooks/kernel/postinst.d/aa-genkernel /mnt/etc/kernel/postinst.d/
echo "sys-kernel/gentoo-kernel -initramfs" > /mnt/etc/portage/package.use/gentoo-kernel
echo "sys-kernel/gentoo-kernel -initramfs >> /mnt/etc/portage/package.use/gentoo-kernel"
echo "Completed!"



else 
echo "Unknown initramfs option, how did you make it this far?"
exit
fi




}
efi_config(){
if [ "$InitramfsScheme" == "genkernel" ]; then
boot_args="crypt_root=UUID=$get_root_crypto_uuid root=/dev/mapper/root"
quiet_settings="quiet loglevel=3"
elif [ "$InitramfsScheme" == "dracut" ]; then
boot_args="rd.luks.uuid=$get_root_crypto_uuid rd.luks.name=$get_root_crypto_uuid=crypt_root root=/dev/mapper/crypt_root"
quiet_settings="quiet loglevel=3"
echo $boot_args
fi
echo -----------------------------
echo "efibootmgr Configuration (generated for: $InitramfsScheme)"
echo \>\> Directory: /etc/default \(will be configured\)
echo \>\> File: efibootmgr-kernel-hook \(will be added\)
echo \>\> Content:
echo "MODIFY_EFI_ENTRIES=1" 
echo -e "OPTIONS=\"$quiet_settings fbcon=font:TER16x32 fbcon=nodefer $boot_args\"" 
echo -e "DISK=\"/dev/disk/by-id/$get_device_id\"" 
echo -e "PART=1" 
echo -----------------------------
echo "This step will configure efibootmgr to be automatically updated upon kernel installation/upgrade/removal."
#echo "This is triggered by the two following files, which are executed automatically on kernel version changes"
#echo "/etc/kernel/postinst.d/zz-efibootmgr"
#echo "/etc/kernel/postrm.d/zz-efibootmgr"
echo "This supplants the need for GRUB, or any similar piece of software"

read -p "Do you understand and wish to continue? [y/N]: " yn 
case $yn in
  "y"|"Y") echo;;
  "n"|"N") echo "Understood." && sleep 2  && exit;;
esac
mkdir /mnt/etc/default
touch /mnt/etc/default/efibootmgr-kernel-hook
echo "MODIFY_EFI_ENTRIES=1" > /mnt/etc/default/efibootmgr-kernel-hook
echo -e "OPTIONS=\"loglevel=3 $quiet_settings fbcon=font:TER16x32 fbcon=nodefer $boot_args\"" >> /mnt/etc/default/efibootmgr-kernel-hook
echo -e "DISK=\"/dev/disk/by-id/$get_device_id\"" >> /mnt/etc/default/efibootmgr-kernel-hook
echo -e "PART=1" >> /mnt/etc/default/efibootmgr-kernel-hook

sleep 2
echo "----------"
echo "Installing kernel postinst.d and postrm.d hooks."

$PrivEsc mkdir /mnt/etc/kernel/postinst.d --parents --verbose
$PrivEsc mkdir /mnt/etc/kernel/postrm.d --parents --verbose 
$PrivEsc cp -v etc_hooks/kernel/postinst.d/zz-efibootmgr /mnt/etc/kernel/postinst.d/
$PrivEsc cp -v etc_hooks/kernel/postrm.d/zz-efibootmgr /mnt/etc/kernel/postrm.d/
echo "Hook installation finished!"

}

kernel_hook(){

if [ "$InitramfsScheme" == "dracut" ]; then
echo "Please ensure you have read the README document before proceeding."
echo "This will deploy the following "
echo "/etc/
├── dracut.conf.d
│   └── 10.conf
├── default
│   └── efibootmgr-kernel-hook
└── kernel
    ├── postinst.d
    │   └── zz-efibootmgr
    └── postrm.d
        └── zz-efibootmgr
"
elif [ "$InitramfsScheme" == "genkernel" ]; then
echo "Please ensure you have read the README document before proceeding."
echo "This will deploy the following "
echo "/etc/
├── default
│   └── efibootmgr-kernel-hook
└── kernel
    ├── postinst.d
    │   └── zz-efibootmgr
    │   └── aa-genkernel 
    └── postrm.d
        └── zz-efibootmgr
"
fi
sleep 2 

echo "Once the script has been deployed, ensure you check /etc/default/efibootmgr-kernel-hook and place your OWN values into it, then run emerge --config gentoo-kernel"

read -p "Do you understand and wish to proceed? [y/N]: " yn
case $yn in
  "y"|"Y") deploy;;
  "n"|"N") echo "Understood." && sleep 2 ;;
esac
}


refresh_uuid
config_check
refresh_uuid
kernel_hook
refresh_uuid
efi_config
