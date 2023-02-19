#!/usr/bin/env bash
#
# SPDX-License-Identifier: Zlib
#
# Copyright: © 2022 Serpent OS Developers
#

# create-sosroot.sh:
# script for conveniently creating a clean /var/lib/machines/sosroot/
# directory suitable for use as the root in serpent os systemd-nspawn
# container or linux-kvm kernel driven qemu-kvm virtual machine.

# target dirs
SOSROOT="/var/lib/machines/sosroot"
BOULDERCACHE="/var/cache/boulder"

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
    linux-kvm
    moss
    moss-container
    nano
    neofetch
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

# utility functions
BOLD='\033[1m'
RED='\033[0;31m'
RESET='\033[0m'
YELLOW='\033[0;33m'

printInfo () {
    local INFO="${BOLD}INFO${RESET}"
    echo -e "${INFO} ${*}"
}

printWarning () {
    local WARNING="${YELLOW}${BOLD}WARNING${RESET}"
    echo -e "${WARNING} ${*}"
}

printError () {
    local ERROR="${RED}${BOLD}ERROR${RESET}"
    echo -e "${ERROR} ${*}"
}

die() {
    printError "${*}\n"
    exit 1
}

showHelp() {
    cat <<EOF

----

You can now start a systemd-nspawn container with:

 sudo systemd-nspawn --bind=${BOULDERCACHE}/ -D ${SOSROOT}/ -b

Do a 'systemctl poweroff' inside the container to shut it down.

The container can also be shut down with:

 sudo machinectl stop sosroot

in a shell outside the container.

EOF
}

MSG="Removing old ${SOSROOT} directory..."
printInfo "${MSG}"
sudo rm -rf "${SOSROOT}" || die "${MSG} failed, exiting."

MSG="Creating new ${SOSROOT} directory..."
printInfo "${MSG}"
sudo mkdir -pv "${SOSROOT}" || die "${MSG} failed, exiting."

MSG="Adding volatile serpent os repository..."
printInfo "${MSG}"
sudo moss -D "${SOSROOT}" ar volatile https://dev.serpentos.com/volatile/x86_64/stone.index -p0 || die "${MSG} failed, exiting."

MSG="Installing packages..."
printInfo "${MSG}"
sudo moss -D "${SOSROOT}" install "${PACKAGES[@]}"

MSG="Preparing local-x86_64 profile directory..."
printInfo "${MSG}"
sudo mkdir -pv ${BOULDERCACHE}/collections/local-x86_64/ || die "${MSG} failed, exiting."

MSG="Creating a moss stone.index file for the local-x86_64 profile..."
printInfo "${MSG}"
sudo moss index ${BOULDERCACHE}/collections/local-x86_64/ || die "${MSG} failed, exiting."

MSG="Adding local-x86_64 profile to list of active repositories..."
printInfo "${MSG}"
sudo moss -D "${SOSROOT}" ar local-x86_64 file://${BOULDERCACHE}/collections/local-x86_64/stone.index -p10 || die "${MSG} failed, exiting."

MSG="Ensuring that an /etc directory exists in ${SOSROOT}..."
printInfo "${MSG}"
sudo mkdir -pv "${SOSROOT}"/etc/ || die "${MSG} failed, exiting."

MSG="Ensuring that various network protocols function..."
printInfo "${MSG}"
sudo cp -va /etc/protocols "${SOSROOT}"/etc/ || die "${MSG} failed, exiting."

showHelp

