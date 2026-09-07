#!/usr/bin/env bash
rm -rf ./.temp-chroot
mkdir -p ./.temp-chroot
tar  -xzf ./dist/bootstrap.tar.gz -C ./.temp-chroot
mkdir -p ./.temp-chroot/proc
mkdir -p ./.temp-chroot/sys
mkdir -p ./.temp-chroot/dev

sudo mount -t proc proc "./.temp-chroot/proc"
sudo mount -t sysfs sys "./.temp-chroot/sys"
sudo mount --bind /dev "./.temp-chroot/dev"
sudo chroot ./.temp-chroot /bin/sh