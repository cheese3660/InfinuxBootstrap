#!/usr/bin/env bash
[ -f ./dist/bootstrap.tar.gz ] && file="./dist/bootstrap.tar.gz"
[ -f ./dist/bootstrap.tar.xz ] && file="./dist/bootstrap.tar.xz"
if [ -z "$file" ]; then
    echo "Error: Bootstrap archive not found." >&2
    exit 1
fi


rm -rf ./.temp-chroot
mkdir -p ./.temp-chroot
tar  -xf $file -C ./.temp-chroot
mkdir -p ./.temp-chroot/proc
mkdir -p ./.temp-chroot/sys
mkdir -p ./.temp-chroot/dev

sudo mount -t proc proc "./.temp-chroot/proc"
sudo mount -t sysfs sys "./.temp-chroot/sys"
sudo mount --bind /dev "./.temp-chroot/dev"
sudo chroot ./.temp-chroot /bin/sh
sudo umount ./.temp-chroot/dev
sudo umount ./.temp-chroot/sys
sudo umount ./.temp-chroot/proc
sudo umount -R  ./.temp-chroot