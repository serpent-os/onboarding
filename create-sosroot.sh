#!/usr/bin/env bash
#
# SPDX-License-Identifier: Zlib
#
# Copyright: © 2022 Serpent OS Developers
#

# create-sosroot.sh:
# script for conveniently creating a working /var/lib/machines/sosroot/
# directory suitable for use as the root in a systemd-nspawn container
# or a linux-kvm kernel driven qemu-kvm virtual machine.

# base packages
PACKAGES=(
    bash
    boulder
    coreutils
    dash
    dbus
    dbus-broker
    file
    gawk
    git
    grep
    gzip
    inetutils
    iproute2
    less
    moss
    moss-container
    nano
    nss
    openssh
    procps
    python
    screen
    sed
    shadow
    sudo
    systemd
    unzip
    util-linux
    vim
    wget
    which
)

# packages specific to qemu-kvm support
KVM_PACKAGES=(
    linux-kvm
)

# target dir
SOSROOT="/var/lib/machines/sosroot"
BOULDERCACHE="/var/cache/boulder"

sudo rm -rf "${SOSROOT}"
sudo mkdir -pv "${SOSROOT}"
sudo moss -D "${SOSROOT}" ar volatile https://dev.serpentos.com/volatile/x86_64/stone.index -p0
sudo moss -D "${SOSROOT}" install "${PACKAGES[@]}"

# prepare local-x86_64 profile directory
sudo mkdir -pv ${BOULDERCACHE}/collections/local-x86_64/
sudo moss index ${BOULDERCACHE}/collections/local-x86_64/
sudo moss -D "${SOSROOT}" ar local-x86_64 file://${BOULDERCACHE}/collections/local-x86_64/stone.index -p10

# kvm
sudo mkdir -pv "${SOSROOT}"/etc/
sudo cp -va /etc/protocols "${SOSROOT}"/etc/

echo -e "\nstart a systemd-nspawn container with:\n"
echo -e "  sudo systemd-nspawn --bind=${BOULDERCACHE}/ -D ${SOSROOT}/ -b\n"
