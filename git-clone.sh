#!/usr/bin/env bash
#
# SPDX-License-Identifier: Zlib
#
# Copyright: © 2022 Serpent OS Developers
#

# Initial setup of Serpent OS Dlang repos for development purposes

RUN_DIR="${PWD}"

# Be helpful if the user supplies an argument
if [[ -n "$1" ]]; then
    cat << EOF

Usage: git-clone.sh

Clone all current Serpent OS (https://serpentos.com) tool repositories.

Please run the script from an empty serpent-os/ base directory

EOF
    exit 0
fi

function failMsg()
{
    echo -e "$*"
    exit 1
}

# Check for all tools, libraries and headers before bailing
checkPrereqs=0
function checkPrereqs()
{
    # Check that the script was run from the shared serpent-os/ dir and not from a git-controlled dir
    [[ -d .git/ ]] && failMsg "Found a .git/ dir -- please run ${0} from the (unversioned) base serpent-os/ dir."

    # Bash associative arrays are well suited for this kind of thing
    declare -A bin
    bin['pkg-config tool']=pkg-config
    bin['Binutils']=ld
    bin['C compiler']=cc
    bin['CMake build tool']=cmake
    bin['Codespell python tool']=codespell
    bin['Dlang code formatter']=dfmt
    bin['Dlang package manager']=dub
    bin['GNU Awk interpreter']=gawk
    bin['Git version control tool']=git
    bin['LDC D compiler']=ldc2
    bin['Meson build tool']=meson
    bin['Ninja build tool']=ninja

    echo -e "\nChecking for necessary tools..."
    #'all keys in the bin associative array'
    for b in "${!bin[@]}" ; do
        command -v "${bin[$b]}" > /dev/null 2>&1
        if [[ ! $? -eq 0 ]]; then
            echo "- ${b} (${bin[$b]}) not found in PATH?"
            checkPrereqs=1
        else
            echo "- found ${b} (${bin[$b]})"
        fi
    done

    echo "Checking for necessary libraries and development headers..."
    declare -A lib
    lib[curl]=libcurl.so.4
    lib[rocksdb]=librocksdb.so.6
    lib[xxhash]=libxxhash.so.0
    lib[zstd]=libzstd.so.1

    for l in ${!lib[@]}; do
        find /usr/lib{,64} -name ${lib[$l]} > /dev/null 2>&1
        if [[ ! $? -eq 0 ]]; then
            echo "- ${l} library (${lib[$l]}) not found?"
            checkPrereqs=1
        else
            echo "- found ${l} library (${lib[$l]})"
        fi
    done

    # Key is the .pc name (without extension) -- e.g. libcurl.pc -> libcurl
    # Value is the invocation parameters for a successful pkg-config match
    # FIXME: Determine and set correct minimum versions
    declare -A pc
    pc[libcurl]='--atleast-version=7.5'
    pc[libxxhash]='--atleast-version=0.0.1'
    pc[libzstd]='--atleast-version=1'
    pc[rocksdb]='--atleast-version=6.22'

    for p in ${!pc[@]}; do
        pkg-config ${pc[$p]} ${p} #> /dev/null 2>&1
        if [[ ! $? -eq 0 ]]; then
            echo "- ${p}.pc file (typically included in a -devel package) not found?"
            checkPrereqs=1
        else
            echo "- found ${p}.pc file"
        fi
    done

    # For packages which typically don't have .pc files
    declare -A header
    header[kernel]='linux/elf.h'
    header[glibc]='gnu/lib-names-64.h'

    for h in ${!header[@]}; do
        find /usr/include -name ${header[$h]} > /dev/null 2>&1
        if [[ ! $? -eq 0 ]]; then
            echo "- ${h} headers (${header[$h]}) not found?"
            checkPrereqs=1
        else
            echo "- found ${h} headers (/usr/include/${header[$h]})"
        fi
    done

    if [[ ${checkPrereqs} -gt 0 ]]; then
        failMsg "\nPlease ensure that all necessary tools, libraries and headers are installed.\n"
    else
        echo -e "\nFound all necessary tools, libraries and headers.\n"
    fi
}

checkGit=0
failClone=()
# Will likely fail if the repo path exists locally, so this may not be a good solution
function gitClone()
{
    echo -e "Cloning ${HTTPS_PREFIX}/${1}.git..."
    git clone --recurse-submodules "${HTTPS_PREFIX}/${1}.git"
    # Only set up push URI on successful clone
    if [[ $? -eq 0 ]]; then
        echo -e "\nSetting up ${1} SSH push URI...\n"
        git -C "${1}" remote set-url --push origin "${SSH_PREFIX}/${1}.git"
        git -C "${1}" remote -v
        echo ""
    else
        echo -e "\n- failed to clone ${1}, not attempting to set push URI.\n"
        failClone+=("${1}")
        checkGit=1
    fi
}

function main ()
{
    # Run checks
    checkPrereqs

    # Download via HTTPS (negotiates faster than SSH), push via SSH
    SSH_PREFIX="git@gitlab.com:serpent-os/core"
    HTTPS_PREFIX="https://gitlab.com/serpent-os/core"

    echo -e "Base pull URI: ${HTTPS_PREFIX}"
    echo -e "Base push URI: ${SSH_PREFIX}\n"

    CORE_REPOS=(
        boulder
        moss
        moss-config
        moss-container
        moss-core
        moss-db
        moss-deps
        moss-fetcher
        moss-format
        moss-vendor
    )

    for repo in ${CORE_REPOS[@]}; do
        gitClone "${repo}"
    done

    [[ ${checkGit} -gt 0 ]] && failMsg "ERROR:\n\nFailed to clone:\n\n${failClone[@]} !"

    echo -e "List of directories in ${RUN_DIR}:\n"
    ls -1F --group-directories-first ${RUN_DIR}
    echo ""
}

main
