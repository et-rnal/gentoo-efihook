#!/bin/sh

deploy(){
echo "Deploying scripts"
cp -rPv etc_hooks/kernel/ /etc/
mkdir /etc/default
cp -v etc_hooks/default/efibootmgr-kernel-hook /etc/default/
}

echo "Please ensure you have read the README document before proceeding."
echo "This will deploy the following "
echo "/etc/
├── default
│   └── efibootmgr-kernel-hook
└── kernel
    ├── postinst.d
    │   └── zz-efibootmgr
    └── postrm.d
        └── zz-efibootmgr
"
sleep 2 

echo "Once the script has been deployed, ensure you check /etc/default/efibootmgr-kernel-hook and place your OWN values into it, then run emerge --config gentoo-kernel"

read -p "Do you understand and wish to proceed? [y/N]: " yn
case $yn in
  "y"|"Y") deploy;;
  "n"|"N") echo "Understood." && sleep 2 ;;
esac
